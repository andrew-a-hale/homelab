# config/

Jason's desktop session, without Omarchy. Plain Hyprland, waybar, fuzzel.

Everything here is derived from `docs/jason/`:

| This directory | Replaces | Evidence |
|---|---|---|
| `hypr/binds.lua` | `~/.config/hypr/bindings.lua` + Omarchy's `default/hypr/bindings/` | [`binds.md`](../docs/jason/binds.md), 37 binds + `SUPER+L` |
| `hypr/{hyprland,monitors,input,looknfeel,rules,autostart}.lua` | Omarchy's `default/hypr/*` | [`README.md`](../docs/jason/README.md), [`needs.md`](../docs/jason/todo/needs.md) |
| `hypr/hypridle.conf`, `hypr/hyprlock.conf` | Omarchy's screensaver + `omarchy-system-lock` | lock at 150 s, no screensaver process |
| `hypr/hyprpaper.conf` | Quickshell's wallpaper layer | static wallpaper |
| `waybar/` | Omarchy's Quickshell bar | workspace indicator, clock + date, wifi, volume |
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

## Known gaps

- **Wallpaper**: `hypr/hyprpaper.conf` points at `~/Pictures/wallpaper.png`, which
  does not exist yet. Convert one out of the Omarchy themes *before* the `[omarchy]`
  repo goes — they ship as `.webp`, which hyprpaper cannot read (no libwebp in its
  dependencies). The `ffmpeg` one-liner is in the config file.
- **pacman packages**: `hyprpaper`, `waybar`, `fuzzel`, `hypridle`, `hyprlock`,
  `grim`, `slurp`, `satty`, `wl-clipboard`, `gpu-screen-recorder` are not installed
  yet — see [`whitelist.md`](../docs/jason/whitelist.md).
- **No notification daemon, no OSD, no tray**: deliberate, `needs.md` batch 5. The
  scripts do not call `notify-send` for that reason.
- **Theming** is static and hand-written. There is no theme switcher; change the
  colours in `hypr/looknfeel.lua`, `waybar/style.css` and `fuzzel/fuzzel.ini` if
  they ever need to change (`#7aa2f7` is the accent in all three).

## Verified

Loaded against the live Hyprland 0.56.2 Lua API on 2026-11-11 via
`hyprctl eval "dofile(...)"` — `binds.lua` registered all 40 binds with no error,
`looknfeel.lua` and `input.lua` applied cleanly (their values are the ones the
desktop already ran with). `monitors.lua` is the live config unchanged, so it was
not re-applied. `autostart.lua` was syntax-checked only; loading it would have
started the bar and the wallpaper daemon.
