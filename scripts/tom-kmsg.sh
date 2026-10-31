#!/bin/bash
# Continuous kernel-log tee.
#
# Tom's failure mode is a hard freeze that the systemd watchdog resets, so the
# journal ends on whatever cron wrote last. journald flushes to disk only every
# SyncIntervalSec (5 s here) and it is the same sink as everything else, so the
# last few seconds of kernel output — the interesting ones — can be lost, and a
# stalled journald loses them all.
#
# This writes /dev/kmsg straight to a separate rolling file with its own
# microsecond ISO timestamp, independent of journald. scripts/tom-trace.sh gives
# a 15 s sampled view; this gives the kernel's own last words, sub-second, up to
# the moment of death.
#
# Rotation is copytruncate on purpose: the file is opened O_APPEND, so after
# truncation writes resume at the new EOF. Renaming the inode would leave dmesg
# writing to an unlinked file and silently lose everything.
#
# Cron (root): @reboot /home/tom/projects/tom/scripts/tom-kmsg.sh >/dev/null 2>&1 &
# See docs/server/todo/tom-reboots-hang-2026-10-31.md.

set -u
OUT=${TOM_KMSG_OUT:-/var/log/tom-kmsg.log}
MAX=${TOM_KMSG_MAX:-8000000}   # ~8 MB ~= 130 boots at ~60 KB each

exec 9>"$OUT.lock"
flock -n 9 || exit 0

# Firmware/SoC view of why the board came back. rsts is documented at
# /proc/device-tree/chosen/bootloader/rsts (big-endian binary). Treat it as a
# weak signal: upstream reports get_rsts=20 regardless of cause
# (raspberrypi/linux#1586) because `reboot` itself resets via the watchdog, and
# the firmware clears/rewrites the register. Cold power-on does show 0x1000,
# so it can at least separate a power loss from a SoC reset; otherwise compare
# the value across boots and let the pattern speak.
{
  printf '\n===== boot %s =====\n' "$(date -Is)"
  printf 'rsts_dt=%s rsts_vc=%s wdt_bootstatus=%s\n' \
    "$(xxd -p /proc/device-tree/chosen/bootloader/rsts 2>/dev/null | tr -d '\n' || echo '?')" \
    "$(vcgencmd get_rsts 2>/dev/null | cut -d= -f2 || echo '?')" \
    "$(cat /sys/class/watchdog/watchdog0/bootstatus 2>/dev/null || echo '?')"
  printf 'throttled=%s temp=%s bootloader=%s\n' \
    "$(vcgencmd get_throttled 2>/dev/null)" \
    "$(vcgencmd measure_temp 2>/dev/null)" \
    "$(vcgencmd bootloader_version 2>/dev/null | head -1)"
} >> "$OUT"

(
  while :; do
    sleep 60
    sz=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
    if [ "$sz" -gt "$MAX" ]; then
      cp -f "$OUT" "$OUT.1" 2>/dev/null || true
      : > "$OUT"
    fi
  done
) &

# dmesg -w should stream forever; if it ever exits, restart it rather than
# silently stopping the capture.
while :; do
  dmesg --time-format iso -w >> "$OUT" 2>/dev/null
  # Unconditional: `|| sleep 5` spins hot if dmesg ever exits 0. Each restart
  # re-dumps the ring buffer, so a tight loop would also rotate away the
  # pre-crash evidence.
  sleep 5
done
