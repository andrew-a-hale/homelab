# Packages, applications and features — Jason, 2026-11-11

Everything installed on this machine that a person chose, what it is for, and the
verdict from the walkthrough ([`todo/needs.md`](todo/needs.md)). Generated from
`pacman -Qeq` + `expac` + `scripts/pacman-atime-audit.sh 30`, so the sizes and
descriptions are the machine's own.

> **Snapshot, pre-cutover.** This is the inventory taken the morning of
> 2026-11-11, before the Omarchy layer and the 71 drops were removed. The boxes
> below are the plan, not the current state — for that run `pacman -Qe`. Where
> the plan changed while executing, [`complete/left-omarchy-2026-11-11.md`](complete/left-omarchy-2026-11-11.md)
> and [`complete/post-cutover-sweep-2026-11-11.md`](complete/post-cutover-sweep-2026-11-11.md)
> are the record: `mise-bin` was retired, `linux-omarchy` removed, and both NTFS
> disks became ext4. Current totals: **197 explicit, 1215 packages.**

**265 explicit packages** (`pacman -Qe`), 13.9 GiB installed,
out of 1475 packages in total — the rest is dependencies. Verdicts: **drop** =
decided out, **keep (plumbing)** = never run directly but needed, **keep** = never
run in 30 days but still wanted, **in use** = a binary ran in the last 30 days.

- **71 packages drop**, freeing **3.1 GiB** outright, plus the
  dependency closure `pacman -Rns` takes with them.
- 174 in use, 20 kept by decision.

## Features the desktop must provide

| Feature | What provides it | Verdict |
|---|---|---|
| Tiling window manager, per-workspace floating | `hyprland`, `SUPER+L` toggle | keep |
| Status bar: workspaces, clock/date, wifi, volume | `waybar` (replaces `quickshell`) | new package |
| App launcher | `fuzzel` on `SUPER+SPACE` (replaces the Omarchy menu) | new package |
| Notifications | none — no daemon, by decision | dropped |
| Volume/brightness OSD | none — volume on the bar, keys silent | dropped |
| Lock screen + idle | `hyprlock`, `hypridle` (lock at 150s) | keep |
| Wallpaper | `hyprpaper`, static (replaces `owe`) | new package |
| Screenshot → annotate → clipboard | `grim` + `slurp` + `satty` + `wl-clipboard` | keep + `satty` new |
| Screen recording | `gpu-screen-recorder` (already installed) | keep |
| Screen sharing / window picker | `xdg-desktop-portal-hyprland`, `hyprland-preview-share-picker` | keep |
| Clipboard (no history) | `wl-clipboard` + `wl-clip-persist` | keep |
| Theming | static dark defaults; `wallust` deferred | deferred |
| Japanese/Chinese input | `fcitx5` + mozc / chinese-addons / hangul / chewing | keep |
| Webcam in browser/vesktop | camera portal via `xdg-desktop-portal(-hyprland)` | verify, no new package |
| Audio | `pipewire` + `wireplumber` + `pamixer` | keep |
| Drives and removable media | `udiskie`, `gvfs-*`, `gnome-disk-utility` | keep |
| Filesystem tools | `btrfs-progs`, `dosfstools`; `ntfs-3g`/`exfatprogs` go with the NTFS disks | `ntfs-3g` + `exfatprogs` drop |
| Night light | `hyprsunset` | dropped |
| Bluetooth | `bluez` stack | dropped (no paired devices) |
| Emoji picker / clipboard history | — | dropped |
| Dock / minimise-to-dock | — | dropped |
| Keybind cheatsheet | — | dropped |
| Power menu | short `fuzzel` script on `SUPER+ESCAPE` | keep (to write) |

## Applications you launch by hand

| Bind | Application | Package | Verdict |
|---|---|---|---|
| `SUPER+RETURN` | ghostty | `ghostty` | keep |
| `SUPER+B` | chromium | `chromium` | keep |
| `SUPER+SHIFT+B` | chromium Profile 4 | `chromium` | keep |
| `SUPER+ALT+RETURN` | tmux | `tmux` | keep |
| `SUPER+CTRL+RETURN` | herdr | `herdr` (rebuild) | keep |
| `SUPER+F` | nautilus | `nautilus` | keep |
| `SUPER+N` | neovim | `neovim` | keep |
| `SUPER+A` | btop | `btop` | keep |
| `SUPER+D` | vesktop | `vesktop` | keep |
| `SUPER+S` | steam | `steam` | keep |
| `SUPER+SPACE` | fuzzel | `fuzzel` (new) | keep |
| `PRINT` | satty + grim + slurp | `satty` (new), `grim`, `slurp` | keep |
| `ALT+PRINT` | gpu-screen-recorder | `gpu-screen-recorder` | keep |

