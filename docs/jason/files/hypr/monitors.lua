-- Restored from pre-Quattro monitors.conf (old config was not auto-migrated).
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Main gaming display with workspaces 1,3,4,5 pinned to it.
hl.monitor({ output = "DP-2", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
hl.workspace_rule({ workspace = "1", monitor = "DP-2" })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })

-- Portrait secondary display; workspace 2 pinned and persistent.
hl.monitor({ output = "DP-1", mode = "preferred", position = "1920x-190", scale = omarchy_monitor_scale, transform = 3 })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })