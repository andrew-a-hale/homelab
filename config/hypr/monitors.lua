-- Display layout. Values are what the machine runs today (hyprctl monitors).
-- List monitors and supported modes with: hyprctl monitors all

hl.env("GDK_SCALE", "1")

-- Main gaming display, landscape, primary. Workspaces 1-6 live here and are
-- `persistent` so they exist before a window does: without that Hyprland only
-- creates a workspace when something opens on it, and the bar shows a shifting
-- row of numbers instead of 1-10.
hl.monitor({ output = "DP-2", mode = "preferred", position = "0x0", scale = "auto" })

for workspace = 1, 6 do
  hl.workspace_rule({ workspace = tostring(workspace), monitor = "DP-2", persistent = true })
end

-- Portrait secondary at the right edge; workspace 2 belongs to it instead.
-- Last rule wins, so this overrides the loop above.
hl.monitor({ output = "DP-1", mode = "preferred", position = "1920x-190", scale = "auto", transform = 3 })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
