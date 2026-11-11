#!/usr/bin/env python3
"""Regenerate docs/jason/packages.md: every explicit package, its size, what it is,
and the verdict recorded in docs/jason/todo/needs.md.

Verdicts live in the DROP / KEEP_PLUMB sets below -- edit those, not the generated
markdown, or your edit is gone next time this runs.

Usage: scripts/jason-package-inventory.py [unused-list]
The unused list is the output of scripts/pacman-atime-audit.sh 30 (default
/tmp/unused30.txt); it is only used to decide "keep" vs "in use".
"""
import subprocess, re, os, sys, textwrap

def sh(c): return subprocess.run(c, shell=True, capture_output=True, text=True).stdout

pkgs = sh("expac -Q '%n|%m|%d' $(pacman -Qeq)").strip().splitlines()
data = {}
for line in pkgs:
    n, m, d = line.split('|', 2)
    data[n] = (int(m or 0), d)
unused_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/unused30.txt'
unused = set(open(unused_file).read().split())
unused = {u for u in unused if not u.startswith('---')}

DROP = set("""aether owe owe-lockfeed hype omawrite omasnap gliff cliamp monologue
disktree-bin ttfx omacut omacalc localsend tobi-try vortix tigervnc obs-studio
exfatprogs inxi discord
 jupyterlab kdenlive mise-bin moonlight-qt obsidian qbittorrent-nox signal-desktop
 signed xournalpp""".split()) | set("""alacritty glow sl caligula pinta imv clojure
leiningen-with-completion lua51 luarocks or-tools python39 v8-r z3 boost terraform
asdcontrol bluez-tools bluez-utils lazydocker system-config-printer qt5-wayland
libstrangle libcamera geckodriver flameshot ksnip hyprshot""".split()) | set("""wine-staging
typora spotify rclone jellyfin-server jellyfin-web cups cups-filters cups-pk-helper
python-poetry python-poetry-core omarchy-nvim foot""".split())

KEEP_PLUMB = set("""efibootmgr man-db unzip inetutils socat whois tldr qrencode
wl-clip-persist brightnessctl alsa-utils pamixer fcitx5-gtk
xdg-desktop-portal-hyprland gnome-disk-utility yt-dlp tesseract""".split())

