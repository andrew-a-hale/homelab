# iwd backend attempt (rolled back) + Ethernet adopted

**Date:** 2026-10-29
**Symptom reported:** "am I stressing out the wifi on the pi?" — no. NetworkManager's
automatic roaming `bgscan simple:30:-65:300` fires its first scan ~5 min after every
connect, the brcmfmac firmware scan engine wedges exactly then (same bug as
[`wifi-scan-storm-watchdog-2026-10-27.md`](wifi-scan-storm-watchdog-2026-10-27.md)),
and the raw SDIO hang was hard-rebooting Tom every 1–1.5 h before wifi-guard's
2-minute cycle could catch it.

## What was tried and failed: switching NetworkManager to iwd

To stop the periodic bgscan trigger, NetworkManager's Wi-Fi backend was switched
to iwd (`/etc/NetworkManager/conf.d/wifi-backend.conf`, `wpa_supplicant` masked,
`apt install iwd`). **The switch was made live, over Wi-Fi, on a headless
Wi-Fi-only box.** Tom then went networkless and unrecoverable remotely:

- Router client list showed Tom associated (MAC `2c:cf:67:f1:4a:67`, .24, 5 GHz)
  but 100% ping loss even from the router (D-Link Diagnostics ping). The entry
  was a stale DHCP lease; the IP stack never came up. iwd never completed
  association + DHCP on first boot.
- `wifi-guard.sh` cannot help here: its reboot fallback assumes Wi-Fi comes back
  after boot, and the wedge it guards is a different layer (driver scan engine,
  not association).
- Recovery required physical access.

**Lesson (the decision):** never hot-switch the Wi-Fi backend (or any
link-layer config) on Tom remotely. Wi-Fi-only boxes need an in-person window or
a wired fallback first. This outage was self-inflicted; the brcmfmac wedge was
not.

## Recovery and what is in place now

1. Ethernet cable plugged into Tom's unused gigabit port (MAC `2c:cf:67:f1:4a:66`)
   → `eth0` up, DHCP lease **192.168.1.23** (`Wired connection 1` in NM).
2. iwd change reverted: `wifi-backend.conf` deleted, `wpa_supplicant` unmasked,
   NetworkManager restarted. Wi-Fi (`Dlink-9C045E:wlan0`) re-associated on
   .24, ProtonVPN restored by the existing 5-min vpn cron. iwd left installed
   but inactive.
3. Jason's `~/.ssh/config` now includes `192.168.1.23` in the `tom` host block.

## Decisions

- **Ethernet is now the primary uplink.** The brcmfmac scan wedge can no longer
  take down the website/petcam/VPN path — wifi-guard and the wedge become a
  secondary-path problem only.
- **iwd experiment abandoned** (at least until done in person, in a planned
  window). The wedge trigger analysis (NM `bgscan` poking the broken firmware)
  is still the likely mechanism, but the cure risk outweighs the disease now
  that wired exists.
  - **Superseded same day:** iwd was in fact adopted — see
    [`iwd-wifi-backend-migration-2026-10-29.md`](iwd-wifi-backend-migration-2026-10-29.md)
    (this attempt failed for mechanical reasons, not because iwd can't work).
- If the wifi wedge keeps hard-rebooting Tom on the secondary path, the next
  lazy step is disabling bgscan (iwd, in person) or simply letting wifi-guard
  keep resetting it — wired carries the load either way.

## Open follow-ups

- Give eth0 a stable address (DHCP reservation on the D-Link for
  `2c:cf:67:f1:4a:66`, or NM static config) so bootstrap scripts can pin one IP.
- Update bookmark: that ticket became `wifi-scan-wedge-2026-10-31.md` (closed)
  plus `../todo/tom-reboots-hang-2026-10-31.md` (the live fault). Wedge severity
  drops to "secondary path" now that Ethernet exists.
