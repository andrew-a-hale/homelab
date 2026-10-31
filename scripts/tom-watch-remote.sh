#!/bin/bash
# jason-side watcher: an independent view of whether Tom is reachable.
#
# Runs on jason, not Tom, so it can see a reset that Tom's own loggers cannot —
# if the board dies, its own trace/kmsg files stop mid-sentence and say nothing
# about how long it was gone. This records the UP/DOWN transitions with wall
# timestamps, which is what turns "Tom rebooted" into "Tom was unreachable for
# 18 seconds at 07:07:42".
#
# Logs transitions only, so the file stays tiny. One line per state change.
#
#   ./tom-watch-remote.sh [host]
#   nohup ./tom-watch-remote.sh >/dev/null 2>&1 & echo $! > /tmp/tom-watch.pid
#
# Stop it by PID from the pidfile, never by pattern — see the wifi-guard
# deployment notes for why pattern-matching a kill over ssh is a trap.

set -u
HOST=${1:-192.168.1.24}
OUT=${TOM_WATCH_LOG:-/tmp/tom-watch.log}
INTERVAL=${TOM_WATCH_INTERVAL:-5}

state=""

while :; do
  if ping -c1 -W1 "$HOST" >/dev/null 2>&1; then now=UP; else now=DOWN; fi
  if [ "$now" != "$state" ]; then
    printf '%s %s %s\n' "$(date -Is)" "$now" "$HOST" >> "$OUT"
    state="$now"
  fi
  sleep "$INTERVAL"
done