SECTIONS = [
 ("Base system, boot, filesystems", """base base-devel fakeroot linux linux-headers linux-firmware amd-ucode
 linux-omarchy linux-omarchy-headers limine sbctl plymouth efibootmgr btrfs-progs dosfstools
 ntfs-3g ntfsprogs exfatprogs zram-generator kernel-modules-hook pacman-contrib expac
 tzupdate limine-snapper-sync snapper less man-db unzip tldr plocate bind inetutils
 networkmanager systemd-resolvconf wireless-regdb nss-mdns avahi bolt bluez bluez-utils
 bluez-tools ufw ufw-docker tailscale proton-vpn-cli pass gnome-keyring libsecret"""),
 ("Desktop session and window manager", """hyprland hyprland-guiutils hyprland-preview-share-picker hyprpicker hyprsunset
 uwsm sddm xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-terminal-exec quickshell
 omarchy omarchy-keyring omarchy-settings omarchy-hyprland-titlebars omarchy-power-profiles-daemon
 omarchy-nvim feh qt6-imageformats gvfs-nfs gvfs-smb gvfs-mtp udiskie sushi evince
 omarchy-nvim ddcutil plymouth libcamera qt5-wayland brightnessctl wl-clipboard
 wl-clip-persist bash-completion"""),
 ("Terminals and command line", """ghostty foot alacritty tmux herdr btop eza fd ripgrep fzf jq gum bat starship zoxide
 fastfetch entr inotify-tools nmap socat whois inxi xmlstarlet qrencode wtype zbar vhs sl
 glow caligula ttfx usage disktree-bin cliamp lazygit github-cli git d2-bin cloc"""),
 ("Browsers, comms and remote desktop", """chromium firefox discord vesktop signal-desktop moonlight-qt
 tigervnc qbittorrent-nox obsidian jellyfin-server jellyfin-web gliff"""),
 ("Editors and languages", """neovim visual-studio-code-bin omawrite hype typora python310 python39 python-numpy
 python-gobject python-poetry python-poetry-core jupyterlab uv npm bun-bin mise-bin
 rustup go zig julia r ruby elixir erlang gleam clojure leiningen-with-completion
 lua51 luarocks emscripten odin dotnet-runtime dotnet-runtime-9.0 dotnet-sdk
 aspnet-runtime aspnet-targeting-pack dotnet-source-built-artifacts clang llvm gcc-fortran
 boost z3 or-tools v8-r postgresql-libs mariadb-libs libqalculate geckodriver
 tree-sitter-cli docker docker-buildx docker-compose qemu-base qemu-user-static-binfmt
 yay pinta lazydocker terraform"""),
 ("Omarchy applications (no Arch package)", """hype omawrite omasnap gliff cliamp monologue disktree-bin ttfx omacut omacalc
 aether owe owe-lockfeed localsend tobi-try vortix signed asdcontrol"""),
 ("Media, graphics and capture", """mpv mpv-mpris streamlink imagemagick libvips kdenlive obs-studio gpu-screen-recorder
 grim slurp satty yt-dlp flameshot ksnip hyprshot imv tesseract tesseract-data-eng
 ffmpegthumbnailer libreoffice-fresh xournalpp spotify obs-studio aether owe owe-lockfeed
 pinta gst-plugin-pipewire"""),
 ("Audio", """pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber alsa-utils pamixer
 libpulse"""),
 ("Input methods and fonts", """fcitx5 fcitx5-chewing fcitx5-chinese-addons fcitx5-gtk fcitx5-hangul fcitx5-mozc
 fcitx5-qt noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra fontconfig
 ttf-cascadia-mono-nerd ttf-ia-writer ttf-jetbrains-mono-nerd-basic woff2-font-awesome
 yaru-icon-theme gnome-themes-extra"""),
 ("Gaming and GPU", """steam lib32-nvidia-utils vulkan-radeon nvidia-open-dkms libva-nvidia-driver
 wine-staging libstrangle moonlight-qt"""),
 ("Files, disks and misc", """nautilus nautilus-python gnome-disk-utility imv udiskie rclone cups cups-filters
 cups-pk-helper system-config-printer inxi gvfs-mtp gvfs-nfs gvfs-smb btrfs-progs libyaml pesign signed nfs-utils ex-vi-compat"""),
]
sec_of = {}
for name, names in SECTIONS:
    for p in names.split():
        sec_of.setdefault(p, name)

def verdict(p):
    if p in DROP: return "drop"
    if p in KEEP_PLUMB or p in unused: return "keep (plumbing)" if p in KEEP_PLUMB else "keep"
    return "in use"

def size(b):   # expac %m is bytes
    if b >= 1073741824: return f"{b/1073741824:.1f} GB"
    if b >= 1048576: return f"{b/1048576:.0f} MB"
    return f"{b/1024:.0f} KB"

rows_by_sec = {}
other = []
for p, (mb, desc) in data.items():
    s = sec_of.get(p)
    rec = (p, mb, desc, verdict(p))
    if s: rows_by_sec.setdefault(s, []).append(rec)
    else: other.append(rec)

total = sum(mb for mb, _ in data.values())
drop_mb = sum(data[p][0] for p in data if verdict(p) == "drop")
lines = []
A = lines.append
A("# Packages, applications and features — Jason, 2026-11-11\n")
A("Everything installed on this machine that a person chose, what it is for, and the")
A("verdict from the walkthrough ([`todo/needs.md`](todo/needs.md)). Generated from")
A("`pacman -Qeq` + `expac` + `scripts/pacman-atime-audit.sh 30`, so the sizes and")
A("descriptions are the machine's own.\n")
A(f"**{len(data)} explicit packages** (`pacman -Qe`), {total/1073741824:.1f} GiB installed,")
A("out of 1475 packages in total — the rest is dependencies. Verdicts: **drop** =")
A("decided out, **keep (plumbing)** = never run directly but needed, **keep** = never")
A("run in 30 days but still wanted, **in use** = a binary ran in the last 30 days.\n")
nd = sum(1 for p in data if verdict(p)=="drop")
A(f"- **{nd} packages drop**, freeing **{drop_mb/1073741824:.1f} GiB** outright, plus the")
A("  dependency closure `pacman -Rns` takes with them.")
A(f"- {sum(1 for p in data if verdict(p)=='in use')} in use, " +
  f"{sum(1 for p in data if verdict(p).startswith('keep'))} kept by decision.\n")

