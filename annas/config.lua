local util = require("util")
local T = require("annas.gettext")
local logger = require("logger")

local Config = {}

Config.SETTINGS_SEARCH_LANGUAGES_KEY = "annas_search_languages"
Config.SETTINGS_SEARCH_EXTENSIONS_KEY = "annas_search_extensions"
Config.SETTINGS_SEARCH_ORDERS_KEY = "annas_search_order"
Config.SETTINGS_DOWNLOAD_DIR_KEY = "annas_download_dir"
Config.SETTINGS_TURN_OFF_WIFI_AFTER_DOWNLOAD_KEY = "annas_turn_off_wifi_after_download"
Config.SETTINGS_LIBGEN_MAX_PAGES_KEY = "annas_libgen_max_pages"
Config.SETTINGS_LIBGEN_TOPICS_KEY = "annas_libgen_topics"
Config.SETTINGS_FLARESOLVERR_URL_KEY = "annas_flaresolverr_url"
Config.SETTINGS_FLARESOLVERR_MODE_KEY = "annas_flaresolverr_mode"

-- Library Genesis collections, as libgen's topics[] search parameter.
-- No selection searches all of them (libgen's default).
Config.SUPPORTED_LIBGEN_TOPICS = {
    { name = T("Libgen"), value = "l" },
    { name = T("Comics"), value = "c" },
    { name = T("Fiction"), value = "f" },
    { name = T("Scientific Articles"), value = "a" },
    { name = T("Magazines"), value = "m" },
    { name = T("Fiction RUS"), value = "r" },
    { name = T("Standards"), value = "s" },
}

-- libgen can't filter by language or format itself, so with those filters
-- set the plugin pages through results (100 per page) and filters locally.
Config.LIBGEN_MAX_PAGES_DEFAULT = 5
Config.LIBGEN_MAX_PAGES_MIN = 1
Config.LIBGEN_MAX_PAGES_MAX = 20

-- FlareSolverr is an optional helper service (not part of KOReader) that loads
-- a page in a real headless browser and hands back the HTML after any
-- Cloudflare/DDoS-Guard interstitial has been solved. It is off unless the
-- user points the plugin at a running instance, and the URL is almost always
-- the default because the service usually runs next to the reader (a desktop
-- on the same network, or on the device itself).
Config.FLARESOLVERR_DEFAULT_URL = "http://localhost:8191"

-- "fallback": fetch directly as usual, and only hand the URL to FlareSolverr
--             once a direct fetch failed or came back as a challenge page.
-- "always":  send every page fetch through FlareSolverr first.
Config.FLARESOLVERR_MODE_FALLBACK = "fallback"
Config.FLARESOLVERR_MODE_ALWAYS = "always"

Config.FLARESOLVERR_MODES = {
    { name = T("Automatic (only when a page is blocked)"), value = Config.FLARESOLVERR_MODE_FALLBACK },
    { name = T("Always (every page fetch)"), value = Config.FLARESOLVERR_MODE_ALWAYS },
}

Config.DEFAULT_DOWNLOAD_DIR_FALLBACK = G_reader_settings:readSetting("home_dir")
             or require("apps/filemanager/filemanagerutil").getDefaultDir()

-- Anna's Archive uses ISO 639-1 / BCP-47 language codes (see the `lang`
-- query parameter in the search form). Unknown values are silently ignored
-- by the server, which makes the filter appear to do nothing.
Config.SUPPORTED_LANGUAGES = {
    { name = "العربية", value = "ar" },
    { name = "Հայերեն", value = "hy" },
    { name = "Azərbaycanca", value = "az" },
    { name = "বাংলা", value = "bn" },
    { name = "简体中文", value = "zh" },
    { name = "Čeština", value = "cs" },
    { name = "Nederlands", value = "nl" },
    { name = "English", value = "en" },
    { name = "Français", value = "fr" },
    { name = "ქართული", value = "ka" },
    { name = "Deutsch", value = "de" },
    { name = "Ελληνικά", value = "el" },
    { name = "हिन्दी", value = "hi" },
    { name = "Bahasa Indonesia", value = "id" },
    { name = "Italiano", value = "it" },
    { name = "日本語", value = "ja" },
    { name = "한국어", value = "ko" },
    { name = "Bahasa Malaysia", value = "ms" },
    { name = "پښتو", value = "ps" },
    { name = "Polski", value = "pl" },
    { name = "Português", value = "pt" },
    { name = "Русский", value = "ru" },
    { name = "Српски", value = "sr" },
    { name = "Slovenčina", value = "sk" },
    { name = "Español", value = "es" },
    { name = "తెలుగు", value = "te" },
    { name = "ไทย", value = "th" },
    { name = "繁體中文", value = "zh-Hant" },
    { name = "Türkçe", value = "tr" },
    { name = "Українська", value = "uk" },
    { name = "اردو", value = "ur" },
    { name = "Tiếng Việt", value = "vi" },
}

Config.SUPPORTED_EXTENSIONS = {
    { name = "AZW", value = "AZW" },
    { name = "AZW3", value = "AZW3" },
    { name = "CBZ", value = "CBZ" },
    { name = "DJV", value = "DJV" },
    { name = "DJVU", value = "DJVU" },
    { name = "EPUB", value = "EPUB" },
    { name = "FB2", value = "FB2" },
    { name = "LIT", value = "LIT" },
    { name = "MOBI", value = "MOBI" },
    { name = "PDF", value = "PDF" },
    { name = "RTF", value = "RTF" },
    { name = "TXT", value = "TXT" },
}

Config.SUPPORTED_ORDERS = {
    { name = T("Most Relevant"), value = "" },
    { name = T("Newest"), value = "newest" },
    { name = T("Oldest"), value = "oldest" },
    { name = T("Largest"), value = "largest"},
    { name = T("Smallest"), value = "smallest"},
    { name = T("Newest Added"), value = "newest_added"},
    { name = T("Oldest Added"), value = "oldest_added"},
    { name = T("Random"), value = "random"}
}

function Config.getSetting(key, default)
    return G_reader_settings:readSetting(key) or default
end

function Config.saveSetting(key, value)
    if type(value) == "string" then
        G_reader_settings:saveSetting(key, util.trim(value))
    else
        G_reader_settings:saveSetting(key, value)
    end
end

function Config.deleteSetting(key)
    G_reader_settings:delSetting(key)
end

function Config.getDownloadDir()
    return Config.getSetting(Config.SETTINGS_DOWNLOAD_DIR_KEY, Config.DEFAULT_DOWNLOAD_DIR_FALLBACK)
end

function Config.getSearchLanguages()
    return Config.getSetting(Config.SETTINGS_SEARCH_LANGUAGES_KEY, {})
end

function Config.getSearchExtensions()
    return Config.getSetting(Config.SETTINGS_SEARCH_EXTENSIONS_KEY, {})
end

function Config.getSearchOrder()
    return Config.getSetting(Config.SETTINGS_SEARCH_ORDERS_KEY, {})
end

function Config.getSearchOrderName()
    local search_order_name = T("Default")
    local selected_order = Config.getSearchOrder()
    local search_order = selected_order and selected_order[1]

    if search_order then
        for _, v in ipairs(Config.SUPPORTED_ORDERS) do
            if v.value == search_order then
                search_order_name = v.name
                break
            end
        end
    end
    return search_order_name
end

function Config.getTurnOffWifiAfterDownload()
    return Config.getSetting(Config.SETTINGS_TURN_OFF_WIFI_AFTER_DOWNLOAD_KEY, false)
end

function Config.setTurnOffWifiAfterDownload(turn_off)
    Config.saveSetting(Config.SETTINGS_TURN_OFF_WIFI_AFTER_DOWNLOAD_KEY, turn_off)
end

function Config.getLibgenMaxPages()
    local pages = tonumber(Config.getSetting(Config.SETTINGS_LIBGEN_MAX_PAGES_KEY)) or Config.LIBGEN_MAX_PAGES_DEFAULT
    return math.max(Config.LIBGEN_MAX_PAGES_MIN, math.min(Config.LIBGEN_MAX_PAGES_MAX, math.floor(pages)))
end

function Config.setLibgenMaxPages(pages)
    Config.saveSetting(Config.SETTINGS_LIBGEN_MAX_PAGES_KEY, pages)
end

function Config.getLibgenTopics()
    return Config.getSetting(Config.SETTINGS_LIBGEN_TOPICS_KEY, {})
end