Also installed and used without a bind: `firefox`, `vesktop`, `signal-desktop`,
`mpv`, `libreoffice-fresh`, `obsidian`, `xournalpp`, `kdenlive`, `docker`, `git`,
`visual-studio-code-bin`, the dev toolchains (see the tables below).

## Packages by area

### Base system, boot, filesystems

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `amd-ucode` | Microcode update image for AMD CPUs | 603 KB | in use |
| `avahi` | Service Discovery for Linux using mDNS/DNS-SD (compatible with Bonjour) | 2 MB | in use |
| `base` | Minimal package set to define a basic Arch Linux installation | 0 KB | in use |
| `base-devel` | Basic tools to build Arch Linux packages | 0 KB | in use |
| `bind` | A complete, highly portable implementation of the DNS protocol | 7 MB | in use |
| `bluez` | Daemons for the bluetooth protocol stack | 2 MB | in use |
| `bluez-tools` | A set of tools to manage Bluetooth devices for Linux | 265 KB | drop |
| `bluez-utils` | Development and debugging utilities for the bluetooth protocol stack | 4 MB | drop |
| `bolt` | Thunderbolt 3 device manager | 439 KB | in use |
| `btrfs-progs` | Btrfs filesystem utilities | 7 MB | in use |
| `dosfstools` | DOS filesystem utilities | 409 KB | in use |
| `efibootmgr` | Linux user-space application to modify the EFI Boot Manager | 84 KB | keep (plumbing) |
| `exfatprogs` | exFAT filesystem userspace utilities for the Linux Kernel exfat driver | 347 KB | drop |
| `expac` | alpm data (pacman database) extraction utility | 33 KB | in use |
| `fakeroot` | Tool for simulating superuser privileges | 142 KB | in use |
| `gnome-keyring` | Stores passwords and encryption keys | 3 MB | in use |
| `inetutils` | A collection of common network programs | 1 MB | keep (plumbing) |
| `kernel-modules-hook` | Keeps your system fully functional after a kernel upgrade | 2 KB | in use |
| `less` | A terminal based program for viewing text files | 338 KB | in use |
| `libsecret` | Library for storing and retrieving passwords and other secrets | 1 MB | in use |
| `limine` | An advanced, portable, multiprotocol bootloader | 5 MB | in use |
| `linux` | The Linux kernel and modules | 162 MB | in use |
| `linux-firmware` | Firmware files for Linux - Default set | 0 KB | in use |
| `linux-headers` | Headers and scripts for building modules for the Linux kernel | 321 MB | in use |
| `linux-omarchy` | The Omarchy Linux (BORE CPU scheduler, ADIOS I/O scheduler) kernel and modules | 175 MB | in use |
| `linux-omarchy-headers` | Headers and scripts for building modules for the Omarchy Linux (BORE CPU scheduler, ADIOS I/O scheduler) kernel | 330 MB | in use |
| `man-db` | A utility for reading man pages | 2 MB | keep (plumbing) |
| `networkmanager` | Network connection manager and user applications | 18 MB | in use |
| `nss-mdns` | glibc plugin providing host name resolution via mDNS | 108 KB | in use |
| `ntfs-3g` | NTFS FUSE driver | 171 KB | in use |
| `ntfsprogs` | NTFS userspace utilities | 851 KB | in use |
| `pacman-contrib` | Contributed scripts and tools for pacman systems | 129 KB | in use |
| `pass` | Stores, retrieves, generates, and synchronizes passwords securely | 47 KB | in use |
| `plocate` | Alternative to locate, faster and compatible with mlocate's database. | 516 KB | in use |
| `plymouth` | Graphical boot splash screen | 2 MB | in use |
| `proton-vpn-cli` | Official ProtonVPN CLI Linux app | 433 KB | in use |
| `sbctl` | Secure Boot key manager | 10 MB | in use |
| `systemd-resolvconf` | systemd resolvconf replacement (for use with systemd-resolved) | 0 KB | in use |
| `tailscale` | A mesh VPN that makes it easy to connect your devices, wherever they are. | 51 MB | in use |
| `tldr` | Command line client for tldr, a collection of simplified man pages. | 126 KB | keep (plumbing) |
| `tzupdate` | Set the system timezone based on IP geolocation | 2 MB | in use |
| `ufw` | Uncomplicated and easy to use CLI tool for managing a netfilter firewall | 528 KB | in use |
| `ufw-docker` | To fix the Docker and UFW security flaw without disabling iptables. | 65 KB | in use |
| `unzip` | For extracting and viewing files in .zip archives | 308 KB | keep (plumbing) |
| `wireless-regdb` | Central Regulatory Domain Database | 22 KB | in use |
| `zram-generator` | Systemd unit generator for zram devices | 768 KB | in use |