A("## Features the desktop must provide\n")
A("| Feature | What provides it | Verdict |")
A("|---|---|---|")
FEATS = [
 ("Tiling window manager, per-workspace floating", "`hyprland`, `SUPER+L` toggle", "keep"),
 ("Status bar: workspaces, clock/date, wifi, volume", "`waybar` (replaces `quickshell`)", "new package"),
 ("App launcher", "`fuzzel` on `SUPER+SPACE` (replaces the Omarchy menu)", "new package"),
 ("Notifications", "none — no daemon, by decision", "dropped"),
 ("Volume/brightness OSD", "none — volume on the bar, keys silent", "dropped"),
 ("Lock screen + idle", "`hyprlock`, `hypridle` (lock at 150s)", "keep"),
 ("Wallpaper", "`hyprpaper`, static (replaces `owe`)", "new package"),
 ("Screenshot → annotate → clipboard", "`grim` + `slurp` + `satty` + `wl-clipboard`", "keep + `satty` new"),
 ("Screen recording", "`gpu-screen-recorder` (already installed)", "keep"),
 ("Screen sharing / window picker", "`xdg-desktop-portal-hyprland`, `hyprland-preview-share-picker`", "keep"),
 ("Clipboard (no history)", "`wl-clipboard` + `wl-clip-persist`", "keep"),
 ("Theming", "static dark defaults; `wallust` deferred", "deferred"),
 ("Japanese/Chinese input", "`fcitx5` + mozc / chinese-addons / hangul / chewing", "keep"),
 ("Webcam in browser/vesktop", "camera portal via `xdg-desktop-portal(-hyprland)`", "verify, no new package"),
 ("Audio", "`pipewire` + `wireplumber` + `pamixer`", "keep"),
 ("Drives and removable media", "`udiskie`, `gvfs-*`, `gnome-disk-utility`", "keep"),
 ("Filesystem tools", "`btrfs-progs`, `dosfstools`; `ntfs-3g`/`exfatprogs` go with the NTFS disks", "`ntfs-3g` + `exfatprogs` drop"),
 ("Night light", "`hyprsunset`", "dropped"),
 ("Bluetooth", "`bluez` stack", "dropped (no paired devices)"),
 ("Emoji picker / clipboard history", "—", "dropped"),
 ("Dock / minimise-to-dock", "—", "dropped"),
 ("Keybind cheatsheet", "—", "dropped"),
 ("Power menu", "short `fuzzel` script on `SUPER+ESCAPE`", "keep (to write)"),
]
for f, p, v in FEATS: A(f"| {f} | {p} | {v} |")

A("\n## Applications you launch by hand\n")
A("| Bind | Application | Package | Verdict |")
A("|---|---|---|---|")
APPS = [
 ("`SUPER+RETURN`", "ghostty", "`ghostty`"), ("`SUPER+B`", "chromium", "`chromium`"),
 ("`SUPER+SHIFT+B`", "chromium Profile 4", "`chromium`"), ("`SUPER+ALT+RETURN`", "tmux", "`tmux`"),
 ("`SUPER+CTRL+RETURN`", "herdr", "`herdr` (rebuild)"), ("`SUPER+F`", "nautilus", "`nautilus`"),
 ("`SUPER+N`", "neovim", "`neovim`"), ("`SUPER+A`", "btop", "`btop`"),
 ("`SUPER+D`", "vesktop", "`vesktop`"), ("`SUPER+S`", "steam", "`steam`"),
 ("`SUPER+SPACE`", "fuzzel", "`fuzzel` (new)"), ("`PRINT`", "satty + grim + slurp", "`satty` (new), `grim`, `slurp`"),
 ("`ALT+PRINT`", "gpu-screen-recorder", "`gpu-screen-recorder`"),
]
for b, a, p in APPS: A(f"| {b} | {a} | {p} | keep |")
A("\nAlso installed and used without a bind: `firefox`, `vesktop`, `signal-desktop`,")
A("`mpv`, `libreoffice-fresh`, `obsidian`, `xournalpp`, `kdenlive`, `docker`, `git`,")
A("`visual-studio-code-bin`, the dev toolchains (see the tables below).\n")

