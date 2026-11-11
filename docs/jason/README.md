# Jason

The desktop. Ryzen 5 7600X, 30G RAM, RTX 3070, MSI PRO B650-P WIFI, two LG
UltraGear panels. **Plain Arch**, Wayland, Hyprland, configured from
[`config/`](../../config/README.md) — Omarchy was removed 2026-11-11
([record](complete/left-omarchy-2026-11-11.md)). Where the petcam detector is
fine-tuned and the `amp --no-tui` runner lives.

Purpose of this file: **what this machine actually is and actually uses**, so a
rebuild starts from evidence instead of guesses. Gaps to fill are at the bottom.

## Shape

| Layer | What | Why |
|---|---|---|
| Base OS | Arch, 1215 packages / 197 explicit | Omarchy layer gone 2026-11-11 — [record](complete/left-omarchy-2026-11-11.md); [sweep](complete/post-cutover-sweep-2026-11-11.md) |
| Kernel | stock `linux` 7.2.11-arch1-1 | `linux-omarchy` removed 2026-11-11 once this booted — [sweep](complete/post-cutover-sweep-2026-11-11.md) |
| Session | sddm → `uwsm` → Hyprland 0.56.2 (Wayland) | |
| WM config | Lua in `~/.config/hypr/`, ours: `hyprland.lua` requires `monitors`, `input`, `looknfeel`, `rules`, `binds`, `autostart` | source of truth is [`../../config/hypr/`](../../config/README.md); the old Omarchy tree is kept at `~/.config/hypr.omarchy-2026-11-11` |
| Shell | waybar (workspaces, clock + date, wifi, volume) + fuzzel launcher + hyprpaper | [`../../config/`](../../config/README.md). No notification daemon, no OSD, no tray — deliberate |
| GPU | RTX 3070 (`nvidia-open-dkms` 615.78.08) + Raphael iGPU `Radeon 610M` | NVIDIA is the render device |
| Displays | `DP-2` 1920x1080@144 landscape at 0x0; `DP-1` 1920x1080@144 **portrait** (`transform=3`) at 1920x-190 | |
| Disk | `nvme1n1` 930G: LUKS2 → btrfs `@ /`, `@home`, `@log`, `@pkg`; `/boot` 1G vfat | |
| Other disks | `nvme1n1p2` 229G ext4 `games` → `/mnt/games`; `sda1` 1.8T ext4 `storage` → `/mnt/storage`; `zram0` 30G swap | both wiped from NTFS on 2026-11-11 |
| Boot | Limine 12.9.4 + snapper 0.13.2 + limine-snapper-sync (both limine tools AUR-owned, not `[omarchy]`), `sbctl` secure boot; `/etc/limine-entry-tool.d/zz-jason.conf` carries the UKI settings `omarchy-settings` used to own | entries auto-generated. One kernel, one **snapshot entry** (the menu shows `Snapshots → 16`): `/boot` is 53% of 1G because each snapshot entry copies the 267M UKI, so the cap is 1 and `LIMIT_USAGE_PERCENT=70` lives in `/etc/default/limine`, **not** the `d/` directory |
| Access | tailnet `jason` = `100.95.54.82`; SSH identity from the tailnet | |

## What is actually used

Method: `scripts/pacman-atime-audit.sh 30` (atime = "was a binary ever run").
**53 of the 265 explicit packages have run nothing in 30 days — 0.7 GiB.**
Unused: `aether alacritty alsa-utils asdcontrol bluez-tools bluez-utils boost
brightnessctl caligula clojure efibootmgr exfatprogs fcitx5-gtk ffmpegthumbnailer
flameshot geckodriver glow gnome-disk-utility hyprshot imv inetutils inxi ksnip
lazydocker leiningen-with-completion libcamera libstrangle lua51 luarocks man-db
obs-studio or-tools pamixer pinta python39 qrencode qt5-wayland sl socat
system-config-printer terraform tesseract tigervnc tldr tree-sitter-cli unzip
v8-r whois wl-clip-persist wtype xdg-desktop-portal-hyprland yt-dlp z3` — plus
the whole 411-package dependency closure that goes with them.

