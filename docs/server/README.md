# Tom (Raspberry Pi 5)

The camera. Tom exists to hold the CSI camera and turn it into HLS segments and
1 fps stills; everything stateful lives on Ralph. Verified 2026-11-08.

**Rule of thumb: if it has a URL, a login, or state, it is not on Tom.**

## What runs here

| Piece | Unit / mechanism | Notes |
|---|---|---|
| `rpicam-vid` \| `ffmpeg` | cron, [`scripts/petcam.sh`](../../scripts/petcam.sh) | 720p@1 fps capture → 480p H.264 HLS + 1 fps stills in `/dev/shm/petcam` (tmpfs, ~4MB). Supervisor relaunches dead pipelines (60 s backoff on flap) |
| `petcam-static` | `petcam-static.service` | `python3 -m http.server 8081 --bind 100.77.132.110 --directory /dev/shm/petcam`. Not nginx, not the website — a tailnet-only file server so Ralph can fetch the stream and the still |
| `wifi-guard` | cron, `/usr/local/bin/wifi-guard.sh` every 2 min | inert since the iwd migration; fires only if `wlan0` loses its address and both its probes fail (`complete/iwd-wifi-backend-migration-2026-10-29.md`) |
| `tom-health` | cron, `logger -t tom-health` every 2 min | uptime, throttled bits, temp, EXT5V — the crash-investigation breadcrumb (`journalctl -t tom-health`) |

**Not here:** nginx, cloudflared, the Go site, Jellyfin, qBittorrent, the petcam
app, the detector, the model, all petcam state, Docker, ollama, the DHT daemon.
All of that is on Ralph (`../ralph/README.md`, `../petcam/README.md`).

There is **no firewall** (ufw is not installed) and, for now, the tailnet —
see `../security/todo/lan-trust-2026-11-08.md`, which owns both.

## Host

| | |
|---|---|
| OS | Debian 13 (trixie), kernel `6.18.50+rpt-rpi-2712` |
| Packages | `ffmpeg` (7.1.5), `python3` (3.13.5), `rpicam-apps` (1.14.0). Nothing else added |
| Uplink | wifi `wlan0`, `192.168.1.24` (DHCP reservation on the router) |
| Tailnet | `100.77.132.110`, `tom.tailad1015.ts.net`, advertises `192.168.1.0/24` |
| Access | SSH as `tom`, key-only (`PasswordAuthentication no`, `PermitRootLogin no`, `AllowUsers tom`); ufw active — tailnet any port, `22` from the LAN, `41641/udp`. Passwordless sudo only for `/usr/local/bin/wifi-guard.sh` |
| Gone | VNC (`:5900`), rpcbind (`:111`) — both disabled 2026-11-08 |

## SSH from Jason

`~/.ssh/config` must carry `IPQoS none` for `tom`: the default TOS marking gets
dropped by Jason's conntrack and direct SSH times out.

Names: **`tom` / `tom.tailad1015.ts.net` (MagicDNS) is the primary name
everywhere** — scripts, docs, ssh — because it is uplink-agnostic. `tom.local` is
a LAN convenience pinned in `/etc/hosts` **on Jason** to both LAN addresses
(`192.168.1.24` wifi, `192.168.1.23` the temporary wired cable), so it resolves
whichever is up. Do not hard-code a LAN address in a script.

## Supply chain

`unattended-upgrades` is installed and restricted to the Debian
`trixie-security` pocket, `Automatic-Reboot "false"`. Nothing else lands on its
own: `archive.raspberrypi.com` has no security pocket, so kernel,
`firmware-brcm80211` and `rpi-eeprom` are applied **by hand**, as are Docker,
Jellyfin, Tailscale and ProtonVPN packages (none of which are on Tom now).

## Known live fault

Random reboots, ~12/day: the imx708 stops answering I²C writes on its RP1 bus,
CPU 3 hard-locks, and `panic_on_rcu_stall=1` turns that into a panic + pstore
dump instead of a silent watchdog reset. Keep that sysctl armed — it is what
produces the evidence. Remaining fixes are physical: reseat the CSI ribbon,
replace it, replace the module, or switch to a USB UVC webcam.

Full evidence and fix order: [`todo/tom-reboots-hang-2026-10-31.md`](todo/tom-reboots-hang-2026-10-31.md).
Triage that still works:

```bash
journalctl -b -1 -o cat | grep -c 'rcu_preempt detected stalls'   # the live fault
journalctl -b -1 -o cat | grep -c SCAN-FAILED                     # expect 0 (wifi closed)
journalctl -t tom-health -n 40                                    # throttled / EXT5V / temp
```

## Monitoring

Not from Tom: `scripts/homelab-health.sh` runs on **Jason** daily at 08:00
(systemd user timer) and checks Tom, Ralph and the public ingress from outside,
appending one line to `~/homelab-health.log`.

## Rebuild

`RUNBOOK.md` (Tom section) is the cold-start order; `../petcam/README.md#rebuild`
has the detail. Ten minutes on a fresh SD card: `apt install ffmpeg`, clone this
repo, the capture cron lines from [`../petcam/crontab.txt`](../petcam/crontab.txt),
then `petcam-static.service`.

History: `complete/` — iwd migration and the wifi scan wedge (closed), crash
capture + bootloader, SSH/IPQoS, the health-check build, and the retired
"which server do I buy" analysis.
