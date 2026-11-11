-- Restored from pre-Quattro input.conf (old config was not auto-migrated).
-- Values below override Omarchy defaults. Terminal scroll-touchpad rules and
-- kb_layout=us/numlock are already in the defaults, so not repeated here.

hl.config({
  input = {
    kb_options = "caps:escape",
    repeat_rate = 50,
    repeat_delay = 200,
    accel_profile = "flat",
    touchpad = {
      scroll_factor = 0.4,
    },
  },
})