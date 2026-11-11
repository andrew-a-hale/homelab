-- Every bind, one row per key. The list is docs/jason/binds.md — that file is the
-- source of truth for *what* is bound; this is how.

local home = os.getenv("HOME")
local shot = home .. "/.config/hypr/scripts/screenshot.sh"
local record = home .. "/.config/hypr/scripts/screenrecord.sh"
local power = home .. "/.config/hypr/scripts/power-menu.sh"

------------------
---- windows -----
------------------

hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "d" }))

hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.swap({ direction = "l" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.swap({ direction = "r" }))
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.swap({ direction = "u" }))
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.swap({ direction = "d" }))

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- MINUS narrows, EQUAL widens. CTRL is the big step.
hl.bind("SUPER + MINUS", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind("SUPER + EQUAL", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind("SUPER + CTRL + MINUS", hl.dsp.window.resize({ x = 300, y = 0, relative = true }))
hl.bind("SUPER + CTRL + EQUAL", hl.dsp.window.resize({ x = -300, y = 0, relative = true }))

hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + W", hl.dsp.window.close())

-- Pop the window out: float it and pin it to every workspace, like Omarchy's.
hl.bind("SUPER + O", function()
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  hl.dispatch(hl.dsp.window.pin({ action = "toggle" }))
end)

---------------------
---- workspaces -----
---------------------

for workspace = 1, 10 do
  local key = tostring(workspace % 10) -- 10 is the 0 key
  hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(workspace) }))
  hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

-- SUPER + L: float the whole workspace, again to tile it back. The named rule
-- makes windows opened later float too; the loop covers the ones already there.
-- ponytail: session-only, a reload leaves the workspace tiling; windows an app
-- floats by its own rule tile on toggle-off -- tag them if that ever bites.
local floating_workspaces = {}

hl.bind("SUPER + L", function()
  local ws = hl.get_active_workspace()
  if not ws or ws.id < 1 then return end

  local on = not floating_workspaces[ws.id]
  floating_workspaces[ws.id] = on or nil

  hl.window_rule({
    name = "float-workspace-" .. ws.id,
    enabled = on,
    match = { workspace = tostring(ws.id) },
    float = true,
  })

  for _, window in ipairs(hl.get_workspace_windows(tostring(ws.id))) do
    if on and not window.floating and (window.fullscreen or 0) == 0 then
      hl.dispatch(hl.dsp.window.float({ action = "set", window = window }))
    elseif not on and window.floating and not window.pinned then
      hl.dispatch(hl.dsp.window.float({ action = "unset", window = window }))
    end
  end
end)

----------------
---- apps ------
----------------

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("chromium"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("chromium --profile-directory='Profile 4'"))
hl.bind("SUPER + ALT + RETURN", hl.dsp.exec_cmd("ghostty -e tmux new -A -s main"))
hl.bind("SUPER + CTRL + RETURN", hl.dsp.exec_cmd("herdr"))
hl.bind("SUPER + F", hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("ghostty -e nvim"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("ghostty -e btop"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("vesktop"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("steam"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("fuzzel"))

-------------------
---- capture ------
-------------------

hl.bind("PRINT", hl.dsp.exec_cmd(shot .. " region"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(shot .. " output"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd(record))

-------------------
---- system ------
-------------------

hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd(power))