### Desktop session and window manager

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `bash-completion` | Programmable completion for the bash shell | 1019 KB | in use |
| `brightnessctl` | Lightweight brightness control tool | 28 KB | keep (plumbing) |
| `ddcutil` | Query and change Linux monitor settings using DDC/CI and USB. | 3 MB | in use |
| `evince` | Document viewer (PDF, PostScript, XPS, djvu, dvi, tiff, cbr, cbz, cb7, cbt) | 12 MB | in use |
| `feh` | Fast and light imlib2-based image viewer | 1 MB | in use |
| `gvfs-mtp` | Virtual filesystem implementation for GIO - MTP backend (Android, media player) | 157 KB | in use |
| `gvfs-nfs` | Virtual filesystem implementation for GIO - NFS backend | 50 KB | in use |
| `gvfs-smb` | Virtual filesystem implementation for GIO - SMB/CIFS backend (Windows file sharing) | 85 KB | in use |
| `hyprland` | a highly customizable dynamic tiling Wayland compositor | 64 MB | in use |
| `hyprland-guiutils` | Hyprland GUI utilities | 797 KB | in use |
| `hyprland-preview-share-picker` | An alternative share picker for hyprland with window and monitor previews | 6 MB | in use |
| `hyprpicker` | A wlroots-compatible Wayland color picker that does not suck | 231 KB | in use |
| `hyprsunset` | An application to enable a blue-light filter on Hyprland | 261 KB | in use |
| `libcamera` | A complex camera support library for Linux, Android, and ChromeOS | 2 MB | drop |
| `omarchy` | Beautiful, modern, and opinionated Arch Linux by DHH | 83 MB | in use |
| `omarchy-hyprland-titlebars` | Titlebars for Omarchy's floating workspaces | 420 KB | in use |
| `omarchy-keyring` | Omarchy keyring | 1 KB | in use |
| `omarchy-nvim` | Pre-built LazyVim configuration with cached plugins | 56 MB | drop |
| `omarchy-power-profiles-daemon` | Makes power profiles handling available over D-Bus (with NVIDIA RTX Spark and Snapdragon X CPU profiles) | 165 KB | in use |
| `omarchy-settings` | Omarchy user defaults, /etc/skel content, fonts, plymouth theme, and support helpers | 10 MB | in use |
| `qt5-wayland` | Provides APIs for Wayland | 6 MB | drop |
| `qt6-imageformats` | Plugins for additional image formats: TIFF, MNG, TGA, WBMP | 269 KB | in use |
| `quickshell` | Flexible toolkit for making desktop shells with QtQuick | 6 MB | in use |
| `sddm` | QML based X11 and Wayland display manager | 5 MB | in use |
| `sushi` | A quick previewer for Nautilus | 375 KB | in use |
| `udiskie` | Removable disk automounter using udisks | 941 KB | in use |
| `uwsm` | A standalone Wayland session manager | 333 KB | in use |
| `wl-clip-persist` | Keep Wayland clipboard even after programs close | 3 MB | keep (plumbing) |
| `wl-clipboard` | Command-line copy/paste utilities for Wayland | 101 KB | in use |
| `xdg-desktop-portal-gtk` | A backend implementation for xdg-desktop-portal using GTK | 428 KB | in use |
| `xdg-desktop-portal-hyprland` | xdg-desktop-portal backend for hyprland | 817 KB | keep (plumbing) |
| `xdg-terminal-exec` | Proposal for XDG Default Terminal Execution Specification and shell-based reference implementation | 47 KB | in use |

