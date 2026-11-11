-- Restored from pre-Quattro bindings.conf (old config was not auto-migrated).
-- SUPER+RETURN (terminal), SUPER+SHIFT+RETURN (browser) and SUPER+ALT+RETURN
-- (tmux) already exist in Omarchy defaults; only personal overrides below.

-- SUPER + SHIFT + D: Vesktop (replaced default Docker/lazydocker)
hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + D", "Vesktop", { launch = "vesktop" })

-- SUPER + S: Steam (replaced default scratchpad toggle)
hl.unbind("SUPER + S")
o.bind("SUPER + S", "Steam", { launch = "steam" })

-- Old layout: SUPER+F = files, SUPER+SHIFT+F = fullscreen (new defaults are swapped)
hl.unbind("SUPER + F")
hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + F", "File manager", { launch = "nautilus --new-window" })
o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- SUPER + B: default browser
o.bind("SUPER + B", "Browser", { omarchy = "browser" })

-- SUPER + SHIFT + B: chromium Profile 4 (replaced default browser)
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Browser", { launch = 'chromium --profile-directory="Profile 4"' })

-- SUPER + A: Activity (btop)
o.bind("SUPER + A", "Activity", { tui = "btop", focus = true })

