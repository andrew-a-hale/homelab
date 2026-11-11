# Leaving Omarchy for plain Arch (Jason)

Status: investigation, 2026-11-09. Nothing changed yet.

Goal: keep Arch + Hyprland + the apps actually used, drop Omarchy's opinionated layer.

## What Omarchy is on this box today

Omarchy 4.5.0 (`local/omarchy`), 1475 packages total, 265 explicit.

- 562 `omarchy-*` binaries in `/usr/bin`.
- Desktop shell = `quickshell` (Omarchy repo) running ~60 QML files from
  `/usr/share/omarchy/shell/`: top bar, launcher, app menu, OSD, notifications,
  screensaver. Driven by `~/.config/omarchy/shell.toml` (only `font.base-size = 12` customised).
- Hyprland config = **Lua**, not hyprlang: `~/.config/hypr/hyprland.lua` dofiles
  `/usr/share/omarchy/default/hypr/bootstrap.lua` (63 files, 2625 lines) to get the
  `o.*` helper API and default bindings; personal overrides are 5 small files
  (`bindings.lua` 47 lines, `looknfeel.lua` 55, `hyprland.lua` 33, `monitors.lua` 17,
  `input.lua` 14). The `*.conf` files next to them are stale pre-Quattro leftovers.
- 14 web apps in `~/.local/share/applications/` whose `Exec=` is `omarchy-launch-webapp <url>`.
- **42 installed packages come from the `[omarchy]` repo** (not Arch):
  `omarchy omarchy-{keyring,settings,hyprland-titlebars,nvim,power-profiles-daemon,speedtest,themes-intros}`
  `linux-omarchy linux-omarchy-headers limine-mkinitcpio-hook limine-snapper-sync`
  `quickshell owe owe-lockfeed hype omacut omasnap omawrite omacalc monologue aether
  herdr gliff cliamp disktree-bin tobi-try ttfx vortix signed spotify typora
  bun-bin mise-bin localsend visual-studio-code-bin yay ufw-docker tzupdate
  yaru-icon-theme ttf-ia-writer ttf-jetbrains-mono-nerd-basic asdcontrol aether`

Already plain Arch (survive untouched): `hyprland 0.56.2` (extra), `uwsm`, `sddm`,
`limine`, `snapper`, `pipewire`, `xdg-desktop-portal-hyprland`, `hyprlock`,
`hypridle`, `hyprsunset`.

## What it installs that you don't use