### Terminals and command line

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `alacritty` | A cross-platform, GPU-accelerated terminal emulator | 8 MB | drop |
| `bat` | Cat clone with syntax highlighting and git integration | 5 MB | in use |
| `btop` | A monitor of system resources, bpytop ported to C++ | 2 MB | in use |
| `caligula` | A user-friendly, lightweight TUI for disk imaging | 3 MB | drop |
| `cliamp` | A retro terminal music player inspired by Winamp 2.x | 75 MB | drop |
| `d2-bin` | A modern diagram scripting language that turns text to diagrams | 40 MB | in use |
| `disktree-bin` | Disk space treemap for Omarchy: see what fills a disk by kind, mark what should go, and remove it | 28 MB | drop |
| `entr` | Run arbitrary commands when files change | 33 KB | in use |
| `eza` | A modern replacement for ls (community fork of exa) | 2 MB | in use |
| `fastfetch` | A feature-rich and performance oriented neofetch like system information tool | 2 MB | in use |
| `fd` | Simple, fast and user-friendly alternative to find | 3 MB | in use |
| `foot` | Fast, lightweight, and minimalistic Wayland terminal emulator | 812 KB | drop |
| `fzf` | Command-line fuzzy finder | 5 MB | in use |
| `ghostty` | Fast, native, feature-rich terminal emulator pushing modern features | 33 MB | in use |
| `git` | the fast distributed version control system | 34 MB | in use |
| `github-cli` | The GitHub CLI | 40 MB | in use |
| `glow` | Command-line markdown renderer | 18 MB | drop |
| `gum` | A tool for glamorous shell scripts | 14 MB | in use |
| `herdr` | Herdr terminal workspace manager for AI coding agents | 21 MB | in use |
| `inotify-tools` | a C library and a set of command-line programs for Linux providing a simple interface to inotify. | 2 MB | in use |
| `inxi` | Full featured CLI system information tool | 1 MB | drop |
| `jq` | Command-line JSON processor | 481 KB | in use |
| `lazygit` | Simple terminal UI for git commands | 20 MB | in use |
| `nmap` | Utility for network discovery and security auditing | 27 MB | in use |
| `qrencode` | C library for encoding data in a QR Code symbol. | 111 KB | keep (plumbing) |
| `ripgrep` | A search tool that combines the usability of ag with the raw speed of grep | 4 MB | in use |
| `sl` | Steam Locomotive runs across your terminal when you type "sl" as you meant to type "ls" | 27 KB | drop |
| `socat` | Multipurpose relay | 580 KB | keep (plumbing) |
| `starship` | The cross-shell prompt for astronauts | 12 MB | in use |
| `tmux` | Terminal multiplexer | 1 MB | in use |
| `ttfx` | Terminal text effects as a single static binary — Rust port of terminaltexteffects | 3 MB | drop |
| `usage` | A specification for CLIs | 11 MB | in use |
| `vhs` | A tool for recording terminal GIFs | 23 MB | in use |
| `whois` | Intelligent WHOIS client | 245 KB | keep (plumbing) |
| `wtype` | xdotool type for wayland | 24 KB | keep |
| `xmlstarlet` | A set of tools to transform, query, validate, and edit XML documents | 552 KB | in use |
| `zbar` | Application and library for reading bar codes from various sources | 804 KB | in use |
| `zoxide` | A smarter cd command for your terminal | 1 MB | in use |

### Browsers, comms and remote desktop

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `chromium` | A web browser built for speed, simplicity, and security | 431 MB | in use |
| `discord` | All-in-one voice and text chat for gamers | 7 MB | drop |
| `firefox` | Fast, Private & Safe Web Browser | 302 MB | in use |
| `gliff` | Hyprland remote desktop over SSH (GPU H.264, 4:4:4) | 16 MB | drop |
| `jellyfin-server` | Jellyfin server backend | 65 MB | drop |
| `jellyfin-web` | Web client for Jellyfin | 55 MB | drop |
| `moonlight-qt` | GameStream client for PCs | 2 MB | drop |
| `obsidian` | A powerful knowledge base that works on top of a local folder of plain text Markdown files | 26 MB | drop |
| `qbittorrent-nox` | An advanced BitTorrent client programmed in C++, based on Qt toolkit and libtorrent-rasterbar, w/o gui | 12 MB | drop |
| `signal-desktop` | Signal Private Messenger for Linux | 365 MB | drop |
| `tigervnc` | Suite of VNC servers and clients based on the VNC 4 branch of TightVNC | 7 MB | drop |
| `vesktop` | A standalone Electron-based Discord app with Vencord & improved Linux support | 277 MB | in use |

