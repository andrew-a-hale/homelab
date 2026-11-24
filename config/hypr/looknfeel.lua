-- Look and feel. Read back from the old desktop with `hyprctl getoption`, not
-- taken from a theme system: no rounding, no blur, a thin blue active border.
-- Tune freely — nothing depends on them.

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    col = {
      active_border = "0xff7aa2f7",
      inactive_border = "0xaa595959",
    },
    layout = "dwindle",
  },

  decoration = {
    rounding = 0,
    dim_inactive = false,
    shadow = { enabled = true },
    blur = { enabled = false },
  },

  animations = {
    enabled = true,
  },

  misc = {
    font_family = "Sans",
  },
})

-- hyprbars (hyprpm plugin): draggable titlebar on floating windows only.
-- A left-click on the bar starts a window drag with no modifier held.
--
-- The plugin is a .so loaded by `hyprpm`, which needs the compositor socket —
-- that only exists after this file has been parsed, so the keys are set only
-- when the plugin is actually in (autostart.lua loads it, then reloads this
-- config, which drops back into here and sets them). Setting them blind is what
-- made every boot print `unknown config key 'plugin.hyprbars.*'`.
if plugin_loaded("hyprbars") then
  hl.config({
    plugin = {
      hyprbars = {
        bar_height = 22,
        bar_padding = 10,
        bar_text_size = 10,
        bar_color = "0xcc1e1e2e",
      },
    },
  })
end

-- No workspace slide: switching workspace is instant, everything else keeps
-- Hyprland's default animation. `hl.animation` is the Lua form of
-- `animation = workspaces, 0`; 0.56 also has the In/Out leaves.
for _, leaf in ipairs({ "workspaces", "workspacesIn", "workspacesOut" }) do
  hl.animation({ leaf = leaf, enabled = false })
end
