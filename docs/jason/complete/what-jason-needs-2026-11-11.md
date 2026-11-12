# What Jason needs — decided 2026-11-11

Task: work out, by hand and from evidence, which applications and features the
desktop actually needs before Omarchy is removed — and record that as the install
contract, without changing anything on the machine.

The rule followed throughout: **a decision is only real if it points at evidence on
the box** (package atime, browser history, notification history, disk contents,
service state). Everything else was treated as a guess and left open.

## Where it is written down

| File | What it is |
|---|---|
| [`../binds.md`](../binds.md) | the keymap, hand-edited: 37 binds + workspace ranges |
| [`config/hypr/`](../../../config/hypr/) | the live `~/.config/hypr` config (this record used to keep a copy under `docs/jason/files/`; deleted 2026-11-12) |
| [`../README.md`](../README.md) | the machine: hardware, disks, what runs, evidence-backed inventory |
| [`../whitelist.md`](../whitelist.md) | the install list that came out of this |
| [`needs-2026-11-11.md`](needs-2026-11-11.md) | the seven batches, each verdict with its evidence |
| [`../complete/arch-desktop-spec-2026-11-11.md`](../complete/arch-desktop-spec-2026-11-11.md) | the install contract — what the new desktop installs, nothing else |

## Decisions

**Apps.** `herdr` is the only Omarchy-built app kept (rebuild from
`github.com/herdrdev/herdr`; not in the AUR). Dropped: `hype`, `omawrite`, `omasnap`,
`gliff`, `cliamp`, `monologue`, `disktree-bin`, `ttfx`, plus the previously
unused `aether`, `owe`, `omacut`, `omacalc`, `localsend`, `tobi-try`, `vortix`.
**No web apps at all** — browser tabs only, so 12 `.desktop` files and 5 binds go.

**Desktop.** `waybar` (workspace indicator, clock + date, wifi, volume) and `fuzzel`
replace the quickshell bar/menu. No notification daemon, no OSD, no dock, no
clipboard history (plain `wl-clipboard`), no night light, no Bluetooth, no emoji
picker, no dictation. `hyprpaper` for a static wallpaper. Capture is `satty` +
`gpu-screen-recorder` behind `PRINT`-family binds. Idle → `hyprlock` at 150s.
Default look is static dark; wallpaper-derived theming deferred until the defaults
annoy.

**Packages.** Of the 53 explicit packages whose binaries had not run in 30 days:
30 dropped outright (never-touched language stacks, screenshot tools, Apple
leftovers, printer/exfat/inxi), 17 kept as plumbing (`efibootmgr`, `man-db`,
`xdg-desktop-portal-hyprland`, `wl-clip-persist`, `fcitx5-gtk`, `yt-dlp`,
`tesseract`, …), and 5 adjudicated by hand — `obs-studio`, `tigervnc`,
`exfatprogs`, `inxi` drop; `ffmpegthumbnailer`, `tree-sitter-cli` keep.

**Keys.** 37 binds, from ~130 Omarchy defaults. `SUPER+L` toggles the current
workspace tiling ↔ floating. Cut even from the first draft: monitor focus,
multi-monitor workspace moves, group toggle, tab cycling, `SUPER+I` IME switch, and
the XF86 volume/media keys — all recorded with their knock-ons in `binds.md`.

**Storage.** Both spare disks are Windows leftovers: `sda` (2TB WD20EARX, 2011) is
NTFS `/mnt/storage` with 681M of family backups (already in Proton Drive),
`nvme0n1` (233G) is NTFS `/mnt/games` with WoW and a 16M Microsoft-reserved
partition. Both get wiped to `ext4` during the migration and mounted empty. WoW is
dropped; the Steam library (263G) stays on the btrfs root, which is 51% full.

## Deliberately deferred

- What the two emptied disks are for (Steam library on the NVMe, `restic`/`borg`
  target on `sda`) — no plans yet, nothing blocks on it.
- Wallpaper-derived theming (`wallust`) — only if the static dark default annoys.
- Notification daemon (`mako`) — only if a missed DM costs something.
- `wf-recorder` — only if NVIDIA-independent recording is ever needed.

## Why it matters

The spec was written from a stale 10-day atime window and carried guesses: 14 web
apps of which five had never been opened, an Omarchy app list of which one is
wanted, a `SUPER+R` VNC bind whose package had not run in a month, and a `/mnt/games`
disk assumed to hold the Steam library it does not hold. Everything above replaces
those guesses with a verdict and the measurement it came from, so the migration
plan can be executed without re-litigating it.
