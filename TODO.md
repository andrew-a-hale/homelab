# TODO

## Home Lab

- [ ] Setup a daily task to check if all the systems are working
  - [ ] Make a skill that documents the list of things to check and probably an uptime tool with logging

- [ ] Verify nginx.conf for jellyfin and qBittorrent on **Ralph** and commit the topology to the repo for simple bootstrap. This includes the hostname files for each of Tom, Jason, Rose, and Ralph.
  - Note: the intermittent 502 completed task. Ralph's nginx + tunnel config now live in `docs/ralph/nginx-ralph.conf`, `docs/ralph/cloudflared-config.yaml`, `docs/ralph/cloudflared.service`.

- [ ] Ensure this homelab is simple to bootstrap

- [ ] Finish the repo rename (`tom` → `homelab`, done 2026-11-07 for GitHub, this laptop and Tom): Jason still has `~/projects/tom`, and it is only reachable via the runner. Also `scripts/vpn-soak` points at `~/projects/homelab/scripts/vpn` on Jason.

- [ ] Tailnet auth on headless boxes (console-only, no CLI): disable node key expiry for `ralph` and `tom` (currently 2027-05-06 and 2027-01-14), and set the ACL `ssh` rule to `action: "accept"` so the 12-hourly check prompt stops (docs/vpn/complete/tailnet-key-expiry-2026-11-07.md)

- [ ] Ralph (OptiPlex 7070, new always-on server) — Arch + LUKS/TPM2 + Guix installed, Jellyfin + 58G media migrated, see [docs/ralph/](docs/ralph/). Remaining:
  - [x] Cloudflare tunnel on Ralph, website + Jellyfin served from Ralph (docs/ralph/complete/public-ingress-2026-11-07.md)
  - [x] Play-test Jellyfin on Ralph (Kokuho, 2026-11-07), then stop Jellyfin on Tom
  - [x] Petcam is a standalone app on Tom (tailnet bind), Ralph nginx is its only ingress; Tom runs no web server (docs/petcam/complete/standalone-app-2026-11-07.md)
  - [ ] Pin the IP (DHCP reservation on the router, currently .26)
  - [ ] Host firewall on Ralph
  - [ ] Secure Boot with own keys (`sbctl`) so the TPM2 PCR 7 seal means something
  - [ ] Intel AMT for out-of-band console (LUKS-prompt failures need a keyboard)
  - [x] Secrets are not backed up by design; `RUNBOOK.md` covers regenerating the stack and every secret (media is the one no-second-copy item)

- [ ] Change qBittorrent login to tom/pancake

- [ ] Fix Tom restarts — **wifi cause eliminated, restarts still unexplained**. Scan wedge fixed (iwd backend since 2026-10-29: 0 `SCAN-FAILED` every boot, `wifi-guard` silent since 10-28 18:18 — docs/server/complete/wifi-scan-wedge-2026-10-31.md), but Tom still hard-resets ~hourly (19 boots on 2026-10-31, gaps 77 s–2.5 h) — watchdog reset with no shutdown message, `rcu_preempt` stall on CPU 3 (never any other core) in ~⅓ of boots, silent otherwise. Capture is live since 2026-10-31 (ramoops/pstore + `panic=15` + `panic_on_rcu_stall`, `scripts/tom-trace.sh`); bootloader updated to 2026-09-25. Next: read the first pstore dump — archived automatically to /var/lib/systemd/pstore/ — and compare `/var/log/tom-trace.log` against the crash gap. Still open: PSU/cable check (owner, physical) and the SD card as suspect (docs/server/todo/tom-reboots-hang-2026-10-31.md)

- [ ] Simplify the homelab now that Tom is no longer load bearing (petcam needs only ~90% uptime)

## Purchases

- [ ] Google TV Streamer or Nvidia Shield
- [ ] Ethernet Powerline for TV
- [ ] Smart blub + Lamp: https://www.smarthome.com.au/product/shelly-multicolor-wi-fi-bulb-gen3-e27/

## Trades

- [ ] Electrician: move the internet port + Power and Ethernet

