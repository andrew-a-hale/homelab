-- Jason: plain Hyprland, configured in Lua. This is the entry point; Hyprland loads
-- ~/.config/hypr/hyprland.lua and everything else is required from here.
-- Source of truth for what is in here: docs/jason/{binds,whitelist,needs}.md.

--------------------
---- environment ----
--------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Wayland everywhere.
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Both monitors are on the RTX 3070 (card1), so NVIDIA backs the display and
-- its VA-API/GLX drivers are the right ones to force. The Radeon 610M (card0)
-- drives nothing.
hl.env("NVD_BACKEND", "direct")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- fcitx5 (mozc). No environment.d file carries these, so the input-method
-- variables live here.
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- Is an hyprpm plugin in? Used by looknfeel.lua and rules.lua: their plugin
-- config keys and plugin window rules are hard errors when it is not loaded.
function plugin_loaded(name)
  for _, plugin in ipairs(hl.get_loaded_plugins()) do
    if plugin.name == name then return true end
  end
  return false
end

require("monitors")
require("input")
require("looknfeel")
require("rules")
require("binds")
require("autostart")
