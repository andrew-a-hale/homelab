# Jason

The desktop. Ryzen 5 7600X, 30G RAM, RTX 3070, MSI PRO B650-P WIFI, two LG
UltraGear panels. **Plain Arch**, Wayland, Hyprland, configured from
[`config/`](../../config/README.md) — Omarchy was removed 2026-11-11
([record](complete/left-omarchy-2026-11-11.md)). Where the petcam detector is
fine-tuned and the `amp --no-tui` runner lives.

Purpose of this file: **what this machine actually is and actually uses**, so a
rebuild (or a second machine like Rose) starts from evidence instead of guesses.

## Shape

| Layer | What |
|---|---|
| Base OS | Arch, 1184 packages / 177 explicit |
| Kernel | stock `linux` 7.2.11-arch1-1 |
| Session | sddm → `uwsm` → Hyprland 0.56.2 (Wayland) |
| WM config | Lua in `~/.config/hypr/`, from [`config/hypr/`](../../config/hypr): `hyprland.lua` requires `monitors`, `input`, `looknfeel`, `rules`, `binds`, `autostart`; systemd user units for the GUI daemons |
| Shell | waybar (workspaces colour-coded by state, clock + date, wifi, volume) + fuzzel launcher + hyprpaper wallpaper. No notification daemon, no OSD, no tray — deliberate |
| GPU | RTX 3070 (`nvidia-open-dkms` 615.78.08) + Raphael iGPU `Radeon 610M`; NVIDIA is the render device |
| Displays | `DP-2` 1920x1080@144 landscape at 0x0; `DP-1` 1920x1080@144 **portrait** (`transform=3`) at 1920x-190 |
| Disk | `nvme1n1` 930G: LUKS2 → btrfs `@ /`, `@home`, `@log`, `@pkg`; `/boot` 1G vfat (53% — one snapshot entry). 430G used, 332G of it Steam (`common` 263G, `compatdata` 69G) |
| Other disks | `nvme0n1p2` 229G ext4 `games` → `/mnt/games` (empty); `sda1` 1.8T ext4 `storage` → `/mnt/storage` (Proton Drive backup staging); `zram0` 30G swap |
| Boot | menu title `Arch`, Limine 12.9.4 + snapper 0.13.2 + `limine-mkinitcpio-hook` / `limine-snapper-sync` (AUR), `sbctl` secure boot; `/etc/limine-entry-tool.d/zz-jason.conf` carries the UKI settings. One snapshot entry kept: each copies the 267M UKI, so the cap is 1 and `LIMIT_USAGE_PERCENT=70` lives in `/etc/default/limine` |
| Access | tailnet `jason` = `100.95.54.82`; SSH identity from the tailnet. `ssh tom` and `ssh ralph` both work from here |

## What is installed

[`whitelist.md`](whitelist.md) is the list: apps, CLI tools, dev toolchains,
desktop shell, gaming. If it is not there it is not installed. The live truth is
`pacman -Qe` (177 explicit); the atime audit
(`scripts/pacman-atime-audit.sh 30`) reports **nothing unused in 30 days**, so
there are no drops pending.

## Decisions and backups

- [`whitelist.md`](whitelist.md) — the user-land keep list. Rebuild from this.
- [`services.md`](services.md) — units and timers: what starts at boot, what runs
  on a schedule, what reads `/mnt/storage`. Scripts live in
  [`services/jason/`](../../services/jason/), installed units run them from there.
- [`binds.md`](binds.md) — the keymap, hand-edited: 40 rows (workspaces 1–6 included).
- [`config/README.md`](../../config/README.md) — what each file in `config/`
  replaces from Omarchy, and how to deploy it.
- [`complete/needs-2026-11-11.md`](complete/needs-2026-11-11.md) — the app-by-app
  walkthrough the whitelist rests on.
- [`complete/what-jason-needs-2026-11-11.md`](complete/what-jason-needs-2026-11-11.md)
  — every verdict and what was deferred on purpose.
- [`complete/waybar-workspace-modes-2026-11-12.md`](complete/waybar-workspace-modes-2026-11-12.md)
  — why workspace state is colour, the 6-workspace cap, and why waybar must stay
  ≥ 0.16.0 (Hyprland's Lua dispatch).
- [`complete/simplify-jason-docs-2026-11-12.md`](complete/simplify-jason-docs-2026-11-12.md)
  — the 2026-11-12 tidy: generated inventory and stale config copies deleted.

Settled in the walkthrough: **herdr** is the only Omarchy app kept; **no web apps**;
**waybar** + **fuzzel** + **hyprpaper** + **hyprlock/hypridle** (lock at 150s,
no screensaver process); **satty + gpu-screen-recorder** for capture; static dark
theme; no notification daemon, OSD, dock, clipboard history, night light,
Bluetooth, emoji picker or dictation.

## Gaps still open

- [ ] **Steam, 332G**: uninstall what is unplayed, or add `/mnt/storage` as a
      second library. The 229G `/mnt/games` is empty and unused.
- [ ] **Rose** — the next machine is the same shape without the four system
      units Jason carries: a dev laptop on the tailnet that plays Steam games.
      `config/` is the reusable half; see the note in [`TODO.md`](../../TODO.md).
