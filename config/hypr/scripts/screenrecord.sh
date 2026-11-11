#!/bin/sh
# Screen recording toggle (ALT + PRINT). gpu-screen-recorder finishes and writes
# its file on SIGINT, so the same script starts and stops it.
set -eu

dir="$HOME/Videos/recordings"
mkdir -p "$dir"

if pgrep -x gpu-screen-recorder >/dev/null 2>&1; then
  pkill -INT -x gpu-screen-recorder
  exit 0
fi

# -c mp4, screen capture at 60 fps, audio from the default output monitor.
# ponytail: whole screen only; add -w region with a slurp geometry if a
# window/region recorder is ever needed.
exec gpu-screen-recorder -w screen -f 60 -a "default_output" -c mp4 \
  -o "$dir/$(date +%F_%H-%M-%S).mp4"
