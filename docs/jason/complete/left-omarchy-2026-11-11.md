# Jason left Omarchy, 2026-11-11

Status: **done on disk, one reboot from proven.** The running session is already
the new desktop (config reloaded live); the reboot is what proves the stock
`linux` kernel boots it.

Rollback: `snapper` snapshot 13 `pre-aur-limine` is the pre-change filesystem,
`/etc/pacman.conf.omarchy-2026-11-11` the old repo definition, and the
`//linux-omarchy` boot entry is still present.

## What was on disk before, what is on disk now

| | Before | After |
|---|---|---|
| Packages | 1475 total / 265 explicit | 1220 total / 200 explicit |
| Repo | `[omarchy]` first in `pacman.conf` | removed, Arch `core`/`extra` only |
| Kernel | `linux-omarchy` 7.2.15 running, stock `linux` idle | `//linux` entry first; `linux-omarchy` kept one reboot as fallback |
| Session | `sddm` → `uwsm` → Hyprland + Quickshell shell | same, minus Quickshell: waybar + fuzzel + hyprpaper |
| Boot entries | written by Omarchy's `limine-*` cache | AUR `limine-mkinitcpio-hook` + `limine-snapper-sync`, both explicit |

## Order of operations actually used

1. AUR builds of the two limine tools installed over the `[omarchy]` copies
   (`pacman -U`, same upstream version), so the boot stack was never unowned.
2. `config/limine/zz-jason.conf` deployed: `ENABLE_UKI=yes` and
   `CUSTOM_UKI_NAME="omarchy"` were owned by `omarchy-settings`, so this file
   carries them. `zz-` prefix so it is read last.
3. Desktop config copied into `~/.config` (`hypr`, `waybar`, `fuzzel`); the old
   `~/.config/hypr` kept as `~/.config/hypr.omarchy-2026-11-11`.
4. `hyprctl reload` — live test of the new config while Omarchy was still
   installed. Found and fixed: hyprpaper 0.8's new per-monitor `wallpaper { }`
   syntax, and `autostart.lua` starting a second waybar/hypridle/udiskie on
   every reload (the Lua API has no `exec-once`, so each start is pgrep-guarded).
5. Prune: the 71 marked drops minus `mise-bin` → `pacman -Rs`, 255 packages
   gone including dependency orphans (wine, cups, QT5, poetry, v8-r, llvm-ish
   strays).
6. `[omarchy]` commented out of `/etc/pacman.conf`, `pacman -Sy`, then
   `-Rs` on the layer: `omarchy omarchy-settings omarchy-keyring
   omarchy-themes-intros omarchy-speedtest omarchy-hyprland-titlebars
   omarchy-power-profiles-daemon quickshell ttf-jetbrains-mono-nerd-basic`.
7. Fonts replaced first: `extra/ttf-jetbrains-mono` + `extra/ttf-nerd-fonts-symbols`.

## Traps found on the way (each would have cost a boot or a session)

- **`pacman -Rs omarchy` took both limine tools with it.** They were still
  marked "installed as a dependency for another package", so the recursive
  removal pulled `limine-mkinitcpio-hook` and `limine-snapper-sync` as orphans.
  Reinstalled from `~/build/aur/` and marked explicit. Do not trust the package
  source alone — `Install Reason` is what `-Rs` reads.
- **`/etc/sddm.conf.d/autologin.conf` had `Session=omarchy.desktop`**, a file the
  omarchy package owned. On the first reboot that session would not exist.
  Changed to `hyprland-uwsm.desktop`.
- **The two `omarchy-*.conf` files in `/etc/limine-entry-tool.d/`** held
  `ENABLE_UKI=yes` and `CUSTOM_UKI_NAME="omarchy"`; losing them silently changes
  how boot entries are written. Now in `config/limine/zz-jason.conf`.
- **`mise-bin` was held back on purpose**: mise also provides `node`, `uv`, `go`,
  `zig`, `julia`, `elixir` and the agent fleet. `amp` and `opencode` are already
  installed to `/usr/bin` from npm (`@ampcode/cli`, `@opencode/cli`), but the
  rest still resolve through mise. Removing it needs one more pass.

## Workspaces: Omarchy's 10-per-monitor scheme went with it

Omarchy ran `monitor-workspaces.lua`, so DP-2 owned 1–10 and **DP-1 owned 11–20**.
That is why the old bar showed `1 11 14`: workspace 11 held a terminal and 14 the
floating Steam window. After the layer went, 11 and 14 were just orphan numbers.
Both windows were moved back into the real range (11 → 6, 14 → 7) and the bar now
shows only workspaces that exist.

waybar's `persistent-workspaces` does not fill in the missing 2–5, 8–10: on
0.15.0 `{"DP-2": 10}` produced workspaces 21–30 and `{"*": 10}` created nothing,
so the option was dropped rather than shipped broken.

## Still to do after the reboot

1. Boot `//linux`; if it fails, `//linux-omarchy` is still there (menu timeout is
   now 10 s so it can be picked).
2. Once booted: `pacman -Rns linux-omarchy linux-omarchy-headers` and drop its
   UKI — that also brings `/boot` from 53% to ~27%, which is what re-enables
   `limine-snapper-sync` snapshot entries (it refuses above
   `LIMIT_USAGE_PERCENT=50`).
3. Move the mise-managed toolchain (`node`, `uv`, `go`, `zig`, `julia`, `elixir`,
   `claude`, `codex`, `gh`) to pacman/AUR/npm, then `pacman -Rns mise-bin`.
4. Rename the Limine OS entry if "Omarchy" as a boot menu label is unwanted —
   `TARGET_OS_NAME` in `/etc/limine-entry-tool.d/zz-jason.conf`, then
   `limine-update`. Cosmetic; the entry is matched by machine-id.
