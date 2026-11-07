#!/bin/sh
# Keep cloudflared's egress on the bare ISP when Proton VPN is up.
# Tom does the same thing (see docs/petcam/complete/petcam-502-vpn-bypass-2026-10-23.md);
# the VPN's policy routing sends everything else through proton0.
set -u
UID_N=$(id -u cloudflared)
ip rule add uidrange "$UID_N-$UID_N" lookup main priority 100 2>/dev/null || true
ip -6 rule add uidrange "$UID_N-$UID_N" lookup main priority 100 2>/dev/null || true
exit 0
