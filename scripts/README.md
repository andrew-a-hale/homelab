# scripts/

What each script is, and where it actually runs. A script belongs here only if it
is deployed somewhere, is the documented rebuild path, or is a diagnostic for an
open problem — that is the test applied on 2026-11-11, when two dead ones went.

| Script | Runs on | Deployed as | Purpose |
|---|---|---|---|
| `homelab-health.sh` | Jason | user timer `homelab-health.timer`, 08:00 | daily check of Tom, Ralph and public ingress |
| `petcam.sh` | Tom | service | pet cam supervisor: capture + detector loop |
| `petcam-detect.py` | Tom | service | YOLO detector, movement-gated stills |
| `petcam-jev.py` | Jason | manual | Jev classifier over detection stills |
| `petcam-metrics.py` | Tom | cron | detection metrics |
| `train-model.sh` | Jason | manual (`petcam-retrain` skill) | fine-tune the detector, gate the result |
| `dht-writer.sh` | Ralph | `dht` service | USB DHT sensor → `/srv/dht/dht.json` |
| `dht/` (C + Makefile + service + Arduino firmware) | Ralph | `dht` service | the sensor daemon itself |
| `nzb-dl.sh` | Ralph | manual / skill | search NZBGeek, queue in NZBGet |
| `nzb-tidy.sh` | Ralph | cron | re-file finished downloads into Jellyfin's library |
| `proton-guard.sh` | Ralph | `proton-guard.timer`, 5 min | re-raise `proton0` if the WG tunnel drops |
| `wifi-guard.sh` | Tom | cron | recover Tom's brcmfmac when it stops passing traffic |
| `vpn` | Jason | manual | Proton VPN mode switcher (`any` / `safe` / `off` / `status`) |
| `ralph-arch-install.sh` | live ISO | manual | the Ralph rebuild, start to finish |
| `ralph-finish.sh` | live ISO | manual | re-runs the tail if the install stops partway |
| `tom-kmsg.sh` | Tom | root cron, `@reboot` | continuous `dmesg` tee so a silent freeze keeps its last seconds |
| `pacman-atime-audit.sh` | Jason | manual | which explicit packages never ran — evidence for pruning |

Deleted 2026-11-11 as spent, both recoverable from git history:

- `protonvpn-wrapper.sh` — worked around the Proton CLI needing a session D-Bus on
  headless boxes. Unreferenced; Ralph uses WireGuard (`proton-guard.sh`) and Jason
  has a real session.
- `vpn-soak` — mode-cycling soak harness that produced the VPN measurements. Its
  output lives in `docs/vpn/complete/`; nothing reads it any more.
- `tom-watch-remote.sh`, `tom-trace.sh` — the outside-in and SD/wlan0 samplers from
  the Tom freeze investigation. Not required; `tom-kmsg.sh` and ramoops cover it.
- `cloudflared-bypass.sh` — kept cloudflared's traffic off the VPN route. Tom runs
  **no** cloudflared (no unit, no process); the only tunnel in the house is Ralph's.

Retired but deliberately still in the repo: `ralph-arch-install.sh` and
`ralph-finish.sh` — the bootstrap must stay cheap ([AGENTS.md](../AGENTS.md)), and
they are what `RUNBOOK.md` tells you to run.
