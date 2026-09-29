# [KOReader Annas Plugin](https://github.com/fischer-hub/annas.koplugin)


**Disclaimer:** This plugin is for educational purposes only. Please respect copyright laws and use this plugin responsibly.

This KOReader plugin lets you search and download documents from Anna's Archive. Since it scrapes the HTML of Anna's Archive and tries to grab source links there is no need to log in with any account. However, as soon as there is changes to the Anna's Archive HTML code the scraper can (but it might not!) fail.

Big thanks and credits to the devs of the [KOReader Zlibrary plugin](https://github.com/ZlibraryKO/zlibrary.koplugin) which inspired a huge amount of the frontend code and UI for my plugin and to the devs of [KindleFetch](https://github.com/justrals/KindleFetch) which inspired much of my webscraping 'backend' code. Without these projects the plugin would probably not run at all yet lol.

The plugin was tested on KOReader installed on a Kindle Paperwhite 11th generation.

## Installation

1.  Download the the `annas.plugin.zip` archive from the [latest release](https://github.com/fischer-hub/annas.koplugin/releases/latest).
2.  Extract the `annas.koplugin.zip` file and rename remove the version number from the directory name if it has one, e.g.: `annas.koplugin-0.1.5` -> `annas.koplugin`.
3.  Copy the `annas.koplugin` directory to the `koreader/plugins` folder on your device.
4.  Restart KOReader.


## Usage

1.  Ensure you are in the KOReader file browser.
2.  Access the `Search` menu.
3.  Select `Anna's Archive`.
4.  Enter your search terms and adjust language, format, and additional settings as needed and hit `search`.
5.  Under Search Results click on the entry you are interested in.
6.  Finally hit `Format: (tap to download)` and confirm again by tapping `Download`.

## FlareSolverr (Advanced)
<details>
<summary>Click to reveal</summary>

**If searches return no results, or "DDoS protection" errors, Anna's Archive and its mirrors may be challenging your device.** The plugin can hand those requests to a [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) service, which loads the page in a real browser, waits out the challenge, and returns the page to the plugin.

FlareSolverr is **not** bundled with the plugin and **not** required. It is off until you configure it.

### What you need

* A machine on the same network as your e-reader (a desktop, a NAS, a server) running Docker. Running it on the e-reader itself is not practical - FlareSolverr needs Chromium, which no current e-reader has room for.

```sh
docker run -d \
  --name flaresolverr \
  --restart unless-stopped \
  -p 8191:8191 \
  ghcr.io/flaresolverr/flaresolverr:latest
```

### Configuring the plugin

1.  Open `Search` -> `Anna's Archive` -> `Settings` -> `FlareSolverr`.
2.  Tap `FlareSolverr URL` and enter the address of the service, e.g. `http://192.168.1.10:8191` (the IP of the machine running Docker). The default FlareSolverr port is `8191`; a scheme is optional.
3.  Leave the field empty to switch FlareSolverr off again.
4.  Tap `Test connection` to check the setup. It asks FlareSolverr for a real Anna's Archive page and tells you what came back.

### When it is used

`When to use FlareSolverr` has two settings:

* **Automatic (only when a page is blocked)** - the default. The plugin fetches pages directly as usual, and only contacts FlareSolverr once a page comes back as a challenge or fails outright. This costs nothing when you are not being blocked.
* **Always (every page fetch)** - every page goes through FlareSolverr. Slower and dependent on the service, but the most reliable when Anna's Archive is aggressively challenging your device.

The book file itself is always downloaded directly: FlareSolverr returns pages as text, so routing the actual ebook through it would corrupt the file.

</details>

## DNS Settings (Advanced)
<details>
<summary>Click to reveal</summary>
**On some devices, you may need to change your DNS provider to 1.1.1.1 (Cloudflare).**

You only need to do this if Anna’s Archive repeatedly does not work, for example:

* Downloads not working
* No results found (even when searching for something general)
* “All protocols failed” errors

### Fix (Kobo & Kindle)

Follow these steps:

1. Open an SSH session using KOReader.
   Go to:
   **Settings → Network → SSH Server → No Password** (for simplicity).

2. You will see a prompt with connection information.
   Look for an IP address like     `192.168.179.xxx`.
   This is your device’s IP.

3. On your PC, open a terminal and run:

   ```
   ssh -p 2222 root@<IP_FROM_ABOVE>
   ```
   
4. Run:

   ```sh
   ls /etc/ | grep dhcp
   ```
   
   If it returns `udhcpd.conf` then jump to the **udhcpc** section if it is `dhcpcd.conf` then follow the instructions in the **DHCP** section
   
#### DHCP

1. Edit the DHCP config file:

   ```
   vi /etc/dhcpcd.conf
   ```

   At the bottom, you should already see:

   ```
   nohook lookup-hostname
   ```

  2. Press **i** to enter insert mode and change it to:

   ```
   nohook lookup-hostname, resolv.conf
   ```

3. Press **ESC**, then type:

   ```
   :wq
   ```

   and press Enter.

4. Now edit the DNS resolver file:

   ```
   vi /etc/resolv.conf
   ```

   Change it to:

   ```
   nameserver 1.1.1.1
   ```

5. Press **ESC**, then type:

   ```
   :wq
   ```

   and press Enter.

  
#### udhcpc

1. Run

```sh
vi /usr/share/udhcpc/default.script
```

2. Enter insert mode by pressing `i` on your keyboard

3. Add the line `echo nameserver 1.1.1.1 >> $RESOLV_CONF` above `echo -n > $RESOLV_CONF`

4. Save and Quit with `ESC` and then `:wq`

5. Finally, if you want this change to be permanent, you'll need to run this command:

 `mntroot rw` 
 This will set your filesystem to writable.

#### Finishing up

To make these changes 'permanent' you can set the files you touched to be immutable, even to `root`, 
which should prevent future updates from overwriting your changes. Simply run `chattr +` to the files
you modified. To undo these changes later simply run `chattr -i` against the same files. 

**For udhcpc**:
 
• `chattr +i /usr/share/udhcpc/default.script` 

**For dhcp**:
• `chattr +i /etc/resolv.conf`
and
`chattr +i /etc/dhcpcd.conf`

- Reboot your device and try again.

  Done!

---

### Permanent fix without changing root write permissions(recommended)

To make this change permanent, you must set the DNS directly in your **router settings**.

Search on Google for something like:

> **“Change DNS to 1.1.1.1 on {Your Router Model}”**

and follow the instructions for your specific router.


## Keywords

KOReader, Z-library, e-reader, plugin, ebook, download, KOReader plugin, Z-library integration, digital library, e-ink, bookworm, reading, open source.
</details>
