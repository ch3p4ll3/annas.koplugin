-- Client for a FlareSolverr service.
--
-- FlareSolverr (https://github.com/FlareSolverr/FlareSolverr) is a small
-- standalone server that runs a real headless browser, waits out Cloudflare /
-- DDoS-Guard interstitials, and returns the resulting page HTML as JSON. It is
-- not part of KOReader and not bundled here: the user has to run it somewhere
-- reachable from the device and point the plugin at it.
--
-- It is a GET-only page retriever, which is exactly what the scraper needs for
-- its search and download-page fetches. It must never be used for the actual
-- book bytes: the HTML comes back as a JSON string, so binary data would be
-- mangled. src/scraper.lua therefore disables it for binary downloads.

local logger = require("logger")
local Config = require("annas.config")

local FlareSolverr = {}

-- Exposed so callers can compare against the configured mode without having to
-- reach into Config themselves.
FlareSolverr.MODE_ALWAYS = Config.FLARESOLVERR_MODE_ALWAYS

-- How long FlareSolverr itself may spend on the challenge before giving up.
-- Kept generous because solving a challenge in a real browser is a lot slower
-- than a plain request, and the alternative is giving up on a page that would
-- have worked a moment later.
FlareSolverr.MAX_TIMEOUT_MS = 60000

-- FlareSolverr keeps working for a while after we stop reading the socket, so
-- the client-side timeout has to outlast its own maxTimeout by a margin.
local CLIENT_TIMEOUT_GRACE_SECS = 10

local function get_endpoint()
    local base_url = Config.getFlareSolverrUrl()
    if not base_url then
        return nil
    end
    -- Config.getFlareSolverrUrl() strips any trailing slash, so this is the
    -- only place that has to know about the API path.
    return base_url .. "/v1"
end

function FlareSolverr.isConfigured()
    return get_endpoint() ~= nil
end

-- Returns the configured mode, or nil when FlareSolverr isn't set up at all
-- (a mode without a URL is not something callers can act on).
function FlareSolverr.getMode()
    if not FlareSolverr.isConfigured() then
        return nil
    end
    return Config.getFlareSolverrMode()
end

-- Safely quote a string for embedding as a single shell argument. The request
-- body carries the target URL, which can come from a third-party mirror's HTML.
local function shell_quote(str)
    return "'" .. tostring(str):gsub("'", "'\\''") .. "'"
end

local function command_exists(cmd)
    local handle = io.popen("which " .. cmd .. " 2>/dev/null")
    if not handle then return false end
    local result = handle:read("*a")
    handle:close()
    return result and result ~= ""
end

-- POST a JSON body and return the response body as a string. Returns nil plus
-- a reason on failure. LuaSocket is tried first (it is always present inside
-- KOReader and needs no subprocess, which matters on a slow device), curl
-- second as a fallback that also covers a FlareSolverr reached over https.
local function post_json(endpoint, body, timeout_secs)
    local socket_ok = pcall(require, "socket")
    local http_ok, http = pcall(require, "socket.http")
    local ltn12_ok, ltn12 = pcall(require, "ltn12")

    if socket_ok and http_ok and ltn12_ok then
        -- http.TIMEOUT is global state shared with the scraper's own LuaSocket
        -- fetch, so restore it rather than leaking our longer timeout.
        local previous_timeout = http.TIMEOUT
        http.TIMEOUT = timeout_secs
        local response_body = {}
        local success, response, code = pcall(http.request, {
            url = endpoint,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#body),
                ["Accept"] = "application/json",
            },
            source = ltn12.source.string(body),
            sink = ltn12.sink.table(response_body),
        })
        http.TIMEOUT = previous_timeout

        if not success then
            print("=== FlareSolverr request threw:", tostring(response))
        elseif type(code) == "number" and code >= 200 and code < 300 then
            return table.concat(response_body)
        elseif type(code) == "number" then
            return nil, "FlareSolverr answered HTTP " .. tostring(code)
        else
            return nil, "could not reach " .. endpoint .. " (" .. tostring(code) .. ")"
        end
    end

    if command_exists("curl") then
        local handle = io.popen("curl -s --max-time " .. tostring(timeout_secs)
            .. " -X POST -H " .. shell_quote("Content-Type: application/json")
            .. " -H " .. shell_quote("Accept: application/json")
            .. " --data-binary " .. shell_quote(body)
            .. " " .. shell_quote(endpoint) .. " 2>&1")
        if handle then
            local raw = handle:read("*a")
            -- curl's error text lands in the same stream (2>&1), so a failed
            -- request still produces output. Only a zero exit status means the
            -- body is actually a response we can parse.
            local success = handle:close()
            if success and raw and #raw > 0 then
                return raw
            end
            return nil, "curl failed to reach " .. endpoint
        end
        return nil, "could not run curl"
    end

    return nil, "no HTTP client available to reach " .. endpoint