Measured with `scripts/pacman-atime-audit.sh 10` (atime = "was this binary ever
run"; relatime updates it on first execution):

**95 of the 265 explicit packages have not had a single binary run in 10+ days
— 2.3 GiB.** Biggest: `wine-staging` 598M, `spotify` 386M, `typora` 353M,
`boost` 151M, `terraform` 114M, `rclone` 110M, `localsend` 67M,
`jellyfin-server` 65M (that runs on Ralph, not here), `v8-r` 56M,
`omarchy-nvim` 56M, `python39` 53M, `python-numpy` 50M, `gcc-fortran` 49M,
`d2-bin` 40M, `z3` 38M, `or-tools` 36M, `jupyterlab` 36M, then a long tail of
screenshot tools (flameshot, ksnip, hyprshot), terminal emulators
(alacritty, foot), VNC, printing, `sl`, `tobi-try`, `asdcontrol`.
The 411-package dependency closure of `omarchy` includes **76 packages nothing
else you use needs** — libraries and helpers that vanish with `pacman -Rns`.

**562 `omarchy-*` commands; shell history shows ~15 distinct ones used.** The
rest is per-user-profile scaffolding: 42 `hw-*` profiles (Apple silicon, Intel
laptop, ROG, Surface, ARM boards…), 46 `install-*` / 35 `remove-*` helpers for
AI vendors, editors, gaming launchers, dictation, 37 `agent-*` AI-usage meters,
40 `theme-*`, 9 `capture-*`. Plus 171M of themes and intro videos, 936K of
migrations, `plymouth`, and `omarchy-nvim`'s prebuilt LazyVim tree.

**Defaults and daemons running that you never asked for:**

- user units enabled: `omarchy-crash-watch`, `omarchy-migrate-notify`,
  `omarchy-recover-internal-monitor`, `omarchy-sleep-lock`, `omarchy-fcitx5`,
  and `owed` (video-wallpaper daemon).
- 4 alpm hooks: update guard, passwordless revoke, Hyprland reload pause/resume.
- `/etc/profile.d/omarchy.sh` sources an env bootstrap; `/etc/skel` ships the
  full dotfile set; `/etc/pacman.d/mirrorlist` is Omarchy's, not Arch's.
- 21 per-app Hyprland rules (1password, bitwarden, telegram, inkscape, retroarch,
  davinci-resolve, moonlight, geforce-now, battlenet, localsend, jetbrains, pip,
  hermes) — only steam, browser, terminals and `omarchy-shell` apply on this box.
- plymouth theme, sddm theme, limine templates, voxtype/v4l2-relayd/tensaku
  (dictation, webcam relay) defaults.
- the running kernel is `linux-omarchy` (BORE + ADIOS), not stock `linux`.

Boot: single 930G LUKS+btrfs (`@`, `@home`, `@log`, `@pkg`), `/boot` vfat with
Limine, snapper on `/`, snapshot boot entries intended via `limine-snapper-sync`
(but suppressed today: `/boot` sits at 54% with two 272M UKIs against
`LIMIT_USAGE_PERCENT=50`, so dropping `linux-omarchy` is what turns them on). No spare disk —
a fresh reinstall would need 472G of backup.

## What you lose, and the replacement

| Omarchy | Plain Arch replacement | Effort |
|---|---|---|
| quickshell bar/launcher/menu/OSD/notifications | `waybar` + `fuzzel` + `mako` + `swayosd` | medium — new config, not a translation |
| `omarchy-launch-screensaver` (lock) | `hyprlock` (already installed, `hyprlock.conf` already 43 lines) | easy |
| `omarchy-launch-webapp` | nothing — no web apps, everything is a browser tab | free |
| `o.bind`/`hl.*` Lua default bindings | Hyprland's own Lua config: `hl.*` + `hl.dsp.*` only (ships `/usr/share/hypr/hyprland.lua`, stubs `stubs/hl.meta.lua`, 0.56.2) | easy — keep Lua, drop `o.*` and the `dofile(OMARCHY_PATH .. "/default/hypr/bootstrap.lua")` |
| theme system (`omarchy-theme-*`, aether, owe) | wallust/pywal + `~/.config/gtk-*`, or nothing | optional |
| `linux-omarchy` kernel | `linux` (already installed, currently unused) | easy, reboot |
| `omarchy-agent*` (30+ binaries) | nothing — unused | free |
| omarchy-owned apps: `hype omacut omasnap omawrite omacalc cliamp herdr gliff aether owe` | AUR where it exists, else drop | decide per app |
| omarchy repo packages in daily use: `visual-studio-code-bin yay bun-bin ufw-docker tzupdate ttf-ia-writer yaru-icon-theme` | AUR (all seven verified to exist); `mise-bin` dropped — agent CLIs via `npm -g`; JetBrains Mono Nerd = `extra/ttf-jetbrains-mono` + `extra/ttf-nerd-fonts-symbols` | easy — [`whitelist.md`](../whitelist.md) has the table |
| `omarchy-update`, migrations, crash watch | `yay -Syu`, nothing | free |
| keybind cheatsheet (`SUPER + /`) | write a static list, or `hyprland-per-window-layout`-style trick | easy |

## Options

**A. In-place strip (recommended).** Uninstall the Omarchy layer on the existing
install, keep btrfs/limine/snapper/sddm/LUKS. Staged, each step revertible by
snapper. Risk: a half-converted config mid-way (fix: build the waybar/fuzzel/mako
config first, switch in one reboot).

**B. Fresh Arch install.** Cleanest end state, but 472G to back up with no spare
disk, and every dotfile re-created by hand anyway. Takes a weekend, not an evening.

## Staged plan (option A)

0. **Prune first, migrate later.** This is independent of leaving Omarchy:
   review `scripts/pacman-atime-audit.sh 10` and `pacman -Rns` what you won't
   miss. Same for the `omarchy-*` units you never use.
1. **Snapshot** `snapper create -d pre-deomarchy`, and `git init` a dotfiles repo
   (or just copy `~/.config/{hypr,omarchy,waybar,…}` to a tarball on `/mnt/storage`).
2. **Build the plain desktop in parallel** — **written, in `config/`**. waybar,
   fuzzel and hyprpaper configs, `hyprlock`/`hypridle`, and the three helper
   scripts. There is no notification daemon and no OSD to configure: both were
   dropped (`needs.md` batch 5). No web apps to rewrite: browser tabs only.
3. **Rebase hypr config** on Hyprland's own Lua sample (`/usr/share/hypr/hyprland.lua`)
   — **written, in `config/hypr/`**: monitors (DP-2 + DP-1 portrait, workspace
   pinning), input (fcitx5 + the environment.d variables the Omarchy upgrade had
   already renamed to `.bak`), looknfeel, the 37 binds from `binds.md`, the
   idle-inhibit rules, and the `SUPER+L` workspace float (§2.1 of the spec), with
   `hl.*`/`hl.dsp.*` instead of `o.*`. Verified against the live Hyprland 0.56.2
   Lua API with `hyprctl eval "dofile(...)"` — all 40 binds register, no errors.
   What is left here is copying it into `~/.config` on the day.
4. **Swap** at one reboot: disable quickshell/mako-less state, enable waybar.
5. **Move packages off the omarchy repo**: every survivor's source is tabulated in
   [`../whitelist.md`](../whitelist.md) — `bun-bin`, `visual-studio-code-bin`,
   `yay`, `ufw-docker`, `tzupdate`, `ttf-ia-writer`, `yaru-icon-theme` from the AUR;
   fonts from `extra`; `mise-bin` gone, agent CLIs installed with `npm -g`.
6. **Remove `[omarchy]` from `/etc/pacman.conf`**, then
   `pacman -Rdd omarchy omarchy-* quickshell owe owe-lockfeed linux-omarchy*`,
   remove `omarchy-*` user units, switch boot to `linux`, rebuild initramfs.
7. **Docs**: replace this file with `docs/jason/complete/leave-omarchy-<date>.md`,
   keep a one-page "how this desktop is configured" README.

## Open questions

Moved to `arch-desktop-spec.md` §7 (bar, launcher, notifications, theming).
That spec is the contract: the new desktop installs what it lists and nothing else.