### Editors and languages

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `aspnet-runtime` | The ASP.NET Core runtime | 23 MB | in use |
| `aspnet-targeting-pack` | The ASP.NET Core targeting pack | 45 MB | in use |
| `boost` | Free peer-reviewed portable C++ source libraries (development headers) | 151 MB | drop |
| `bun-bin` | All-in-one JavaScript runtime built for speed, with bundler, transpiler, test runner, and package manager. Includes bunx, shell completions and support for baseline CPUs | 85 MB | in use |
| `clang` | C language family frontend for LLVM | 115 MB | in use |
| `clojure` | Lisp dialect for the JVM | 13 MB | drop |
| `docker` | Pack, ship and run any application as a lightweight container | 119 MB | in use |
| `docker-buildx` | Docker CLI plugin for extended build capabilities with BuildKit | 65 MB | in use |
| `docker-compose` | Fast, isolated development environments using Docker | 28 MB | in use |
| `dotnet-runtime` | The .NET Core runtime | 74 MB | in use |
| `dotnet-runtime-9.0` | The .NET Core runtime | 70 MB | in use |
| `dotnet-sdk` | The .NET Core SDK | 358 MB | in use |
| `dotnet-source-built-artifacts` | Internal package for building the .NET Core SDK | 1.2 GB | in use |
| `elixir` | A dynamic, functional language for building scalable and maintainable applications | 10 MB | in use |
| `emscripten` | Compile C and C++ into highly-optimizable JavaScript for the web | 1.3 GB | in use |
| `erlang` | General-purpose concurrent functional programming language developed by Ericsson | 0 KB | in use |
| `gcc-fortran` | Fortran front-end for GCC | 49 MB | in use |
| `geckodriver` | Proxy for using W3C WebDriver-compatible clients to interact with Gecko-based browsers. | 5 MB | drop |
| `gleam` | Friendly programming language for building type-safe and scalable systems | 22 MB | in use |
| `go` | Core compiler tools for the Go programming language | 227 MB | in use |
| `hype` | Simple Markdown presentations with a visual slide editor | 689 KB | drop |
| `julia` | High-level, high-performance, dynamic programming language | 571 MB | in use |
| `jupyterlab` | JupyterLab computational environment | 36 MB | drop |
| `lazydocker` | A simple terminal UI for docker and docker-compose, written in Go with the gocui library. | 13 MB | drop |
| `leiningen-with-completion` | For automating Clojure projects without setting your hair on fire. | 12 MB | drop |
| `libqalculate` | Multi-purpose desktop calculator | 16 MB | in use |
| `llvm` | Compiler infrastructure | 85 MB | in use |
| `lua51` | Powerful lightweight programming language designed for extending applications | 888 KB | drop |
| `luarocks` | Deployment and management system for Lua modules | 7 KB | drop |
| `mariadb-libs` | MariaDB libraries | 24 MB | in use |
| `mise-bin` | dev tools, env vars, task runner | 146 MB | drop |
| `neovim` | Fork of Vim aiming to improve user experience, plugins, and GUIs | 31 MB | in use |
| `npm` | JavaScript package manager | 9 MB | in use |
| `odin` | Data-oriented programming language | 122 MB | in use |
| `omawrite` | Dead-simple Markdown writing app built with Qt Quick | 949 KB | drop |
| `or-tools` | Google's Operations Research tools. | 36 MB | drop |
| `pinta` | Drawing/editing program modeled after Paint.NET. It's goal is to provide a simplified alternative to GIMP for casual users | 20 MB | drop |
| `postgresql-libs` | Sophisticated object-relational DBMS - Client binaries and libraries | 11 MB | in use |
| `python-gobject` | Python bindings for GLib/GObject/GIO/GTK | 2 MB | in use |
| `python-numpy` | Scientific tools for Python | 50 MB | in use |
| `python-poetry` | Python dependency management and packaging made easy | 4 MB | drop |
| `python-poetry-core` | Poetry PEP 517 Build Backend & Core Utilities | 2 MB | drop |
| `python310` | The Python programming language (version 3.10) | 55 MB | in use |
| `python39` | Major release 3.9 of the Python high-level programming language | 53 MB | drop |
| `qemu-base` | A basic QEMU setup for headless environments | 48 KB | in use |
| `qemu-user-static-binfmt` | Binary format rules for QEMU static user mode emulation | 55 KB | in use |
| `r` | Language and environment for statistical computing and graphics | 78 MB | in use |
| `ruby` | An object-oriented language for quick and easy programming | 17 MB | in use |
| `rustup` | The Rust toolchain installer | 11 MB | in use |
| `terraform` | HashiCorp tool for building and updating infrastructure as code idempotently | 114 MB | drop |
| `tree-sitter-cli` | CLI tool for developing, testing, and using Tree-sitter parsers | 9 MB | keep |
| `typora` | A minimal markdown editor and reader. | 353 MB | drop |
| `uv` | An extremely fast Python package installer and resolver written in Rust | 46 MB | in use |
| `v8-r` | Google's open source JavaScript and WebAssembly engine | 56 MB | drop |
| `visual-studio-code-bin` | Visual Studio Code (vscode): Editor for building and debugging modern web and cloud applications (official binary version) | 1.0 GB | in use |
| `yay` | Yet another yogurt. Pacman wrapper and AUR helper written in go. | 11 MB | in use |
| `z3` | High-performance theorem prover | 38 MB | drop |
| `zig` | a general-purpose programming language and toolchain for maintaining robust, optimal, and reusable software | 204 MB | in use |

