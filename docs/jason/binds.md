# Jason keymap — for the Omarchy-free Hyprland config

Hand-edited source of truth. One row per bind; delete a row to drop the bind, add a
row to add one. `?` in the notes column is a question I could not settle from
evidence — decide it here.

Style: `SUPER + X` means Super held. `SHIFT`/`CTRL`/`ALT` are spelled the same way
the config spells them. Mouse binds are named as Hyprland names them.

## Windows

| Bind | Action | Notes |
|---|---|---|
| `SUPER + LEFT` | focus left | |
| `SUPER + RIGHT` | focus right | |
| `SUPER + UP` | focus up | |
| `SUPER + DOWN` | focus down | |
| `SUPER + SHIFT + LEFT` | swap window left | |
| `SUPER + SHIFT + RIGHT` | swap window right | |
| `SUPER + SHIFT + UP` | swap window up | |
| `SUPER + SHIFT + DOWN` | swap window down | |
| `SUPER + LEFT MOUSE` | move window | works on floating windows |
| `SUPER + RIGHT MOUSE` | resize window | works on floating windows |
| `SUPER + MINUS` | resize narrower | |
| `SUPER + EQUAL` | resize wider | |
| `SUPER + CTRL + MINUS` | resize narrower, big step | |
| `SUPER + CTRL + EQUAL` | resize wider, big step | |
| `SUPER + SHIFT + F` | fullscreen | was files on the old config, swapped |
| `SUPER + T` | toggle this window floating | |
| `SUPER + J` | toggle split | |
| `SUPER + P` | pseudo-tile | |
| `SUPER + O` | pop window out: float + pin | keep |
| `SUPER + W` | close window | polite close: WM_DELETE. Steam's XWayland window ignores it |
| `SUPER + SHIFT + W` | force-close window | `kill`, for apps that ignore the polite close (Steam) |

## Workspaces

| Bind | Action | Notes |
|---|---|---|
| `SUPER + 1` … `SUPER + 0` | switch to workspace 1–10 | |
| `SUPER + SHIFT + 1` … `SUPER + 0` | move window to workspace 1–10 | |
| `SUPER + L` | toggle this workspace tiling ↔ floating | the one layout key, `arch-desktop-spec.md` §2.1 |

## Apps

| Bind | Action | Notes |
|---|---|---|
| `SUPER + RETURN` | ghostty | |
| `SUPER + B` | firefox | |
| `SUPER + SHIFT + B` | chromium, Profile 4 | |
| `SUPER + ALT + RETURN` | tmux | |
| `SUPER + CTRL + RETURN` | herdr | the one Omarchy app that survives, `needs.md` batch 1 |
| `SUPER + F` | nautilus | |
| `SUPER + N` | nvim | |
| `SUPER + A` | btop | |
| `SUPER + D` | vesktop | |
| `SUPER + S` | steam | |
| `SUPER + SPACE` | fuzzel launcher | replaces Omarchy's menu |

## Capture

| Bind | Action | Notes |
|---|---|---|
| `PRINT` | region screenshot → annotate in satty → clipboard + save | `grim -g "$(slurp)" - \| satty --filename -` |
| `SHIFT + PRINT` | whole focused monitor → satty | `grim -o "$(hyprctl monitors -j ...)"` |
| `ALT + PRINT` | start/stop screen recording | `gpu-screen-recorder`, toggle in one script |

## System

| Bind | Action | Notes |
|---|---|---|
| `SUPER + CTRL + L` | lock | `hyprlock` |
| `SUPER + ESCAPE` | power menu: lock / logout / reboot / shutdown ||

## Deliberately not bound

Kept here so nothing gets re-added by accident.

- **Omarchy furniture**: menu (`SUPER+SPACE` old), panels 1–9, audio/network/power/
  display/hardware/share/calendar/weather/time/reminders menus, keybindings
  cheatsheet (`SUPER+K`), theme menu, `SUPER+CTRL+O` menu toggle.
- **Webapps** (no web apps at all, `needs.md` batch 3): `SUPER+M`, `SUPER+Y`,
  `SUPER+SHIFT+S`, `SUPER+D`, `SUPER+SHIFT+A`, `SUPER+SHIFT+ALT+A`,
  `SUPER+SHIFT+ALT+G`, `SUPER+SHIFT+ALT+E`.
- **Gone with the app**: `SUPER+R` (VNC to Tom, tigervnc dropped), `SUPER+CTRL+RETURN`
  stays because herdr stays.
- **Gone with the dock**: `SUPER+M` minimise to dock.
- **Gone with the Omarchy shell**: notification keys (dismiss, silence, history),
  bar panel keys, `SUPER+CTRL+SPACE`/`SUPER+CTRL+W` background switcher,
  `SUPER+BACKSPACE` transparency, `SUPER+ALT+BRACKETLEFT/RIGHT` webcam overlay.
- **Gone with the layout engine**: `SUPER+ALT+L` layout cycle back.
- **Never used**: scratchpad (`SUPER+ALT+S`, `SUPER+ALT+SPACE`), Quake console
  (`SUPER+~`), `SUPER+CTRL+F` tiled fullscreen, `SUPER+ALT+F` full width,
  `SUPER+ALT+Home`/`SUPER+Home` save/restore width, `SUPER+CTRL+BACKSPACE` square
  aspect, `CTRL+ALT+DELETE` close all, `SUPER+PRINT` colour picker,
  `SUPER+CTRL+PRINT` OCR, `SUPER+CTRL+V` clipboard manager, `SUPER+CTRL+E` emoji,
  `CTRL+SPACE` terminal prefix, `SUPER+CTRL+ALT+*` info keys, monitor scaling,
  `SUPER+CTRL+I` idle lock toggle, `SUPER+DELETE`/laptop-display keys (desktop, no
  internal panel), webapp URL/download keys, the `hw-*` machine-profile keys.
