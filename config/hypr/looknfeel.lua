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
