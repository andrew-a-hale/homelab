# Jason docs: the 2026-11-12 tidy

Jason left Omarchy on 2026-11-11 and the byte-level work finished the same day
([record](left-omarchy-2026-11-11.md)). What was left was the paperwork: several
`docs/jason/` files still described the *plan* in the present tense — a 265-package
inventory including packages that are no longer installed, a "migration pending"
appendix, a duplicate copy of a config that lives in `config/`, and a todo
directory whose items were all decided. Anyone reading them (human or agent) would
have been told the wrong thing about the machine.

So: current state only. History stays in the dated records in this directory.

## What changed

| Gone | Why |
|---|---|
| `docs/jason/packages.md` (472 lines) | Generated 2026-11-11 *before* the drops: listed `omarchy`, `linux-omarchy`, `quickshell`, `ntfs-3g` and 70-odd others as present, plus a verdict column that no longer applied. The live answer to "what is installed" is `pacman -Qe`, and the rebuild answer is `whitelist.md`. A hand-patched snapshot only rots. |
| `scripts/jason-package-inventory.py` (~230 lines) | Its only output was that file. |
| `docs/jason/files/hypr/` | A copy of the live `~/.config/hypr` taken before the cutover; `config/hypr/` is the deployed source and the two had already diverged (old `bindings.lua` vs `binds.lua`). One source of truth. |
| `docs/jason/todo/` | `needs.md` is a completed walkthrough → moved to [`complete/needs-2026-11-11.md`](needs-2026-11-11.md). Nothing left to track. |

| Rewritten | Now says |
|---|---|
| [`whitelist.md`](../whitelist.md) | the install list: grouped `pacman -S` lines for the 177 explicit packages, the eight AUR ones, what is deliberately absent, four traps that cost time once. No verdict tables, no "drop" markers, no migration appendix. |
| [`services.md`](../services.md) | what runs now: three custom units (their scripts run from this repo), the packaged units kept, the user units, and a one-line "gone" list. |
| [`README.md`](../README.md) | hardware and shape table refreshed to the box as it boots today; omarchy-era prose and the stale "53 unused packages" figure removed. |
| [`../../config/README.md`](../../../config/README.md) | "Known gaps" (wallpaper missing, packages not installed yet) were closed; they are decisions now. |
| `services/jason/README.md` | qBittorrent leftovers: removed, not pending. |

Also done on the box, not just documented: `qbittorrent.service`, its unit file and
`~/.config/qBittorrent`, `~/.local/share/qBittorrent` are gone (the package already
was). Nothing else on Jason referenced them.

## Evidence the state is current

- `pacman -Qe` → 177 explicit, 1184 total; `pacman -Qm` → the eight AUR packages
  in `whitelist.md`.
- `scripts/pacman-atime-audit.sh 30` → **nothing unused in 30 days**. No drops are
  pending, which is why the verdict tables had nothing to say any more.
- `diff -r config/{hypr,waybar,fuzzel} ~/.config/{hypr,waybar,fuzzel}` → empty
  (only `~/.config/hypr/.luarc.json`, an editor file).
- Cold boot 2026-11-12 07:30 proved both ext4 volumes (`/mnt/games`,
  `/mnt/storage`) and the single snapshot boot entry survive a reboot.
