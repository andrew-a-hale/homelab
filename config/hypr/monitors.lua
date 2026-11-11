-- Display layout. Values are what the machine runs today (hyprctl monitors).
-- List monitors and supported modes with: hyprctl monitors all

hl.env("GDK_SCALE", "1")

-- Main gaming display, landscape, primary; workspaces 1,3,4,5 are pinned here.
hl.monitor({ output = "DP-2", mode = "preferred", position = "0x0", scale = "auto" })
hl.workspace_rule({ workspace = "1", monitor = "DP-2" })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })

-- Portrait secondary at the right edge; workspace 2 is pinned and persistent.
hl.monitor({ output = "DP-1", mode = "preferred", position = "1920x-190", scale = "auto", transform = 3 })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
