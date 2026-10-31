# Tom Wi-Fi moved to iwd backend (brcmfmac scan-wedge trigger removed)

**Date:** 2026-10-29 (evening, same day as the outage doc)
**Status:** done, verified — reboot-tested with Wi-Fi-only boot, all services up.

Supersedes the "iwd abandoned" conclusion in
[`iwd-outage-and-wired-ethernet-2026-10-29.md`](iwd-outage-and-wired-ethernet-2026-10-29.md):
the user chose to resolve the Wi-Fi wedge properly via iwd and removed the
Ethernet cable again. This time the migration was done with a fallback path
(Ethernet plugged during the switch) and it works.

## Why iwd

NetworkManager's wpa_supplicant path drives roaming bgscans (~5 min after every
connect) that hit the brcmfmac firmware scan wedge
([`wifi-scan-storm-watchdog-2026-10-27.md`](wifi-scan-storm-watchdog-2026-10-27.md)),
wedge → SDIO hang → hard reboot every 1–1.5 h. iwd does not bgscan that way;
since the migration the journal shows **0** `SCAN-FAILED`/`Scanning suppressed`
lines.

## What the first (failed) attempt got wrong — checklist for future backend work

1. **`wifi.backend=iwd` belongs in `[device]`, not `[main]`.** NM logged
   `config: unknown key 'wifi.backend' in section [main]` and silently kept
   using wpa_supplicant.
2. **`iwd` must be enabled at boot** (`systemctl enable --now iwd`), else the
   backend has no daemon at boot and wlan0 never comes up.
3. **`mask` ≠ `stop`** — a running wpa_supplicant survives masking and fights
   iwd for the radio. Stop it too.
4. **iwd needs the network known.** NM's activation called iwd
   `Network.Connect` on an unknown network → provisioning agent dance →
   `GDBus.Error:net.connman.iwd.Aborted` → NM `need-auth (no-secrets)` loop on
   a headless box with no secret agent. Fix: native iwd network file
   `/var/lib/iwd/Dlink-9C045E.psk` with `Passphrase=` + `AutoConnect=true`.
   The NM profile (`Dlink-9C045E`) still owns L3/DHCP and activates fine.
5. **Never hot-switch the Wi-Fi backend remotely on a Wi-Fi-only Tom.** Keep a
   wired path plugged until the new backend has survived a reboot.

## Final state

- `/etc/NetworkManager/conf.d/wifi-backend.conf`: `[device] wifi.backend=iwd`
- `iwd.service` enabled + running; `wpa_supplicant` masked and stopped
- `/var/lib/iwd/Dlink-9C045E.psk` (passphrase, AutoConnect) + NM profile
  `Dlink-9C045E` (wpa-psk, psk also in keyfile) — wlan0 gets 192.168.1.24
- `scripts/wifi-guard.sh` left in place but **inert under iwd**: its trigger is
  wpa_supplicant's `SCAN-FAILED` message which no longer exists. The wedge
  trigger (bgscan) is gone too. Keep it until the firmware bug is confirmed
  dead; it does nothing when there is no scan storm.
- Ethernet: unplugged again per user decision (wired remains the emergency
  fallback; `ssh tom-wired` alias on Jason points at 192.168.1.23).

## Verified

- Boot test (2026-10-29): reboot with Ethernet plugged → wlan0 up on iwd at
  boot, .24, VPN + cloudflared up. Then cable removed → SSH/Wi-Fi-only OK.
- Services `mnt-storage.mount`, `jellyfin`, `qbittorrent-nox@tom` started
  manually after cable removal and are active (they failed at earlier boots
  because the NFS mount was sourcing from eth0's .23 and jason's export only
  allows 192.168.1.24 — if Ethernet returns, add .23 to jason's `/etc/exports`).

## Follow-ups

- Watch the journal for a week: `journalctl -b -0 -o cat | grep -cE
  'SCAN-FAILED|Scanning suppressed'` should stay 0. If the wedge reappears via
  iwd's own scanning, revisit (wired, or firmware update).
- `docs/server/complete/wifi-scan-wedge-2026-10-31.md` closes the guard flap
  limit and upstream-tracking items. The "unexplained 2026-10-27 13:42 reboot"
  turned out to be the general hard-hang fault, not a separate one: see
  `docs/server/todo/tom-reboots-hang-2026-10-31.md`.