Used, by group (full list in the spec, §4): ghostty + tmux, chromium (default,
Profile 4) + firefox, neovim + VS Code, nautilus, mpv, libreoffice,
signal + vesktop + discord web, steam (Proton), docker, bun, go, rust, zig,
julia, elixir, r, ruby, clang/llvm, python310, uv, postgresql-libs, plus the
CLI set (btop, eza, fd, ripgrep, zoxide, starship, fzf, jq, gum, lazygit, herdr…).

Omarchy-built apps: **`herdr` only** — it has no Arch package (rebuild from
`github.com/herdrdev/herdr`). `hype omawrite omasnap gliff cliamp monologue
disktree-bin ttfx owe owe-lockfeed aether` are all dropped — [`needs.md` batch 1](todo/needs.md).

Web apps: **none** — 12 `.desktop` files exist today, all dropped: five had never
been opened (Google Contacts/Messages/Photos, WhatsApp, Figma), Basecamp and HEY
were last seen in February. Everything is a browser tab now, and the `SUPER+Y`,
`SUPER+M`, `SUPER+SHIFT+S`, `SUPER+D` bind-triggers go with them.

The keymap being built for the Omarchy-free config is [binds.md](binds.md) —
hand-edited, and the only keybind source once Omarchy is gone.

Custom keybinds today (all 21 are in [spec §3](todo/arch-desktop-spec.md)):
the ones that matter daily are `SUPER+RETURN` ghostty, `SUPER+R` VNC to Tom,
`SUPER+B` chromium, `SUPER+S` steam, `SUPER+F` nautilus, `SUPER+M`/`SUPER+Y`
webapps. One new one is agreed for the new desktop: `SUPER+L` toggles the
current workspace tiling ↔ floating ([spec §2.1](todo/arch-desktop-spec.md)).

Omarchy units enabled that nothing here asks for: `omarchy-crash-watch`,
`omarchy-migrate-notify`, `omarchy-recover-internal-monitor`,
`omarchy-sleep-lock`, `omarchy-fcitx5`, `owed` (video wallpaper daemon).

## Decisions and backups

- [`whitelist.md`](whitelist.md) — **the user-land list**: apps, CLI tools, dev
  toolchains, desktop shell, gaming. If it is not there it is not installed.
- [`services.md`](services.md) — units, timers and scheduling: what starts at boot,
  what runs on a timer, and what reads `/mnt/storage`. Scripts live in
  [`services/jason/`](../../services/jason/).
- [`packages.md`](packages.md) — every explicit package (265) with verdicts, sizes
  and descriptions, plus the features table. The reference, including the system layer.
- [`binds.md`](binds.md) — the new keymap, hand-edited: 37 binds + workspace ranges.
- [`files/hypr/`](files/hypr/) — a copy of the live `~/.config/hypr` Lua config,
  `hypridle`, `hyprlock`, `xdph`. **No credentials** live in the repo; none of these
  files contain any (checked).
- [`todo/needs.md`](todo/needs.md) — the walkthrough: what is
  needed, app by app, feature by feature, with the evidence each verdict rests on.
- [`complete/what-jason-needs-2026-11-11.md`](complete/what-jason-needs-2026-11-11.md)
  — the completed decision record: every verdict, and what was deferred on purpose.

Settled in that walkthrough: **herdr** is the only Omarchy app kept; **no web apps**;
**waybar** (workspace indicator, clock/date, wifi, volume) + **fuzzel**; **no
notification daemon, no OSD, no dock, no clipboard history, no night light, no
Bluetooth, no emoji picker, no dictation**; **hyprpaper** static wallpaper;
**satty + gpu-screen-recorder** for capture; idle → `hyprlock` at 150s; static dark
default theme, wallpaper-derived theming deferred. Dropped: 30 of the 53
never-run packages, all screenshot tools, `tigervnc` (and `SUPER+R`), `obs-studio`.

## Gaps still open

- [x] **Two freed disks**: `sda1` 1.8T and `nvme1n1p2` 229G are ext4 and empty
      (except `/mnt/storage/backup`, the Proton Drive staging tree). Done
      2026-11-11. What they are *for* is still deferred.
- [ ] **amp runner** — `--no-tui` reaching Tom and Ralph over the tailnet:
      [docs/amp](../amp/README.md) says how it is wired; not re-verified from here.
- [ ] **The migration itself** — `/mnt/games` mount goes away and WoW moves to
      `~/Games` on btrfs as part of it, not before.
