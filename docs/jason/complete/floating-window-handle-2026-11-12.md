# Floating window handle — hyprbars

**Task.** Asked whether Hyprland can put a mouse-draggable handle on floating
windows, i.e. a titlebar you grab without holding a modifier.

**Decision.** Hyprland itself draws no decorations at all — no titlebars, no
grips — so there is nothing to configure. Dragging is a keybind
(`binds.lua`: `SUPER + mouse:272` → `hl.dsp.window.drag()`). A visible,
modifier-free handle means a decoration plugin: **hyprbars**, from
[`hyprwm/hyprland-plugins`](https://github.com/hyprwm/hyprland-plugins), built
with `hyprpm`. Decided: floating windows only.

## Why hyprbars and not the alternatives

| Option | Verdict |
|---|---|
| `bindm = SUPER, mouse:272, movewindow` (what Jason already had) | kept, but it needs a key held — not a handle |
| Client-side decorations (GTK/Qt titlebars) | per-app, inconsistent, and the bar is the app's, not the compositor's |
| `hyprbars` | official plugin repo by Vaxry, renders a real decoration, left-click on the bar calls `changeMouseBindMode(MBIND_MOVE)` — drag with no modifier, works on tiled windows too, so bars are gated per window rule |

## What was done (2026-11-12)

Version pinning matters: the plugin ABI is the compositor's. Hyprland here is
**0.56.2**, and `hyprpm.toml` pins plugin commit `7644cec` (= tag `v0.56.0`) to
exactly that build, so that is the commit built:

```bash
sudo pacman -S --needed hyprpm cmake meson
hyprpm update                       # installs headers for the running 0.56.2
hyprpm add https://github.com/hyprwm/hyprland-plugins v0.56.0
hyprpm enable hyprbars && hyprpm reload
```

Config ([`config/hypr/looknfeel.lua`](../../../config/hypr/looknfeel.lua), Lua
parser, so a table rather than hyprlang keywords):

```lua
plugin = { hyprbars = { bar_height = 22, bar_padding = 10, bar_text_size = 10,
                        bar_color = "0xcc1e1e2e" } }
```

Floating only ([`config/hypr/rules.lua`](../../../config/hypr/rules.lua)):

```lua
hl.window_rule({ name = "hyprbars-floating-only", match = { float = false },
                 ["hyprbars:no_bar"] = true })
```

The rule effect name is **`hyprbars:no_bar`**, not `plugin:hyprbars:nobar` as
the hyprlang README shows: the plugin registers `windowEffects()->registerEffect("hyprbars:no_bar")`,
and that registry — not the `plugin:` config namespace — is what
`hl.window_rule` looks keys up in. Getting this wrong fails loudly at parse
time (`unknown field`), so it is hard to get silently wrong.

## Notes for the next person

- `plugin:hyprbars:bar_height` etc. still work through `getoption` and
  `hl.config({ plugin = { hyprbars = ... } })`; that is the config namespace,
  separate from the rule namespace.
- The bar colour default is `0x88333333` — translucent grey, which disappears
  on this dark theme. Hence the explicit `0xcc1e1e2e`.
- Bump `hyprland` in pacman → `hyprpm update && hyprpm reload`, or the plugin
  refuses to load until rebuilt against the new headers.
- `hyprctl keyword plugin:hyprbars:bar_height 22` does **not** work on the Lua
  parser (`keyword can't work with non-legacy parsers`). Use
  `hyprctl eval 'hl.config{...}'` for a live poke.
- Debugging the plugin: `hyprctl decorations activewindow` lists the attached
  decorations by display name (`Hyprbar`); `hyprctl plugin list` only proves the
  `.so` loaded, not that a window has a bar.
