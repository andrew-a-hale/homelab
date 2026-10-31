# Tom: brcmfmac scan wedge — closed (the reboots were a different fault)

**Date:** 2026-10-31
**Status:** closed for the scan wedge; the reboots it was blamed for are still open
and now tracked in [`../todo/tom-reboots-hang-2026-10-31.md`](../todo/tom-reboots-hang-2026-10-31.md).

Follow-up to
[`wifi-scan-storm-watchdog-2026-10-27.md`](wifi-scan-storm-watchdog-2026-10-27.md)
and [`iwd-wifi-backend-migration-2026-10-29.md`](iwd-wifi-backend-migration-2026-10-29.md).
This file replaces the former `docs/server/todo/wifi-scan-wedge-2026-10-27.md`.

## Decision

**The brcmfmac scan wedge is fixed. It was not, on its own, the cause of Tom's
restarts.** The iwd migration removed the scan storm, and the scan storm has not
come back in two days and ~30 boots — but Tom kept restarting, and at a *higher*
rate than before. The reboot cause therefore has to be treated as a separate,
still-unidentified hard hang.

This closes the wifi ticket and reopens the reboot problem as its own brief.
Do not re-open the scan-wedge work on the strength of a restart: restart
frequency no longer tracks anything the scan engine does.

## Evidence (measured on Tom, 2026-10-31 ~18:15 AEST)

Boots recorded in the persistent journal (2.4 GB, back to 2026-10-26 21:25):

| Day | Boots |
| --- | --- |
| 2026-10-26 | 2 |
| 2026-10-27 | 10 |
| 2026-10-28 | 13 |
| 2026-10-29 | 12 |
| 2026-10-30 | 8 |
| 2026-10-31 (to 18:17) | 19 |

64 boots total. On 2026-10-31 the gap between restarts ranged from 77 seconds
to ~2.5 h, i.e. a mean of roughly one per hour and a worst case of back-to-back.
That is worse than the 1–1.5 h cadence the wedge produced on 2026-10-28.

Scan failures, per boot (`journalctl -b N -o cat | grep -c SCAN-FAILED`):

- **0 on every boot from `-31` through `-0`**, the single exception being `-30`
  with 4.
- 64,918 `SCAN-FAILED` lines exist in total, all of them dated 2026-10-26..28.
  The count collapses to zero at the iwd migration and never returns.

`journalctl -t wifi-guard`: 16 `reloading brcmfmac` firings, all on 2026-10-27
and 2026-10-28. **The last firing was 2026-10-28 18:18:02.** Nothing since.
The guard's trigger (`≥30 SCAN-FAILED` in 2 min) no longer exists under iwd, so
the guard is inert, not broken. It is left installed as a cheap safety net in
case the Wi-Fi backend is ever moved back to wpa_supplicant.

## Flap-limit item: condition never met, and now moot

The old ticket said to add a `≥3 reloads in 30 min → reboot` escalation *only if
`journalctl -t wifi-guard` showed the pattern*. It does not:

- 2026-10-28 16:30 and 16:32 — 2 reloads
- 2026-10-28 17:50 and 17:52 — 2 reloads
- everything else: single reloads

Never 3 in 30 minutes. **No escalation was built**, which is the right call: the
pattern never appeared, and the trigger that fed it is gone.

## What this does *not* claim

- It does not claim Tom is stable. It is not; see the new brief.
- It does not prove the `brcmf_proto_bcdc_msg failed w/status -110` SDIO path is
  healthy — only that it is no longer being driven by a scan storm. Only 7 such
  lines exist in the whole journal, none on 2026-10-30/31.
- It does not close the PSU check, the bootloader update, or upstream tracking.
  Those carried over into the new brief.

## Ceilings still accepted

- No ethernet on Tom and none in use, so wifi is the only uplink: any recovery
  path must keep the board reachable, hence reboot fallbacks rather than
  "leave it down and wait".
- Wi-Fi is the only uplink again (Ethernet unplugged by choice). `ssh tom-wired`
  on jason reaches 192.168.1.23 if a cable is ever plugged in — and if so, add
  `.23` to jason's NFS export.
