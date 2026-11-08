# Homelab rebuild runbook

**Nothing here is backed up, by design.** Config and code live in this repo;
secrets are regenerated from their providers. This file lists the order to
rebuild in and every secret that must be re-created. Read top to bottom on a
cold morning.

Hosts: **ralph** = always-on server (OptiPlex 7070, Arch, LUKS root, 3.6T media
drive). **tom** = Pi 5, petcam only, ~90% uptime is fine — nothing else on Tom
is load bearing. **jason** = storage/runner. **rose** = idle node.

## Ralph

### 1. Base

1. Arch install, LUKS2 on the NVMe (btrfs subvols `@ @home @log @pkg
   @snapshots`, systemd-boot, ESP at `/boot`; `scripts/ralph-arch-install.sh`
   then `scripts/ralph-finish.sh` are the actual install). TPM2 auto-unlock is
   enrolled on the live box (LUKS token 0, PCR 7) — without it every reboot
   stops at a passphrase prompt, and there is no keyboard at the shelf.
2. Media drive: ext4, label `media`, mounted at `/srv/media`, fstab with
   `nofail`. Keep the symlink `ln -s /srv/media /mnt/storage/media` — the
   Jellyfin config references that path.
3. `pacman -S jellyfin-server jellyfin-web jellyfin-ffmpeg nginx cloudflared
   qbittorrent-nox tailscale wireguard-tools ufw go`
   (Guix is an optional layer on top; nothing in the stack needs it — on the
   live box `/gnu/store` holds only `guix` and `nss-certs`.)

### 2. Code

1. Clone this repo and `andrew-a-hale/andrewahale.com` (needs a GitHub key,
   see secrets).
2. Website: build the Go binary to `/srv/website/web/andrewhale-web`, unit
   `andrewhale-web.service` (User=andy, WorkingDirectory=/srv/website/web,
   listens `127.0.0.1:8080`).
3. nginx: copy `docs/ralph/nginx-ralph.conf` to `/etc/nginx/conf.d/`. It
   carries the upgrade map, the `ralph` default server (`/jf/` → 8096, `/bt/` →
   8081 with basic auth, `/static/dht.json` → `/srv/dht/dht.json`, rest →
   127.0.0.1:8080) and the `petcam.andrewahale.com` server as one file; the live
   box splits the same content into `00-upgrade-map.conf`, `ralph.conf` and
   `petcam.conf`. The petcam server needs the petcam app on `127.0.0.1:8082`
   and Tom's static server on the tailnet (`100.77.132.110:8081`, `/hls/` →
   there). One hostname skips nginx: the cloudflared ingress points
   `jellyfin.andrewahale.com` straight at 127.0.0.1:8096, because its BaseUrl
   already carries `/jf`.
4. DHT: `install -m755 scripts/dht-writer.sh /usr/local/bin/dht-writer`, then
   this unit as `/etc/systemd/system/dht.service`:

   ```ini
   [Unit]
   Description=USB DHT sensor -> /srv/dht/dht.json
   After=dev-ttyUSB0.device
   Requires=dev-ttyUSB0.device

   [Service]
   ExecStart=/usr/local/bin/dht-writer
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```

### 3. Services

- **Jellyfin** — config (`/var/lib/jellyfin`) is *not* preserved: run the
  first-run wizard, set BaseUrl to `/jf`, libraries `/srv/media/{movies,tv}`
  (the library links store `/mnt/storage/media/...`, the symlink to
  `/srv/media`; `/srv/media/music` exists but is not a library). Add the
  drop-in `jellyfin.service.d/` with `RequiresMountsFor=/srv/media` so an
  unplugged media drive stops Jellyfin instead of serving empty libraries.
  Users re-set their own passwords. `systemctl enable --now jellyfin`.
- **qBittorrent** — `qbittorrent-nox@qbittorrent`, whose `ExecStartPre` waits
  for `proton0`. Bind the network interface to `proton0` in its settings
  (`Session\Interface=proton0`; leak protection) and set the web login to
  `andy`/`pancake` in `/etc/nginx/htpasswd` (`*/bt/` basic auth; qBit's own
  WebUI is localhost-only with auth off). Torrent state is not preserved
  either: re-add what you still want.
