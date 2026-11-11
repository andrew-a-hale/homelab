#!/bin/sh
# Power menu (SUPER + ESCAPE): fuzzel dmenu, no shell required.
set -eu

choice="$(printf '%s\n' lock logout reboot shutdown |
  fuzzel --dmenu --prompt 'power > ' --lines 4)" || exit 0

case "$choice" in
  lock) hyprlock ;;
  logout) hyprctl dispatch exit ;;
  reboot) systemctl reboot ;;
  shutdown) systemctl poweroff ;;
esac
