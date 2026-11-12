# Jason — install list

What a rebuild installs, and what it is for. **System layer is out of scope**
(kernel, bootloader, filesystems, firmware, libraries are the distro's problem);
this is everything installed on top of `base` that a person chose.

Rule: if it is not on this page it is not installed. The live check is
`pacman -Qe` (**177 explicit**, 1184 total); `pacman -Qm` lists the eight AUR
packages. If a package here stops being used, delete the line.

## Repo packages

```sh
# boot, disks, base tools
sudo pacman -S --needed amd-ucode linux linux-firmware linux-headers \
  btrfs-progs dosfstools efibootmgr limine limine-mkinitcpio-hook snapper \
  sbctl pesign plymouth kernel-modules-hook zram-generator systemd-resolvconf \
  pacman-contrib expac fakeroot man-db less perl unzip ex-vi-compat libyaml

# network, VPN, firewall, remote access
sudo pacman -S --needed networkmanager avahi nss-mdns wireless-regdb ufw \
  tailscale proton-vpn-cli bind inetutils whois socat nmap

# session, compositor, bar, capture
sudo pacman -S --needed sddm uwsm hyprland hyprland-guiutils hyprlock hypridle \
  hyprpaper waybar fuzzel hyprpicker xdg-desktop-portal-gtk \
  xdg-desktop-portal-hyprland xdg-terminal-exec wl-clipboard grim slurp satty \
  gpu-screen-recorder

# audio, input, fonts, themes
sudo pacman -S --needed pipewire pipewire-alsa pipewire-pulse pipewire-jack \
  gst-plugin-pipewire wireplumber pamixer alsa-utils libpulse \
  fcitx5 fcitx5-chinese-addons fcitx5-gtk fcitx5-qt \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
  ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-cascadia-mono-nerd \
  woff2-font-awesome fontconfig gnome-themes-extra

# drives and files
sudo pacman -S --needed udiskie gvfs-mtp gvfs-smb gnome-disk-utility \
  gnome-keyring libsecret nautilus nautilus-python sushi ffmpegthumbnailer \
  ddcutil brightnessctl

# apps opened by hand (binds: docs/jason/binds.md)
sudo pacman -S --needed ghostty chromium firefox evince mpv mpv-mpris \
  imagemagick libvips libreoffice-fresh steam vesktop tesseract \
  tesseract-data-eng libqalculate python-gobject python-numpy

# shell and command line
sudo pacman -S --needed bash-completion bat btop eza fd fastfetch fzf jq \
  lazygit ripgrep starship tldr tmux tree-sitter-cli vhs wtype xmlstarlet \
  zbar qrencode yt-dlp streamlink gum entr inotify-tools plocate zoxide \
  github-cli git pass

# languages and toolchains
sudo pacman -S --needed clang llvm rustup go zig elixir erlang gleam odin r \
  julia dotnet-sdk gcc-fortran ruby uv npm docker docker-compose docker-buildx \
  qemu-base qemu-user-static-binfmt postgresql-libs mariadb-libs

# gaming (RTX 3070 + the Raphael iGPU)
sudo pacman -S --needed nvidia-open-dkms lib32-nvidia-utils \
  libva-nvidia-driver libva-utils vulkan-radeon
```

## AUR packages

Eight, all AUR-owned, none from `[omarchy]` (that repo is gone):

| Package | Why |
|---|---|
| `yay` | AUR helper — bootstrap with `git clone` + `makepkg -si` |
| `herdr` | agent workspace manager, `SUPER+CTRL+RETURN`. The one Omarchy app kept; no repo package exists |
| `vesktop` | Discord, `SUPER+D` |
| `hyprland-preview-share-picker` | window previews when screen sharing |
| `limine-mkinitcpio-hook`, `limine-snapper-sync` | write `/boot/limine.conf` and snapshot entries; install these **before** any `pacman -Rns` that could orphan them |
| `ttf-ia-writer` | iA Writer fonts |
| `ufw-docker` | keeps Docker and ufw from fighting |

## Installed by something else, deliberately absent

- `nodejs` arrives as a dependency of `npm`; the agent CLIs (`amp`, `opencode`,
  `pi`) are `npm -g` / self-installing, not packages. `uv` is the Python side.
- **Not installed, by decision**: notification daemon, OSD, tray, dock,
  clipboard history, night light (`hyprsunset`), Bluetooth (`bluez*`), printing
  (`cups*`), screenshots tools other than grim/slurp/satty, VNC, app launchers
  other than fuzzel, web apps (`.desktop` wrappers — everything is a browser tab),
  themes other than the static dark default. See
  [`complete/what-jason-needs-2026-11-11.md`](complete/what-jason-needs-2026-11-11.md).

## Notes that cost time once

- **waybar ≥ 0.16.0** — the first release that speaks Hyprland's Lua dispatch;
  older ones send the legacy `dispatch workspace N` and clicks do nothing
  ([why](complete/waybar-workspace-modes-2026-11-12.md)).
- **`nvidia-open-dkms`** builds on kernel upgrades; `linux-headers` must be
  installed or DKMS fails and the next boot has no driver.
- Prompt and history settings are ours (`config/shell/bashrc`,
  `config/shell/starship.toml`), not Omarchy's rc.