A("## Packages by area\n")
for name, _ in SECTIONS:
    rows = rows_by_sec.get(name)
    if not rows: continue
    A(f"### {name}\n")
    A("| Package | What it is | Size | Verdict |")
    A("|---|---|---|---|")
    for p, mb, desc, v in sorted(rows, key=lambda r: r[0]):
        A(f"| `{p}` | {desc} | {size(mb)} | {v} |")
    A("")
if other:
    A("### Unclassified\n")
    A("| Package | What it is | Size | Verdict |")
    A("|---|---|---|---|")
    for p, mb, desc, v in sorted(other):
        A(f"| `{p}` | {desc} | {size(mb)} | {v} |")
    A("")

A("## The 53 packages that ran nothing in 30 days\n")
A("Evidence for the pruning: these had no binary read in a month. Verdicts come from")
A("`todo/needs.md` batch 2 — 30 drop, 17 kept as plumbing, and the five that were")
A("judged by hand.\n")
A("| Package | Size | Verdict | Note |")
A("|---|---|---|---|")
NOTES = {
 'efibootmgr':'boot entries', 'man-db':'man pages', 'unzip':'archives',
 'inetutils':'telnet/ftp-era tools', 'socat':'socket plumbing', 'whois':'whois lookups',
 'tldr':'short man pages', 'qrencode':'QR codes', 'wl-clip-persist':'clipboard survives app exit',
 'brightnessctl':'internal panel brightness (unused, no internal panel)',
 'alsa-utils':'amixer', 'pamixer':'volume CLI', 'fcitx5-gtk':'IME for GTK apps',
 'xdg-desktop-portal-hyprland':'screen share + camera portal', 'gnome-disk-utility':'disk GUI',
 'yt-dlp':'video downloads', 'tesseract':'OCR (no bind yet)',
 'obs-studio':'dropped: gpu-screen-recorder covers clips', 'tigervnc':'dropped with SUPER+R / VNC to Tom',
 'ffmpegthumbnailer':'nautilus video thumbnails', 'tree-sitter-cli':'nvim parser builds',
 'exfatprogs':'dropped, formatting only', 'inxi':'dropped, hardware report',
}
for p in sorted(unused):
    if p not in data: continue
    mb, desc = data[p]
    v = verdict(p)
    A(f"| `{p}` | {size(mb)} | {v} | {NOTES.get(p,'')} |")
A("")
A("## Notes\n")
A("- **Foreign packages (8)**: `d2-bin`, `leiningen-with-completion`, `libstrangle`,")
A("  `or-tools`, `python310`, `python39`, `v8-r`, `vesktop` — not from Arch repos. All")
A("  but `python310` and `vesktop` are drops.")
A("- **From the `[omarchy]` repo (42)**: everything named `omarchy-*` plus")
A("  `quickshell owe owe-lockfeed hype omacut omasnap omawrite omacalc monologue aether")
A("  herdr gliff cliamp disktree-bin tobi-try ttfx vortix signed spotify typora bun-bin")
A("  mise-bin localsend visual-studio-code-bin yay ufw-docker tzupdate yaru-icon-theme")
A("  ttf-ia-writer ttf-jetbrains-mono-nerd-basic asdcontrol linux-omarchy*`. Removing the")
A("  repo and the package takes the lot; `herdr`, `bun-bin`, `mise-bin`,")
A("  `visual-studio-code-bin`, `yay`, `uv?` need AUR/`extra` replacements first.")
A("- **Sizes** are `pacman`'s installed size; the dependency closure that `pacman -Rns`")
A("  removes is much larger (the Omarchy package alone pulls 411 packages).")

out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'docs/jason/packages.md')
open(out,'w').write("\n".join(lines) + "\n")
print("wrote", len(lines), "lines;", len(data), "packages;", len(other), "unclassified")
print("unclassified:", " ".join(p for p,_,_,_ in sorted(other)))
