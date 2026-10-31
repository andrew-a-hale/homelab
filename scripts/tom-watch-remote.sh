#!/bin/bash
# jason-side watcher: an independent view of whether Tom is reachable.
#
# Runs on jason, not Tom, so it can see a reset that Tom's own loggers cannot —
# if the board dies, its own trace/kmsg files stop mid-sentence and say nothing
# about how long it was gone. This records the UP/DOWN transitions with wall
# timestamps, which is what turns "Tom rebooted" into "Tom was unreachable for
# 18 seconds at 07:07:42".
#
# Logs every state change, plus a HEARTBEAT line every HEARTBEAT seconds. The
# heartbeat exists so "is the last line recent?" is a valid liveness test: with
# transitions only, a perfectly healthy watcher can sit silent for hours, and a
# recency check would then cry wolf exactly the way a stale check label does.
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
HEARTBEAT=${TOM_WATCH_HEARTBEAT:-600}

state=""
last_beat=0

while :; do
  if ping -c1 -W1 "$HOST" >/dev/null 2>&1; then now=UP; else now=DOWN; fi
  ts_now=$(date +%s)
  if [ "$now" != "$state" ]; then
    printf '%s %s %s\n' "$(date -Is)" "$now" "$HOST" >> "$OUT"
    state="$now"
    last_beat=$ts_now
  elif [ $((ts_now - last_beat)) -ge "$HEARTBEAT" ]; then
    printf '%s HEARTBEAT %s %s\n' "$(date -Is)" "$now" "$HOST" >> "$OUT"
    last_beat=$ts_now
  fi
  sleep "$INTERVAL"
done