### Omarchy applications (no Arch package)

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `aether` | Desktop theming application - extract colors from wallpapers and apply cohesive themes | 20 MB | drop |
| `asdcontrol` | Control brightness on Apple Displays connected via USB-C | 31 KB | drop |
| `localsend` | An open source cross-platform alternative to AirDrop | 67 MB | drop |
| `monologue` | A simple, theme-synced webcam recorder for Omarchy | 311 KB | drop |
| `omacalc` | Dead-simple calculator built with Qt Quick | 297 KB | drop |
| `omacut` | Dead-simple video length trimmer built with Qt Quick and ffmpeg | 275 KB | drop |
| `omasnap` | Native Wayland screenshot and annotation overlay for Hyprland | 2 MB | drop |
| `owe` | High-performance wallpaper engine for Omarchy (mp4, gif, stills) | 491 KB | drop |
| `owe-lockfeed` | Lock screen video feed module for the OWE wallpaper engine | 75 KB | drop |
| `signed` | Sign PDFs and fill them in with text and dates | 453 KB | drop |
| `tobi-try` | Fresh directories for every vibe. | 79 KB | drop |
| `vortix` | A TUI for WireGuard and OpenVPN with real-time telemetry and leak guarding | 7 MB | drop |

### Media, graphics and capture

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `ffmpegthumbnailer` | Lightweight video thumbnailer that can be used by file managers | 285 KB | keep |
| `flameshot` | Powerful yet simple to use screenshot software | 3 MB | drop |
| `gpu-screen-recorder` | A shadowplay-like screen recorder for Linux. The fastest screen recorder for Linux | 505 KB | in use |
| `grim` | Screenshot utility for Wayland | 46 KB | in use |
| `gst-plugin-pipewire` | Multimedia graph framework - pipewire plugin | 175 KB | in use |
| `hyprshot` | Hyprland screenshot utility | 9 KB | drop |
| `imagemagick` | An image viewing/manipulation program | 22 MB | in use |
| `imv` | Image viewer for Wayland and X11 | 240 KB | drop |
| `kdenlive` | A non-linear video editor for Linux using the MLT video framework | 94 MB | drop |
| `ksnip` | Qt-based screenshot tool that provides many annotation features | 3 MB | drop |
| `libreoffice-fresh` | LibreOffice branch which contains new features and program enhancements | 423 MB | in use |
| `libvips` | A fast image processing library with low memory needs | 6 MB | in use |
| `mpv` | a free, open source, and cross-platform media player | 6 MB | in use |
| `mpv-mpris` | MPRIS plugin for mpv | 39 KB | in use |
| `obs-studio` | Free, open source software for live streaming and recording | 25 MB | drop |
| `slurp` | Select a region in a Wayland compositor | 39 KB | in use |
| `spotify` | A proprietary music streaming service | 386 MB | drop |
| `streamlink` | CLI program that launches streams from various streaming services in a custom video player (livestreamer fork) | 7 MB | in use |
| `tesseract` | An OCR program | 5 MB | keep (plumbing) |
| `tesseract-data-eng` | Tesseract OCR data (eng) | 22 MB | in use |
| `xournalpp` | Handwriting notetaking software with PDF annotation support | 8 MB | drop |
| `yt-dlp` | A youtube-dl fork with additional features and fixes | 32 MB | keep (plumbing) |

### Audio

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `alsa-utils` | Advanced Linux Sound Architecture - Utilities | 2 MB | keep (plumbing) |
| `libpulse` | A featureful, general-purpose sound server (client library) | 1 MB | in use |
| `pamixer` | Pulseaudio command-line mixer like amixer | 272 KB | keep (plumbing) |
| `pipewire` | Low-latency audio/video router and processor | 1 MB | in use |
| `pipewire-alsa` | Low-latency audio/video router and processor - ALSA configuration | 1 KB | in use |
| `pipewire-jack` | Low-latency audio/video router and processor - JACK replacement | 701 KB | in use |
| `pipewire-pulse` | Low-latency audio/video router and processor - PulseAudio replacement | 562 KB | in use |
| `wireplumber` | Session / policy manager implementation for PipeWire | 1 MB | in use |

