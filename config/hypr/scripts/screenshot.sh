#!/bin/sh
# Still capture. Writes a PNG, then opens it in satty to annotate; satty saves
# over the same file and copies the annotation to the clipboard (wl-clipboard).
#   screenshot.sh region   -> pick an area with slurp (PRINT)
#   screenshot.sh output   -> the focused monitor (SHIFT + PRINT)
set -eu

dir="$HOME/Pictures/Screenshots"
mode="${1:-region}"
mkdir -p "$dir"
out="$dir/$(date +%F_%H-%M-%S).png"

case "$mode" in
  region)
    geometry="$(slurp)" || exit 0 # Esc in slurp = no screenshot
    grim -g "$geometry" "$out"
    ;;
  output)
    monitor="$(hyprctl monitors -j | python3 -c 'import json,sys; print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))')"
    grim -o "$monitor" "$out"
    ;;
  *)
    echo "usage: $0 [region|output]" >&2
    exit 2
    ;;
esac

exec satty --filename "$out"
