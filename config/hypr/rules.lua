-- Window rules. Two things only: don't blank the screen under a video, and
-- leave Steam's own windows alone.

-- Don't start the locker/idle while a browser window is focused (YouTube etc.).
hl.window_rule({ match = { class = "((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium)" }, idle_inhibit = "focus" })
hl.window_rule({ match = { class = "([fF]irefox|zen|librewolf)" }, idle_inhibit = "focus" })

-- Steam's friend list and chat are utility windows, not tiles.
hl.window_rule({ match = { class = "steam", title = "(Friends List|Steam Chat)" }, float = true })
