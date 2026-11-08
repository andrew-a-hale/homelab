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
| Access | SSH key-only, `andy` in wheel, NOPASSWD sudo | no password auth, no root login |

## Facts worth remembering

- **IP:** `192.168.1.26` (DHCP lease — not pinned yet). Tailnet:
  `ralph` = `100.108.202.106`.
- **What runs here:** `andrewhale-web`, `nginx`, `cloudflared`, `jellyfin`,
  `dht`, **`petcam` + `petcam-detect`**, `sshd`, `guix-daemon`. All enabled, all
  `Restart=always` where relevant.
- **Tom only captures now.** Since 2026-11-08 it runs `petcam.sh`
  (`rpicam-vid | ffmpeg` → `/dev/shm/petcam`) and `petcam-static.service`, a dumb
  `python3 -m http.server 8081` bound to `100.77.132.110` for that tmpfs. The
  detector, the app, the gallery and all 129M of state live here
  (`docs/petcam/complete/tom-camera-appliance-2026-11-08.md`). qBittorrent moved
  here 2026-11-07 (see `complete/qbittorrent-vpn-2026-11-07.md`), petcam split
  out of the website binary 2026-11-07 (see
  `../petcam/complete/standalone-app-2026-11-07.md`).

## Petcam here (since 2026-11-08)

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
- **LUKS keyslot 0** is the passphrase; **slot 1** is the TPM2 token. If firmware
  settings change, PCR 7 changes, the token stops working and Ralph waits for a
  passphrase at the console. Re-enrol:
  `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2`.
- **Unattended reboot verified 2026-11-07:** power cycle to SSH 26s, nobody at
  the console.
- **Secure Boot is off, deliberately.** PCR 7 therefore measures little; the TPM
  protects against drive removal, not against someone booting a USB stick on the
  box. Own keys via `sbctl` were decided against: they only harden the auto-unlock
  seal against a targeted evil maid who can modify the boot partition and wait for
  the next boot, and LUKS alone already covers opportunistic theft.
- **i5-9500T is vPro-capable** → Intel AMT could give an out-of-band console for
  the exact failure mode this box has (needs a keyboard at the LUKS prompt).
- **No swap.** 15GB RAM, nothing hibernates.

## Install

`scripts/ralph-arch-install.sh` is the whole install, guarded against wiping the
wrong disk, and `scripts/ralph-finish.sh` re-runs the tail if it stops partway.
Read them before running; they wipe `/dev/nvme0n1`.

## Open questions

- qBittorrent runs here behind Proton WireGuard (`proton0`, `Table=off`, one uid
  rule — the VPN serves qBit only), reached at `http://ralph/bt/` with basic
  auth `andy`/`pancake`. Tom's qBit/Proton stack is gone (binary, unit and nginx
  removed 2026-11-08, no `/bt/` on Tom).
- Wired ethernet: not available yet. Every public request and every Jellyfin
  stream crosses this one wifi link, and Tom→Ralph measured **0.74 MB/s**. The
  petcam still is ~100 KB every 5 s (≈20 KB/s, ~2.5% of the link) plus the HLS
  stream the browser pulls from Tom (~200 kbps).
- DHT calibration: Ralph reads ~2.8°C cooler than Tom's sensor in the same room.
  Ralph's is published, but neither has been checked against a reference.
