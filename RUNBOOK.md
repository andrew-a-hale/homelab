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

1. Arch install, LUKS on the NVMe. TPM2 auto-unlock is optional (see TODO).
2. Media drive: ext4, label `media`, mounted at `/srv/media`, fstab with
   `nofail`. Keep the symlink `ln -s /srv/media /mnt/storage/media` — the
   Jellyfin config references that path.
3. `pacman -S jellyfin nginx cloudflared qbittorrent-nox tailscale wireguard-tools ufw`
   (Guix is an optional layer on top; nothing in the stack needs it.)

### 2. Code

1. Clone this repo and `andrew-a-hale/andrewahale.com` (needs a GitHub key,
   see secrets).
2. Website: build the Go binary to `/srv/website/web/andrewhale-web`, unit
   `andrewhale-web.service` (User=andy, WorkingDirectory=/srv/website/web,
   listens `127.0.0.1:8080`).
3. nginx: copy `docs/ralph/nginx-ralph.conf` and `docs/ralph/petcam.conf`
   (if present) to `/etc/nginx/conf.d/`. Everything is reached through nginx
   on :80: `/jf/` → 8096, `/bt/` → 8081 (basic auth), `/static/dht.json` →
   `/srv/dht/dht.json`, rest → 127.0.0.1:8080.
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
  first-run wizard, set BaseUrl to `/jf`, libraries ` /srv/media/media/{movies,tv}`
  (i.e. `/mnt/storage/media/...`). Users re-set their own passwords.
  `systemctl enable --now jellyfin`.
- **qBittorrent** — `qbittorrent-nox@qbittorrent`, whose `ExecStartPre` waits
  for `proton0`. Bind the interface to `10.2.0.2` in its settings (leak
  protection) and set the web login (tom/pancake). Torrent state is not
  preserved either: re-add what you still want.
- **Proton VPN** — `wg-quick@proton0` with `/etc/wireguard/proton0.conf`
  (secret, see below), enabled at boot, plus `proton-guard.timer` (every 5 min) to
  re-raise `proton0` if it ever drops.
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

## Tom (petcam only)

Debian on the Pi, clone this repo, `cd petcam && make`, `petcam.service`
(User=tom) points at the built binary; camera and YOLO model/labels are local
(`~/petcam/{model,tolabel,training}` — the training data also exists on the
laptop under `~/petcam-train`). Join the tailnet. Nothing else belongs on Tom.

## Secrets — none are stored anywhere; regenerate each

| Secret | Where it lives | How to regenerate |
|---|---|---|
| Cloudflare tunnel | `/etc/cloudflared/{cert.pem,<tunnel-id>.json,config.yaml}` | Cloudflare dashboard → Zero Trust → Tunnels → create tunnel, `cloudflared tunnel login/create/token`; ingress shape in `docs/ralph/` |
| Proton VPN WireGuard key | `/etc/wireguard/proton0.conf` | Proton VPN dashboard → WireGuard → add key → download .conf |
| Tailscale node keys | `/var/lib/tailscale` | `tailscale up` + approve in the admin console (or auth key) |
| GitHub push key | Tom's `~/.ssh/id_ed25519` | `ssh-keygen` + add pubkey to the GitHub account |
| Jellyfin users | `/var/lib/jellyfin` | first-run wizard / admin reset — passwords are gone, that is the deal |
| qBittorrent login + state | `/var/lib/qbittorrent-nox` | set login fresh, re-add torrents |
| SSH host keys | `/etc/ssh` | regenerated on install; refresh known_hosts |
| Router admin | sticker / ISP account | physical |

Not a secret but with **no second copy**: the 62G of media on `/srv/media`.
Re-rip or re-torrent if the drive dies. Say the word if that changes.

## Deliberate non-goals (decided 2026-11-07)

- **DHT calibration** — the sensor reads true; no offset exists and none should
  be added.
- **Secure Boot** — skipped; it only hardens TPM auto-unlock against a targeted
  evil maid, not against the actual threat (theft of the box).
- **Intel AMT** — skipped; a remote console for a physically reachable box. Keep
  a keyboard + monitor on the shelf instead.