### Input methods and fonts

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `fcitx5` | Next generation of fcitx, cross-platform input method framework | 18 MB | in use |
| `fcitx5-chewing` | Chewing Wrapper for Fcitx5 | 143 KB | in use |
| `fcitx5-chinese-addons` | Addons related to Chinese, including IME previous bundled inside fcitx4 | 4 MB | in use |
| `fcitx5-gtk` | Fcitx5 gtk im module and glib based dbus client library | 320 KB | keep (plumbing) |
| `fcitx5-hangul` | Hangul Wrapper for Fcitx5 | 154 KB | in use |
| `fcitx5-mozc` | Fcitx5 Module of A Japanese Input Method for Chromium OS, Windows, Mac and Linux (the Open Source Edition of Google Japanese Input) | 28 MB | in use |
| `fcitx5-qt` | Fcitx5 Qt Library (Qt5 & Qt6 integrations) | 2 MB | in use |
| `fontconfig` | Library for configuring and customizing font access | 1 MB | in use |
| `gnome-themes-extra` | Extra GNOME themes (legacy HighContrast icon theme and index files for Adwaita) | 4 MB | in use |
| `noto-fonts` | Google Noto TTF fonts | 107 MB | in use |
| `noto-fonts-cjk` | Google Noto CJK fonts | 299 MB | in use |
| `noto-fonts-emoji` | Google Noto Color Emoji font | 10 MB | in use |
| `noto-fonts-extra` | Google Noto TTF fonts - additional variants | 331 MB | in use |
| `ttf-cascadia-mono-nerd` | Patched font Cascadia Mono (Caskaydia) from nerd fonts library | 98 MB | in use |
| `ttf-ia-writer` | Subset of the fonts provided by iA Writer | 2 MB | in use |
| `ttf-jetbrains-mono-nerd-basic` | Basic JetBrains Mono Nerd Font family | 10 MB | in use |
| `woff2-font-awesome` | Iconic font designed for Bootstrap - woff2 format | 260 KB | in use |
| `yaru-icon-theme` | Yaru default ubuntu icon theme | 63 MB | in use |

### Gaming and GPU

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `lib32-nvidia-utils` | NVIDIA drivers utilities (32-bit) | 563 MB | in use |
| `libstrangle` | Simple FPS Limiter | 432 KB | drop |
| `libva-nvidia-driver` | VA-API implementation that uses NVDEC as a backend | 152 KB | in use |
| `nvidia-open-dkms` | NVIDIA open kernel modules - module sources | 111 MB | in use |
| `steam` | Valve's digital software delivery system | 20 MB | in use |
| `vulkan-radeon` | Open-source Vulkan driver for AMD GPUs | 18 MB | in use |
| `wine-staging` | A compatibility layer for running Windows programs - Staging branch | 598 MB | drop |

### Files, disks and misc

| Package | What it is | Size | Verdict |
|---|---|---|---|
| `cups` | OpenPrinting CUPS - daemon package | 13 MB | drop |
| `cups-filters` | OpenPrinting CUPS Filters | 1 MB | drop |
| `cups-pk-helper` | A helper that makes system-config-printer use PolicyKit | 345 KB | drop |
| `ex-vi-compat` | The ex and vi commands based on vim's compatibility modes | 1 KB | in use |
| `gnome-disk-utility` | Disk Management Utility for GNOME | 7 MB | keep (plumbing) |
| `libyaml` | YAML 1.1 library | 184 KB | in use |
| `nautilus` | Default file manager for GNOME | 14 MB | in use |
| `nautilus-python` | Python bindings for the Nautilus Extension API | 217 KB | in use |
| `nfs-utils` | Support programs for Network File Systems | 1 MB | in use |
| `pesign` | Linux tools for signed PE-COFF binaries | 364 KB | in use |
| `rclone` | rsync for cloud storage | 110 MB | drop |
| `system-config-printer` | A CUPS printer configuration tool and status applet | 8 MB | drop |

## The 53 packages that ran nothing in 30 days

Evidence for the pruning: these had no binary read in a month. Verdicts come from
`todo/needs.md` batch 2 — 30 drop, 17 kept as plumbing, and the five that were
judged by hand.

