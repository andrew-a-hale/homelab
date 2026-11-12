-- Look and feel. These are the values the desktop effectively ran with under
-- Omarchy (read back with `hyprctl getoption`), not Omarchy's theme system:
-- no rounding, no blur, a thin blue active border. Tune freely — nothing
-- depends on them.

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

-- No workspace slide: switching workspace is instant, everything else keeps
-- Hyprland's default animation. `hl.animation` is the Lua form of
-- `animation = workspaces, 0`; 0.56 also has the In/Out leaves.
for _, leaf in ipairs({ "workspaces", "workspacesIn", "workspacesOut" }) do
  hl.animation({ leaf = leaf, enabled = false })
end
