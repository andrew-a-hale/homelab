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
  `dht`, `sshd`, `guix-daemon`. All enabled, all `Restart=always` where relevant.
- **Tom only runs petcam now** — and petcam is a standalone app there
  (`petcam.service`, tailnet `100.77.132.110:8080`), reached from this box's
  nginx only; Tom runs no web server at all. qBittorrent moved here 2026-11-07
  (see `complete/qbittorrent-vpn-2026-11-07.md`), petcam split out of the
  website binary 2026-11-07 (see `../petcam/complete/standalone-app-2026-11-07.md`).
- **LUKS keyslot 0** is the passphrase; **slot 1** is the TPM2 token. If firmware
  settings change, PCR 7 changes, the token stops working and Ralph waits for a
  passphrase at the console. Re-enrol:
  `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2`.
- **Unattended reboot verified 2026-11-07:** power cycle to SSH 26s, nobody at
  the console.
- **Secure Boot is off.** PCR 7 therefore measures little; the TPM protects
  against drive removal, not against someone booting a USB stick on the box.
  See `todo/secureboot-tpm2-*.md`.
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
  stream crosses this one wifi link, and Tom→Ralph measured **0.74 MB/s**.
- DHT calibration: Ralph reads ~2.8°C cooler than Tom's sensor in the same room.
  Ralph's is published, but neither has been checked against a reference.