| Package | Size | Verdict | Note |
|---|---|---|---|
| `aether` | 20 MB | drop |  |
| `alacritty` | 8 MB | drop |  |
| `alsa-utils` | 2 MB | keep (plumbing) | amixer |
| `asdcontrol` | 31 KB | drop |  |
| `bluez-tools` | 265 KB | drop |  |
| `bluez-utils` | 4 MB | drop |  |
| `boost` | 151 MB | drop |  |
| `brightnessctl` | 28 KB | keep (plumbing) | internal panel brightness (unused, no internal panel) |
| `caligula` | 3 MB | drop |  |
| `clojure` | 13 MB | drop |  |
| `efibootmgr` | 84 KB | keep (plumbing) | boot entries |
| `exfatprogs` | 347 KB | drop | dropped, formatting only |
| `fcitx5-gtk` | 320 KB | keep (plumbing) | IME for GTK apps |
| `ffmpegthumbnailer` | 285 KB | keep | nautilus video thumbnails |
| `flameshot` | 3 MB | drop |  |
| `geckodriver` | 5 MB | drop |  |
| `glow` | 18 MB | drop |  |
| `gnome-disk-utility` | 7 MB | keep (plumbing) | disk GUI |
| `hyprshot` | 9 KB | drop |  |
| `imv` | 240 KB | drop |  |
| `inetutils` | 1 MB | keep (plumbing) | telnet/ftp-era tools |
| `inxi` | 1 MB | drop | dropped, hardware report |
| `ksnip` | 3 MB | drop |  |
| `lazydocker` | 13 MB | drop |  |
| `leiningen-with-completion` | 12 MB | drop |  |
| `libcamera` | 2 MB | drop |  |
| `libstrangle` | 432 KB | drop |  |
| `lua51` | 888 KB | drop |  |
| `luarocks` | 7 KB | drop |  |
| `man-db` | 2 MB | keep (plumbing) | man pages |
| `obs-studio` | 25 MB | drop | dropped: gpu-screen-recorder covers clips |
| `or-tools` | 36 MB | drop |  |
| `pamixer` | 272 KB | keep (plumbing) | volume CLI |
| `pinta` | 20 MB | drop |  |
| `python39` | 53 MB | drop |  |
| `qrencode` | 111 KB | keep (plumbing) | QR codes |
| `qt5-wayland` | 6 MB | drop |  |
| `sl` | 27 KB | drop |  |
| `socat` | 580 KB | keep (plumbing) | socket plumbing |
| `system-config-printer` | 8 MB | drop |  |
| `terraform` | 114 MB | drop |  |
| `tesseract` | 5 MB | keep (plumbing) | OCR (no bind yet) |
| `tigervnc` | 7 MB | drop | dropped with SUPER+R / VNC to Tom |
| `tldr` | 126 KB | keep (plumbing) | short man pages |
| `tree-sitter-cli` | 9 MB | keep | nvim parser builds |
| `unzip` | 308 KB | keep (plumbing) | archives |
| `v8-r` | 56 MB | drop |  |
| `whois` | 245 KB | keep (plumbing) | whois lookups |
| `wl-clip-persist` | 3 MB | keep (plumbing) | clipboard survives app exit |
| `wtype` | 24 KB | keep |  |
| `xdg-desktop-portal-hyprland` | 817 KB | keep (plumbing) | screen share + camera portal |
| `yt-dlp` | 32 MB | keep (plumbing) | video downloads |
| `z3` | 38 MB | drop |  |

## Notes

- **Foreign packages (8)**: `d2-bin`, `leiningen-with-completion`, `libstrangle`,
  `or-tools`, `python310`, `python39`, `v8-r`, `vesktop` — not from Arch repos. All
  but `python310` and `vesktop` are drops.
- **From the `[omarchy]` repo (42)**: everything named `omarchy-*` plus
  `quickshell owe owe-lockfeed hype omacut omasnap omawrite omacalc monologue aether
  herdr gliff cliamp disktree-bin tobi-try ttfx vortix signed spotify typora bun-bin
  mise-bin localsend visual-studio-code-bin yay ufw-docker tzupdate yaru-icon-theme
  ttf-ia-writer ttf-jetbrains-mono-nerd-basic asdcontrol linux-omarchy*`. Removing the
  repo and the package takes the lot; `herdr`, `bun-bin`, `mise-bin`,
  `visual-studio-code-bin`, `yay`, `uv?` need AUR/`extra` replacements first.
- **Sizes** are `pacman`'s installed size; the dependency closure that `pacman -Rns`
  removes is much larger (the Omarchy package alone pulls 411 packages).
