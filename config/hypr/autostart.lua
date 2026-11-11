-- What starts with the session. Everything here must be a long-lived daemon; a
-- one-shot belongs in a systemd unit instead.
--
-- Each line is guarded with pgrep because this file runs again on every
-- `hyprctl reload`: Hyprland's Lua API has no exec-once, so without the guard a
-- reload leaves you with a second waybar, hypridle and udiskie.

-- Let portals, secrets and the keyring see the session environment.
hl.exec_cmd("dbus-update-activation-environment --systemd --all")

hl.exec_cmd("pgrep -x waybar >/dev/null || waybar")
hl.exec_cmd("pgrep -x hyprpaper >/dev/null || hyprpaper")

-- Japanese input. fcitx5 ships no systemd user unit, and the Omarchy one goes
-- away with Omarchy.
hl.exec_cmd("pgrep -x fcitx5 >/dev/null || fcitx5 -d --replace")

-- USB sticks: automount, no tray icon (waybar has no tray module here).
hl.exec_cmd("pgrep -x udiskie >/dev/null || udiskie --automount --no-notify --no-tray")

-- Idle handling: lock, then display off. See hypridle.conf.
hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle")