-- Turn whatever the user typed into a usable FlareSolverr base URL, or nil
-- when the field is empty (FlareSolverr disabled). A bare "localhost:8191" or
-- "192.168.1.5:8191" is a common thing to type, and without a scheme it would
-- silently build a broken request URL, so default the scheme to http.
-- Returns the normalized URL on success, or nil plus a message on a URL that
-- can't be used.
function Config.normalizeFlareSolverrUrl(raw_url)
    -- a settings store can hand back anything if it was hand-edited or
    -- corrupted, and string methods on a non-string would raise here
    local url = type(raw_url) == "string" and util.trim(raw_url) or ""
    if url == "" then
        return nil
    end
    if not url:match("^%a[%w+.-]*://") then
        url = "http://" .. url
    end

    local scheme, rest = url:match("^(%a[%w+.-]*)://(.+)$")
    if not scheme or rest == "" then
        return nil, string.format(T("Not a valid FlareSolverr URL: %s"), url)
    end
    scheme = scheme:lower()
    if scheme ~= "http" and scheme ~= "https" then
        return nil, T("FlareSolverr URL must start with http:// or https://")
    end

    -- strip a trailing slash so callers can append "/v1" unconditionally
    url = (scheme .. "://" .. rest):gsub("/+$", "")
    if not url:match("^%a[%w+.-]*://[^/%s]+$") then
        return nil, string.format(T("Not a valid FlareSolverr URL: %s"), url)
    end
    return url
end

function Config.getFlareSolverrUrl()
    local url, err = Config.normalizeFlareSolverrUrl(Config.getSetting(Config.SETTINGS_FLARESOLVERR_URL_KEY, ""))
    if not url and err then
        logger.warn("Annas: ignoring unusable FlareSolverr URL setting: " .. tostring(err))
    end
    return url
end

-- An empty field disables FlareSolverr (the setting is removed rather than
-- stored as "", so a stale URL can never resurface on its own).
function Config.setFlareSolverrUrl(raw_url)
    local url, err = Config.normalizeFlareSolverrUrl(raw_url)
    if err then
        return false, err
    end
    if not url then
        Config.deleteSetting(Config.SETTINGS_FLARESOLVERR_URL_KEY)
        return true
    end
    Config.saveSetting(Config.SETTINGS_FLARESOLVERR_URL_KEY, url)
    return true
end

function Config.getFlareSolverrMode()
    local mode = Config.getSetting(Config.SETTINGS_FLARESOLVERR_MODE_KEY, Config.FLARESOLVERR_MODE_FALLBACK)
    if mode ~= Config.FLARESOLVERR_MODE_FALLBACK and mode ~= Config.FLARESOLVERR_MODE_ALWAYS then
        return Config.FLARESOLVERR_MODE_FALLBACK
    end
    return mode
end

function Config.getFlareSolverrModeName()
    for _, mode_info in ipairs(Config.FLARESOLVERR_MODES) do
        if mode_info.value == Config.getFlareSolverrMode() then
            return mode_info.name
        end
    end
    return Config.FLARESOLVERR_MODES[1].name
end

-- Pre-rename versions stored these under zlibrary_* keys, which collided with
-- the unrelated zlibrary.koplugin's own settings. Copy any value forward to
-- the new annas_* key (once) so users don't silently lose their preferences
-- on update. The old key is deliberately left untouched rather than deleted:
-- since it was shared/colliding, we can't be sure it isn't still in use by
-- that other plugin if it's also installed.
local LEGACY_SETTINGS_KEY_MAP = {
    zlibrary_search_languages = Config.SETTINGS_SEARCH_LANGUAGES_KEY,
    zlibrary_search_extensions = Config.SETTINGS_SEARCH_EXTENSIONS_KEY,
    zlibrary_search_order = Config.SETTINGS_SEARCH_ORDERS_KEY,
    zlibrary_download_dir = Config.SETTINGS_DOWNLOAD_DIR_KEY,
    zlibrary_turn_off_wifi_after_download = Config.SETTINGS_TURN_OFF_WIFI_AFTER_DOWNLOAD_KEY,
}

function Config.migrateLegacySettings()
    for old_key, new_key in pairs(LEGACY_SETTINGS_KEY_MAP) do
        if G_reader_settings:readSetting(new_key) == nil then
            local old_value = G_reader_settings:readSetting(old_key)
            if old_value ~= nil then
                Config.saveSetting(new_key, old_value)
            end
        end
    end
end

return Config
