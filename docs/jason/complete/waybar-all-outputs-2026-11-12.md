# Both bars list every workspace — 2026-11-12

Asked for: show all workspaces on all monitors, highlight the one each bar is
showing. Each bar now lists 1–6 and exactly one chip per bar is blue: the
workspace that bar's monitor displays.

## Two lines

`config/waybar/config.jsonc`: `"all-outputs": false` → `true`.
`config/waybar/style.css`: the `.active` rule became
`#workspaces button.visible.hosting-monitor`.

## Why that selector

`hyprland/workspaces` has three relevant classes (there is no option for it):

| Class | Real meaning (measured, 0.16.0) |
|---|---|
| `.active` | the **globally** focused workspace — one for the whole compositor |
| `.visible` | currently on screen on *some* monitor |
| `.hosting-monitor` | hosted on **this bar's** monitor (every such workspace, not just the shown one) |

Styling `.active` lights the same number on both bars (1 blue on DP-1's bar
while DP-1 shows 2). `.hosting-monitor` alone lights every workspace on that
monitor. The intersection is the answer, and GTK CSS supports the compound:
`button.visible.hosting-monitor`. It worked but has no option or doc line of its
own, hence this note.

## Verified

Screenshots of both bars via `grim -o DP-1` / `grim -o DP-2`, `hyprctl monitors
-j`: DP-1 (showing workspace 2) → `1 2 3 4 5 6` with **2** blue; DP-2 (showing
1) → **1** blue. Class probe run first with junk colours (`.visible` yellow,
`.hosting-monitor` red, compound blue) to confirm the mapping. `diff -r
config/waybar ~/.config/waybar` empty, `journalctl --user -u waybar` clean.

Trap for next time: waybar **exits on bad CSS** (`style.css:67:48 Junk at end
of value for background`) and systemd then hits `start-limit-hit` — the bar
silently vanishes. GTK CSS has no `!important`. `systemctl --user
reset-failed waybar` after fixing it.

Workspace *clicks* are unchanged and still per-workspace, so clicking a number
on the left bar switches the focused monitor to it.
