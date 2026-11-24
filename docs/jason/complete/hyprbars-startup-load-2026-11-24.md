# hyprbars startup load — the recurring config errors

**Task.** "errors in hyprland config again". `hyprland --verify-config` printed:

```
looknfeel.lua:5: unknown config key 'plugin.hyprbars.bar_height'
looknfeel.lua:5: unknown config key 'plugin.hyprbars.bar_padding'
looknfeel.lua:5: unknown config key 'plugin.hyprbars.bar_color'
looknfeel.lua:5: unknown config key 'plugin.hyprbars.bar_text_size'
rules.lua:12: hl.window_rule: unknown field 'hyprbars:no_bar'
```

**Cause.** `autostart.lua` ran `hyprpm reload -n` as a plain `hl.exec_cmd`, which
runs *while the config is being parsed* — before Hyprland's socket exists, so
the command has always died with `Couldn't connect to .../.socket.sock`. The
plugin was never loaded (`hyprctl plugin list` → `no plugins loaded`), and every
`plugin:hyprbars:*` key and the `hyprbars:no_bar` rule then read as unknown.

Verified: `hyprpm reload -n` against a live session loads it, and a config
reload after that reports no errors — so the config was correct, only the load
timing was wrong.

**Fix.**

- `autostart.lua`: load on the `hyprland.start` event instead —
  `hl.on("hyprland.start", …)` → `hyprpm reload -n && hyprctl reload`. The
  event fires once the compositor can answer, and the reload re-parses the
  config so the plugin keys land.
- `hyprland.lua`: `plugin_loaded(name)` walks `hl.get_loaded_plugins()`.
- `looknfeel.lua` / `rules.lua`: the hyprbars keys and the `hyprbars:no_bar`
  rule are set only when that returns true. Before the plugin is in they are
  skipped silently instead of erroring; the reload above comes back through and
  sets them.

**Why not `hl.plugin.load()` from the config.** The Lua API exists, but a
config-side load goes through the ecosystem permission system ("Waiting for
user confirmation to load <plugin>") and silently does nothing without it,
in `--verify-config` and in a live session alike. `hyprpm` (i.e.
`hyprctl plugin load`) has no such gate, so it stays the loader. `hyprpm` also
still owns the build: `hyprpm update` after a Hyprland bump.

**Check.** `hyprland --verify-config` → `config ok`; live `hyprctl
configerrors` empty; `hyprctl getoption plugin:hyprbars:bar_color` set.
