#!/bin/sh
# Read a USB-serial DHT sensor and publish it as the JSON the website fetches.
# Device emits lines like: 28.4 C 35.7 %   at 115200 baud.
# Output matches the shape the Go site served from Tom's GPIO:
#   {"temp":31.2,"humidity":27.0, "date":"Sat Nov  7 04:39:00 2026"}
set -eu

DEV=${DEV:-/dev/ttyUSB0}
OUT=${OUT:-/srv/dht/dht.json}
BAUD=${BAUD:-115200}

mkdir -p "$(dirname "$OUT")"
stty -F "$DEV" "$BAUD" raw -echo
export LANG=C

# ponytail: no buffering tricks, one line in one line out; the file is replaced
# atomically so nginx never serves a half-written JSON.
while read -r temp _ humid _; do
    [ -n "${temp:-}" ] && [ -n "${humid:-}" ] || continue
    printf '{"temp":%s,"humidity":%s,"date":"%s"}\n' \
        "$temp" "$humid" "$(date)" > "$OUT.tmp"
    mv "$OUT.tmp" "$OUT"
done < "$DEV"
