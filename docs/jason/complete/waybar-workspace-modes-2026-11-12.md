# Waybar workspace colour, and the 6-workspace cap — 2026-11-12

Asked for: at a glance, which workspaces have windows. Colour, not letters.
Same session, two corrections from the user: no floating/tiling indicator on the
bar at all (grey-out for empty is enough), and `SUPER + 7` must not be able to
grow a seventh workspace. Both applied; the floating module added earlier the
same day is deleted, not disabled.

## The signal, final

| Colour | Meaning | Comes from |
|---|---|---|
| `#565f89` dim grey | workspace exists, no windows | `#workspaces button.empty` |
| `#c0caf5` light | has windows | base `#workspaces button` rule |
| `#7aa2f7` accent blue | active workspace | `#workspaces button.active` (unchanged) |
| `#f7768e` red | urgent | `#workspaces button.urgent` (unchanged) |

Nothing else on the bar carries workspace state. That is the whole module:
`hyprland/workspaces` with `"format": "{name}"`, plus two CSS rules
(`config/waybar/style.css`).

## Why the floating indicator went

It was built (`custom/float`, a polled script that repeated the number of an
all-floating workspace as an orange chip) and removed on sight: the duplicate
number read worse than it looked on paper, and mode is visible from the screen
anyway — a floating window is not filling its half of the tiling. The built-in
`hyprland/workspaces` cannot colour the number in place (its only classes are
`active`, `empty`, `visible`, `persistent`, `special`, `urgent`,
`hosting-monitor`; floating is per window, not per workspace), so "colour the
number when floating" was never a small change. Dropped rather than overbuilt.
Nothing else changed: `{name}`, `on-click: activate`, `sort-by-number`.

## The 6-workspace cap

`config/hypr/binds.lua` bound `SUPER + 1..0` to workspaces 1–10 with a
`workspace % 10` key map. Waybar shows the workspaces that exist, so `SUPER + 7`
materialised workspace 7 on the bar — a workspace that only ever held accidental
windows. The loop is now `1, 6`:

```lua
for workspace = 1, 6 do
  local key = tostring(workspace)
  hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = key }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = key }))
end
```

`SUPER + 7/8/9/0` are now unbound, deliberate YAGNI: six workspaces fit two
1080p outputs (four landscape on DP-2, portrait DP-1, plus one spare). Windows
can still be *moved* to a workspace that exists and dragged to another monitor;
what is gone is the ability to conjure workspace 7+ with one key. If more are
ever wanted, extend the loop — the bar follows automatically, it is not a fixed
row.

## Verified

- `hyprctl binds -j`: modmask 64/65 bind `__lua` for keys `1`–`6` only; nothing
  on `7 8 9 0`.
- `hyprctl workspaces -j`: 1–6 exist, no 7–10.
- Bar screenshot after `hyprctl reload` + `killall -SIGUSR2 waybar`: active 1
  blue, 3/4/5 dim, 6 light — no orange chip, no gap left by the removed module
  (`journalctl --user -u waybar` clean).
- `diff -r config/waybar ~/.config/waybar` and the same for `binds.lua`: empty,
  so what is documented is what is running. `~/.config/waybar/workspaces-float.sh`
  deleted.

## Click-to-switch needed waybar 0.16.0

Reported third in the same session: clicking a workspace number on the bar did
nothing. Root cause is not a config toggle — `hyprland/workspaces` has **no**
`on-click` option at all; its click handler is compiled in
(`src/modules/hyprland/workspace.cpp`, `Workspace::handleClicked`) and 0.15.0
sends the legacy socket command `dispatch workspace <n>`. This Hyprland runs the
**Lua config manager** (`hyprctl systeminfo` → `configProvider: lua`), which
evaluates every socket dispatch as Lua:

```console
$ hyprctl dispatch workspace 3
error: [string "return hl.dispatch(workspace 3)"]:1: ')' expected near '3'
```

So every `hyprctl dispatch <legacy>` on this box fails — waybar's click, and
`power-menu.sh`'s logout (`hyprctl dispatch exit`). Reads (`activeworkspace`,
`clients`, …) are unaffected.

waybar 0.16.0 detects the provider from `systeminfo` and builds
`hl.dsp.focus({ workspace = "N" })` instead (`IPC::isLuaProtocol` /
`buildLuaDispatch` in `backend.cpp`, absent from 0.15.0). The fix is the package
upgrade, `extra/waybar` 0.15.0-3 → 0.16.0-1 — no script, no patch, no
`on-click` entry. The dead `"on-click": "activate"` line and the 0.15-era
`"sort-by-number": true` (0.16 calls it `"sort-by": "number"`) were removed.

Fixed at the same root cause:

```sh
# config/hypr/scripts/power-menu.sh
logout) hyprctl dispatch 'hl.dsp.exit()' ;;
```

Verified: the exact string 0.16 builds, `dispatch hl.dsp.focus({ workspace = "4" })`,
is accepted on the socket (`ok`, active workspace becomes 4) while
`dispatch workspace 4` is rejected; `configProvider: lua` is present in the
socket `j/systeminfo` reply, which is what 0.16 keys off. **Nothing depends on
waybar < 0.16.0 any more — do not downgrade it.**