- **Proton VPN** — `wg-quick@proton0` with `/etc/wireguard/proton0.conf`
  (secret, see below), enabled at boot, plus `proton-guard.timer` (every 5 min)
  running `proton-guard.service` → `install -m755 scripts/proton-guard.sh
  /usr/local/bin/proton-guard.sh`, which re-raises `proton0` if it ever drops
  (the two unit files live on the box, not in this repo; the guard is what
  actually brings the tunnel up in practice).
- **Cloudflared** — `docs/ralph/cloudflared.service`, config at
  `/etc/cloudflared/config.yaml` (shape in `docs/ralph/`).
- **Tailscale** — `tailscale up`, then in the admin console: disable key
  expiry and set ACL `ssh` to `accept` (docs/vpn/complete/tailnet-key-expiry-2026-11-07.md).
- **Firewall (ufw)**:

  ```
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow from 192.168.1.0/24
  ufw allow from 100.64.0.0/10
  ufw allow 41641/udp        # tailscale direct connections
  ufw enable
  ```

  No WAN inbound is needed at all: the tunnel dials out. LAN and tailnet are
  trusted whole.

## Tom (petcam only — capture and nothing else since 2026-11-08)

Debian on the Pi. Tom runs **two things**: `scripts/petcam.sh` (`rpicam-vid |
ffmpeg` → `/dev/shm/petcam`, launched by cron, see `docs/petcam/crontab.txt`)
and `petcam-static.service` (`python3 -m http.server 8081 --bind
100.77.132.110 --directory /dev/shm/petcam`). No Go, no OpenCV, no model, no
website, no unit for the gallery — the detector, the app and all petcam state
(`~/petcam/{model,tolabel,training,shots}`) live on **Ralph** now, because the
CSI camera is the only thing that cannot leave. Join the tailnet, give it a
static IP, and that is the whole box.

Packages: `ffmpeg python3` (`rpicam-apps` ships with Raspberry Pi OS).
Rebuild detail and the rollback path: `docs/petcam/complete/tom-camera-appliance-2026-11-08.md`.

## Secrets — none are stored anywhere; regenerate each

| Secret | Where it lives | How to regenerate |
|---|---|---|
| Cloudflare tunnel | `/etc/cloudflared/{cert.pem,<tunnel-id>.json,config.yaml}` | Cloudflare dashboard → Zero Trust → Tunnels → create tunnel, `cloudflared tunnel login/create/token`; ingress shape in `docs/ralph/` |
| Proton VPN WireGuard key | `/etc/wireguard/proton0.conf` | Proton VPN dashboard → WireGuard → add key → download .conf |
| Tailscale node keys | `/var/lib/tailscale` | `tailscale up` + approve in the admin console (or auth key) |
| GitHub push key | `~/.ssh/id_ed25519` on each host that clones (ralph, jason, tom) | `ssh-keygen` + add pubkey to the GitHub account |
| Jellyfin users | `/var/lib/jellyfin` | first-run wizard / admin reset — passwords are gone, that is the deal |
| qBittorrent login + state | `/var/lib/qbittorrent` | set login fresh (`andy`/`pancake` in `/etc/nginx/htpasswd`), re-add torrents |

| SSH host keys | `/etc/ssh` | regenerated on install; refresh known_hosts |
| Router admin | sticker / ISP account | physical |

Tom has no qBittorrent at all since 2026-11-08: binary, unit and nginx removed
(`qbittorrent-nox@tom` is `not-found`).

Not a secret but with **no second copy**: the 62G of media on `/srv/media`.
Re-rip or re-torrent if the drive dies. Say the word if that changes.

## Deliberate non-goals (decided 2026-11-07)

- **DHT calibration** — the sensor reads true; no offset exists and none should
  be added.
- **Secure Boot** — skipped; it only hardens TPM auto-unlock against a targeted
  evil maid, not against the actual threat (theft of the box).
- **Intel AMT** — skipped; a remote console for a physically reachable box. Keep
  a keyboard + monitor on the shelf instead.
