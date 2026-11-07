#!/bin/sh
# Keep the Proton WireGuard tunnel (interface proton0) up.
# qBittorrent binds proton0 and fails closed, so when this is down torrents
# stall instead of leaking — that is the leak protection, same as Tom.
# (Tom used `protonvpn connect` from cron; the CLI needs a Secret Service keyring
# that a headless box does not have, so Ralph uses Proton's WireGuard config.)
set -u
if ip link show proton0 >/dev/null 2>&1; then
    exit 0
fi
/usr/bin/wg-quick up proton0 >/dev/null 2>&1 || true
i=0
while [ "$i" -lt 15 ]; do
    ip link show proton0 >/dev/null 2>&1 && exit 0
    i=$((i+1)); sleep 2
done
echo "proton0 did not come up" >&2
exit 1
