# TODO

## Home Lab

- [ ] Investigate usenet instead of torrents

- [x] Setup a daily task to check if all the systems are working (timer on Jason, 08:00 daily)
  - [x] Make a skill that documents the list of things to check and probably an uptime tool with logging
    — `scripts/homelab-health.sh` (one run = one line in `~/homelab-health.log`, the uptime
    history) + `skills/homelab-health/SKILL.md`; `homelab-health.timer` (systemd **user** timer on
    Jason, `OnCalendar=*-*-* 08:00:00`, `Persistent=true`, `--quiet`). Not on Ralph on purpose: the
    script ssh's both hosts and `ssh ralph` from Ralph fails host-key verification.

- [x] Verify nginx.conf for jellyfin and qBittorrent on **Ralph** and commit the topology to the repo for simple bootstrap. This includes the hostname files for each of Tom, Jason, Rose, and Ralph.
  - Note: the intermittent 502 completed task. Ralph's nginx + tunnel config now live in `docs/ralph/nginx-ralph.conf`, `docs/ralph/cloudflared-config.yaml`, `docs/ralph/cloudflared.service`.

- [ ] Ensure this homelab is simple to bootstrap
  - Audit done: `docs/server/todo/runbook-bootstrap-audit-2026-11-08.md` lists what the RUNBOOK
    gets wrong or leaves out. Fixed since: the `/bt/` block missing from the committed nginx conf,
    the phantom `docs/ralph/petcam.conf`, Tom's petcam section (capture-only now), and Tom's
    leftover `andrewahale-web.service` (disabled 2026-11-08). Still open: the Ralph install
    procedure (partitions/LUKS/TPM/btrfs only live in `scripts/ralph-arch-install.sh`),
    `proton-guard.{service,timer}` exist only on the box, and `wg-quick@proton0` never actually
    starts (the guard raises `proton0`).

- [x] Finish the repo rename (`tom` → `homelab`) — verified 2026-11-08: no `~/projects/tom` on
  Jason, Tom clones `andrew-a-hale/homelab` at `~/projects/homelab`, `scripts/vpn-soak`'s
  `$HOME/projects/homelab/scripts/vpn` resolves.

- [ ] Tailnet auth on headless boxes (console-only, no CLI): disable node key expiry for `ralph` and `tom` (currently 2027-05-06 and 2027-01-14), and set the ACL `ssh` rule to `action: "accept"` so the 12-hourly check prompt stops (docs/vpn/complete/tailnet-key-expiry-2026-11-07.md)
  - Blocked on a human: there is no Tailscale API key on any box and no browser session to the admin
    console, so it needs either a login at `login.tailscale.com/admin/machines` (two ⋯ → Disable key
    expiry, plus the ACL edit) or `pass insert tailscale/api` with a key that has device + ACL scope,
    after which it is two API calls.

- [ ] Ralph (OptiPlex 7070, new always-on server) — Arch + LUKS/TPM2 + Guix installed, Jellyfin + 58G media migrated, see [docs/ralph/](docs/ralph/). Remaining:
  - [x] Cloudflare tunnel on Ralph, website + Jellyfin served from Ralph (docs/ralph/complete/public-ingress-2026-11-07.md)
  - [x] Play-test Jellyfin on Ralph (Kokuho, 2026-11-07), then stop Jellyfin on Tom
  - [x] Petcam is a standalone app on Tom (tailnet bind), Ralph nginx is its only ingress; Tom runs no web server (docs/petcam/complete/standalone-app-2026-11-07.md)
  - [x] Petcam split: Tom is a camera appliance (capture + a tailnet-only static server on :8081), detector + app (`127.0.0.1:8082`) + all state on Ralph (docs/petcam/complete/tom-camera-appliance-2026-11-08.md)
  - [x] Pin the IP (DHCP reservation on the router: .26 -> 8C:C6:81:A2:7A:38, done 2026-11-07)
  - [x] Host firewall on Ralph (ufw: LAN + tailnet trusted, tailscale UDP, no WAN inbound, 2026-11-07)
  - [x] Secrets are not backed up by design; `RUNBOOK.md` covers regenerating the stack and every secret (media is the one no-second-copy item)

- [x] qBittorrent login is `andy`/`pancake` (nginx basic auth on `/bt/`; qBit lives on Ralph only — Tom's copy is retired)

- [ ] Fix Tom restarts — **cause identified 2026-11-08, not fixed** (Tom is no longer load bearing: petcam needs only ~90% uptime). The first pstore dump proves a CPU 3 hard lockup downstream of the imx708 failing I²C writes on the RP1 bus: nothing logged for 148 s, CPU 3 never answers the NMI backtrace, then `i2c_designware … controller timed out` / `Failed to write reg 0x0342 error = -5` / `start_streaming failed`, then our own `panic_on_rcu_stall=1` panics the box. Silently wedged before that (wifi and the SCAN-FAILED scan wedge are ruled out — 0 occurrences since iwd, docs/server/complete/wifi-scan-wedge-2026-10-31.md). Still ~12 resets/day (87 boots in 7 days). Remaining steps are physical: reseat the CSI ribbon, then replace it, then the module — or switch to a USB UVC webcam, which takes RP1 I²C out of the path. Keep `panic_on_rcu_stall=1` (it produces the dump). Details in docs/server/todo/tom-reboots-hang-2026-10-31.md

- [ ] Simplify the homelab now that Tom is no longer load bearing (petcam needs only ~90% uptime)
  - [x] Make Tom a camera appliance: only `rpicam-vid`/`ffmpeg` + `petcam-static` stay, detector + app + state moved to Ralph (docs/petcam/complete/tom-camera-appliance-2026-11-08.md)

## Purchases

- [ ] Google TV Streamer or Nvidia Shield
- [ ] Ethernet Powerline for TV
- [ ] Smart blub + Lamp: https://www.smarthome.com.au/product/shelly-multicolor-wi-fi-bulb-gen3-e27/

## Trades

- [ ] Electrician: move the internet port + Power and Ethernet