end

-- Fetch a single page through FlareSolverr and return its HTML.
-- Returns "success" plus the HTML, or a failure status plus a reason drawn
-- from the same vocabulary the scraper's other fetch tiers use
-- ("unavailable" = FlareSolverr not set up / unreachable,
--  "blocked"     = FlareSolverr ran but the site is still refusing us).
function FlareSolverr.fetch(url, max_timeout_ms)
    local endpoint = get_endpoint()
    if not endpoint then
        return "not_configured", nil, "unavailable"
    end

    max_timeout_ms = max_timeout_ms or FlareSolverr.MAX_TIMEOUT_MS
    local json_ok, json = pcall(require, "json")
    if not json_ok then
        return "no_json", nil, "unavailable"
    end

    local body_ok, body = pcall(json.encode, {
        cmd = "request.get",
        url = url,
        maxTimeout = max_timeout_ms,
    })
    if not body_ok then
        return "no_json", nil, "unavailable"
    end

    print("=== FlareSolverr: requesting", url, "from", endpoint)
    logger.info("Annas: FlareSolverr POST " .. endpoint .. " url=" .. url)
    local raw, transport_error = post_json(endpoint, body,
        math.floor(max_timeout_ms / 1000) + CLIENT_TIMEOUT_GRACE_SECS)
    if not raw then
        print("=== FlareSolverr request failed:", transport_error)
        logger.warn("Annas: FlareSolverr request failed: " .. tostring(transport_error))
        -- The service itself is missing or down, which is a "this environment
        -- has no working fetch method" problem rather than a site blocking us.
        return "unreachable", nil, "unreachable"
    end

    local decode_ok, response = pcall(json.decode, raw)
    if not decode_ok or type(response) ~= "table" then
        print("=== FlareSolverr returned a non-JSON response")
        return "invalid_response", nil, "unreachable"
    end

    if response.status ~= "ok" then
        local message = tostring(response.message or "no message")
        print("=== FlareSolverr reported an error:", message)
        logger.warn("Annas: FlareSolverr error for " .. url .. ": " .. message)
        return "solver_error", nil, "blocked"
    end

    local solution = response.solution
    if type(solution) ~= "table" or type(solution.response) ~= "string" or solution.response == "" then
        print("=== FlareSolverr returned no page content")
        return "empty_response", nil, "blocked"
    end

    -- FlareSolverr follows redirects and reports the final page's status. Only
    -- an error status means the site is still refusing us; anything else is
    -- real page content, and the scraper's own challenge detection gets the
    -- final say on whether it is usable.
    local solution_status = tonumber(solution.status)
    if solution_status and solution_status >= 400 then
        print("=== FlareSolverr got HTTP", solution_status, "for", url)
        return "blocked_response", nil, "blocked"
    end

    print("=== FlareSolverr returned", #solution.response, "bytes for", url)
    return "success", solution.response
end

return FlareSolverr
