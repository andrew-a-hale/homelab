#!/bin/bash
# Pre-crash activity sampler.
#
# Tom hard-freezes and gets reset by the systemd hardware watchdog with no
# shutdown message, so the journal always ends on whatever cron wrote last and
# tells us nothing about what was happening. This keeps a short ring buffer of
# the minutes before a freeze, so the next crash can be correlated against
# SD-card I/O and wlan0 traffic instead of guessed at.
#
# Counters are cumulative; what matters after a crash is the last line before
# the gap and whether I/O was outstanding around it. Writes one line every 15 s
# and self-trims to the newest half of MAX lines (2000 lines at 15 s is ~8 h of
# history, trimmed back to ~4 h), so the file stays small on the SD card.
#
# Cron (root): @reboot /home/tom/projects/tom/scripts/tom-trace.sh >/dev/null 2>&1 &
# See docs/server/todo/tom-reboots-hang-2026-10-31.md.

set -u
OUT=${TOM_TRACE_OUT:-/var/log/tom-trace.log}
MAX=${TOM_TRACE_MAX:-2000}
INTERVAL=${TOM_TRACE_INTERVAL:-15}

exec 9>"$OUT.lock"
flock -n 9 || exit 0

# /sys/block/<dev>/stat: reads reads_m sectors_read ms_reading writes writes_m
# sectors_written ms_writing ios_in_progress ms_io weighted_io
MMC=/sys/block/mmcblk0/stat
NET=/sys/class/net/wlan0/statistics

while :; do
  {
    printf '%s up=%s load=%s' "$(date -Is)" "$(cut -d. -f1 /proc/uptime)" \
      "$(cut -d' ' -f1-3 /proc/loadavg)"
    if [ -r "$MMC" ]; then
      # shellcheck disable=SC2046
      set -- $(cat "$MMC")
      printf ' mmc_rd=%s mmc_wr=%s mmc_io_ms=%s mmc_busy=%s' \
        "${1:-0}" "${5:-0}" "${10:-0}" "${9:-0}"
    fi
    if [ -r "$NET/rx_bytes" ]; then
      printf ' wl_rx=%s wl_tx=%s' "$(cat "$NET/rx_bytes")" "$(cat "$NET/tx_bytes")"
    fi
    if [ -r /proc/pressure/io ]; then
      printf ' psi_io=%s' "$(awk '/^some/{print $2}' /proc/pressure/io)"
    fi
    printf '\n'
  } >> "$OUT"

  if [ "$(wc -l < "$OUT")" -gt "$MAX" ]; then
    tail -n $((MAX / 2)) "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
  fi
  sleep "$INTERVAL"
done
