-- What starts with the session that systemd cannot start for us.
--
-- waybar, hyprpaper and hypridle are NOT here: they ship their own user units,
-- and a unit started on `graphical-session.target` is the only thing that works
-- reliably. Executing them from this file runs before uwsm has exported
-- `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` into the activation
-- environment, so every GUI client exits instantly on boot (this is what left
-- the first Omarchy-free boot with no bar). Enable them with:
--   systemctl --user enable --now waybar hyprpaper hypridle
--
-- What is left below has no unit of its own and survives the missing Wayland
-- variables: fcitx5 retries, udiskie does not need Wayland at all.

-- Let portals, secrets and the keyring see the session environment.
hl.exec_cmd("dbus-update-activation-environment --systemd --all")

-- Japanese input. fcitx5 ships no systemd user unit (Omarchy's went with it).
hl.exec_cmd("pgrep -x fcitx5 >/dev/null || fcitx5 -d --replace")

-- USB sticks: automount, no tray icon (waybar has no tray module here).
hl.exec_cmd("pgrep -x udiskie >/dev/null || udiskie --automount --no-notify --no-tray")
