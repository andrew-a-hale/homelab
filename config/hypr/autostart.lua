-- What starts with the session. Everything here must be a long-lived daemon; a
-- one-shot belongs in a systemd unit instead.

-- Let portals, secrets and the keyring see the session environment.
hl.exec_cmd("dbus-update-activation-environment --systemd --all")

hl.exec_cmd("waybar")
hl.exec_cmd("hyprpaper")

-- Japanese input. fcitx5 ships no systemd user unit, and the Omarchy one goes
-- away with Omarchy.
hl.exec_cmd("fcitx5 -d --replace")

-- USB sticks: automount, no tray icon (waybar has no tray module here).
hl.exec_cmd("udiskie --automount --no-notify --no-tray")

-- Idle handling: lock, then display off. See hypridle.conf.
hl.exec_cmd("hypridle")
