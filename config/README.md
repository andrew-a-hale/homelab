# config/

Jason's desktop session, without Omarchy. Plain Hyprland, waybar, fuzzel.

Everything here is derived from `docs/jason/`:

| This directory | Replaces | Evidence |
|---|---|---|
| `hypr/binds.lua` | `~/.config/hypr/bindings.lua` + Omarchy's `default/hypr/bindings/` | [`binds.md`](../docs/jason/binds.md), 40 binds incl. workspaces 1–6 and `SUPER+L` |
| `hypr/{hyprland,monitors,input,looknfeel,rules,autostart}.lua` | Omarchy's `default/hypr/*` | [`README.md`](../docs/jason/README.md), [`binds.md`](../docs/jason/binds.md) |
| `hypr/hypridle.conf`, `hypr/hyprlock.conf` | Omarchy's screensaver + `omarchy-system-lock` | lock at 150 s, no screensaver process |
| `hypr/hyprpaper.conf` | Quickshell's wallpaper layer | static wallpaper |
| `waybar/` | Omarchy's Quickshell bar | workspace indicator (colour = state: dim empty, light has windows, blue active; click a number to switch), clock + date, wifi, volume. Workspaces are capped at 6 — `SUPER + 7..0` unbound. Needs **waybar ≥ 0.16.0**: older releases send the legacy `dispatch workspace N`, which this Lua-config Hyprland rejects ([why](../docs/jason/complete/waybar-workspace-modes-2026-11-12.md)) |
| `fuzzel/fuzzel.ini` | Omarchy's menu | `SUPER + SPACE` |
| `hypr/scripts/` | `omarchy-*` helper scripts | capture, recording, power menu |
| `shell/bashrc`, `shell/starship.toml` | `~/.bashrc`'s `source /usr/share/omarchy/default/bash/rc` | the prompt and history settings Omarchy's rc provided |
| `limine/zz-jason.conf` | `/etc/limine-entry-tool.d/zz-jason.conf` | UKI settings `omarchy-settings` used to own; `zz-` so it is read last and wins — see [`../docs/jason/complete/boot-entries-off-omarchy-2026-11-11.md`](../docs/jason/complete/boot-entries-off-omarchy-2026-11-11.md) |

## Deploy

Nothing here is secret. It is copied, not symlinked, so a bad edit cannot take
the session down on reload:

```sh
cp -a config/hypr    ~/.config/
cp -a config/waybar  ~/.config/
cp -a config/fuzzel  ~/.config/
cp    config/shell/bashrc   ~/.bashrc
cp    config/shell/starship.toml ~/.config/
sudo cp config/limine/zz-jason.conf /etc/limine-entry-tool.d/   # already done
# one knob is NOT in that directory — snapshot boot entries read it here:
sudo sed -i 's/^LIMIT_USAGE_PERCENT=.*/LIMIT_USAGE_PERCENT=70/' /etc/default/limine
```

Then enable the three that ship systemd user units — do **not** start them from
`hypr/autostart.lua`, that runs before uwsm exports `WAYLAND_DISPLAY` and the bar
silently fails to appear on the next login:

```sh
systemctl --user enable --now waybar hyprpaper hypridle
hyprctl reload
```

First run on a fresh plain-Hyprland install: back up the existing `~/.config/hypr`
first — Hyprland's sample config lives there and it is easier to keep it as
`hypr.orig/` than to regenerate it.

## Decisions worth knowing

- **Wallpaper**: `hypr/hyprpaper.conf` points at `~/Pictures/wallpaper.png`, static,
  converted once from an Omarchy `.webp` theme (hyprpaper has no libwebp).
- **No notification daemon, no OSD, no tray**: deliberate. The scripts do not call
  `notify-send` for that reason.
- **Theming** is static and hand-written. There is no theme switcher; change the
  colours in `hypr/looknfeel.lua`, `waybar/style.css` and `fuzzel/fuzzel.ini` if
  they ever need to change (`#7aa2f7` is the accent in all three).
- **No workspace slide**: `looknfeel.lua` disables the `workspaces`,
  `workspacesIn` and `workspacesOut` animation leaves (Hyprland 0.56's Lua form
  of `animation = workspaces, 0`). Switching workspace is instant; window
  open/close, fades and borders keep their defaults.

## Verified

Loaded against the live Hyprland 0.56.2 Lua API on 2026-11-11 via
`hyprctl eval "dofile(...)"` — `binds.lua` registered all 40 binds with no error,
`looknfeel.lua` and `input.lua` applied cleanly (their values are the ones the
desktop already ran with). `monitors.lua` is the live config unchanged, so it was
not re-applied. `autostart.lua` was syntax-checked only; loading it would have
started the bar and the wallpaper daemon.

## systemd user drop-ins

| File | Installed to | Why |
|---|---|---|
| `systemd/user/hyprpaper.service.d/10-wait-for-compositor.conf` | `~/.config/systemd/user/hyprpaper.service.d/` | The shipped unit is `Restart=on-failure`, and at login hyprpaper often loses the race with the compositor's Wayland socket (`wl_display_connect failed`), hits the start limit and stays dead — no wallpaper for the session. `Restart=always` + `RestartSec=3` + `StartLimitIntervalSec=0` makes it retry until the socket is up. Verified by killing it and watching it come back |

```bash
install -Dm644 config/systemd/user/hyprpaper.service.d/10-wait-for-compositor.conf \
  ~/.config/systemd/user/hyprpaper.service.d/10-wait-for-compositor.conf
systemctl --user daemon-reload && systemctl --user restart hyprpaper
```
