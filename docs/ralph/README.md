# Ralph

The always-on server. Dell OptiPlex 7070 Micro (i5-9500T, 16GB, 256GB NVMe),
headless, reached over SSH and nothing else. Arch base + Guix for packages.


## Shape

| Layer | What | Why |
|---|---|---|
| Base OS | Arch, `linux-lts` | boring kernel, pacman only for the substrate |
| Packages | Guix (1.5.0, daemon as systemd service) | declarative, rollback-able, per-user generations |
| Disk | LUKS2 → btrfs subvols `@ @home @log @pkg @snapshots` | snapshots before updates |
| Boot | systemd-boot, ESP at `/boot`, TPM2 PCR 7 auto-unlock | encrypted but still boots unattended |
| Network | iwd + systemd-networkd, DHCP, wifi | wired when available (see below) |
| Ingress | nginx :80 + cloudflared (systemd) | the only public entry point in the house |
| Media | 3.6T ext4 USB at `/srv/media`, Jellyfin 12.4 | episode/movie library, group `jellyfin` |
| Sensors | USB DHT on `/dev/ttyUSB0` → `/srv/dht/dht.json` | published at `/static/dht.json` |
| Access | SSH key-only, `andy` in wheel, NOPASSWD sudo, **tailnet only** (LAN `:22` firewalled) | no password auth, no root login |

## Facts worth remembering

- **IP:** `192.168.1.26` (DHCP reservation on the D-Link, by MAC). Tailnet:
  `ralph` = `100.108.202.106`.
- **What runs here (all enabled, `Restart=always` where relevant):**
  `andrewhale-web`, `nginx`, `cloudflared`, `jellyfin`, `dht`, `petcam`,
  `petcam-detect`, `qbittorrent-nox@qbittorrent`, `fail2ban`, `sshd`,
  `guix-daemon`, `tailscaled`, `wg-quick@proton0`.
- **Firewall:** ufw, per service — `22`, `80`, `8096` on the tailnet; `80` and
  `8096` from the LAN; `41641/udp`. LAN `:22` is closed, so admin SSH is
  tailnet-only (`sudo ufw status verbose`).
- **The other two boxes:** Tom captures video only (`../server/README.md`);
  Jason is the desktop that trains the petcam model and runs the health check.
  Ralph is the only always-on host and the only Cloudflare tunnel in the house.

## Petcam here

| Piece | Unit | Address |
|---|---|---|
| gallery app | `petcam.service` (User=andy) | `127.0.0.1:8082` — **not 8080**, that is `andrewhale-web` |
| detector | `petcam-detect.service` (`Restart=always`, no cron on this box) | pulls the still from `100.77.132.110:8081/frames/latest.jpg`, 5 s timeout |
| state | — | `~/petcam/` (shots, tolabel, training, model, detections.log) |
| nginx | `/etc/nginx/conf.d/petcam.conf` | `/hls/` → `100.77.132.110:8081/`; rest → `127.0.0.1:8082` |

nginx adds `Cache-Control: no-store` on `/hls/` because Tom's `http.server`
can't send it and hls.js refetches the playlist. The browser pulls the stream
straight from Tom over the tailnet — this box only proxies it, so a Tom outage
kills `/live` (502 in ~17 ms) while the gallery keeps working, and a wedged
socket on Tom makes the detector skip a pass rather than hang.

Ralph→Tom is HTTP only: the tailnet SSH ACL refuses `andy@tom` and tailnet names
do not resolve here (`getent hosts tom.tailad1015.ts.net` hangs, there is no
`dig`), so anything scripted uses the IP `100.77.132.110`.

## Disk, boot, console

- **LUKS keyslot 0** is the passphrase; **slot 1** is the TPM2 token. If firmware
  settings change, PCR 7 changes, the token stops working and Ralph waits for a
  passphrase at the console. Re-enrol:
  `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2`.
- **Unattended reboot works:** power cycle → SSH in 26 s, nobody at the console
  (proven 2026-11-07; re-prove after any boot-chain change).
- **Secure Boot is off on purpose**, so PCR 7 measures little: the TPM protects
  against drive removal, not against booting a USB stick on the box. Own keys via
  `sbctl` only harden the auto-unlock seal against a targeted evil maid, and LUKS
  alone already covers opportunistic theft. Same class of non-goal as Intel AMT
  (the i5-9500T is vPro-capable; skipped, it is a remote console for a box within
  arm's reach). See `RUNBOOK.md` → *Deliberate non-goals*.
- **No swap.** 15GB RAM, nothing hibernates.

## Install

`scripts/ralph-arch-install.sh` is the whole install, guarded against wiping the
wrong disk, and `scripts/ralph-finish.sh` re-runs the tail if it stops partway.
Read them before running; they wipe `/dev/nvme0n1`.

## Constraints and open questions

- qBittorrent is the **only** thing behind Proton WireGuard (`proton0`,
  `Table=off`, one uid rule), reached at `http://ralph/bt/`. It is bound to the
  interface, so a dead tunnel means no traffic rather than a leak.
- Wired ethernet: not available yet. Every public request and every Jellyfin
  stream crosses this one wifi link; Tom→Ralph measured **0.74 MB/s**. The petcam
  still is ~100 KB every 5 s (≈20 KB/s, ~2.5% of the link) plus the HLS stream the
  browser pulls from Tom (~200 kbps).
- DHT calibration: Ralph reads ~2.8°C cooler than Tom's sensor in the same room.
  Ralph's is published, but neither has been checked against a reference.
