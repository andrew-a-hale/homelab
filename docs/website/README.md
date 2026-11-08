# Website (andrewahale.com)

The Go site, `placetime`, and the DHT feed — all on **Ralph**, behind the one
Cloudflare tunnel. Verified 2026-11-08: every hostname answers, `/static/dht.json`
is live from the USB sensor.

## What serves what

| Hostname | Origin | Notes |
|---|---|---|
| `andrewahale.com`, `www.andrewahale.com` | nginx:80 → `127.0.0.1:8080` | `/`, `/blog`, `/static/*`, `/map/`, `/pong/` |
| `placetime.andrewahale.com` | nginx:80 → same Go app | host-routed inside the binary |
| `jellyfin.andrewahale.com` | `127.0.0.1:8096` direct | skips nginx on purpose (BaseUrl `/jf`) |
| `petcam.andrewahale.com` | nginx:80 → `127.0.0.1:8082` + `/hls/` → Tom | separate app, `../petcam/` |

| Piece | Where |
|---|---|
| Binary | **Ralph**, `/srv/website/web/andrewhale-web`, unit `andrewhale-web.service` (`User=andy`, `WorkingDirectory=/srv/website/web`) |
| Source | separate repo, `andrew-a-hale/andrewahale.com`, checked out at `/srv/website/web` |
| Tunnel | **Ralph**, `cloudflared.service`, config `../ralph/cloudflared-config.yaml` |
| nginx | **Ralph**, `/etc/nginx/conf.d/{00-upgrade-map,ralph,petcam}.conf` |

Ralph is the **only** Cloudflare tunnel in the house. Tom runs no web server and
no tunnel: it captures video (see [`../server/README.md`](../server/README.md)).

## The two things that catch people out

1. **`WorkingDirectory` matters.** Templates and `static/` are resolved relative
   to CWD, so the unit must start in `/srv/website/web`. Running the binary from
   elsewhere 404s the pages.
2. **`/static/dht.json` is an nginx alias, not the file in the repo.**
   `location = /static/dht.json { alias /srv/dht/dht.json; }` serves the live
   sensor; the copy committed in the website repo is stale by design. Request it
   *through* nginx (`http://ralph/static/dht.json`), never through the Go app's
   own static dir.

## Deploy

```bash
ssh ralph
cd /srv/website/web && git pull
/usr/local/go/bin/go build -o andrewhale-web .    # binary name is andrewhale-web (one 'h')
sudo systemctl restart andrewhale-web
```

No cron watchdogs, no `nohup`: `Restart=always` in the unit is the whole
supervision story.

## Verify

```bash
for h in andrewahale.com www.andrewahale.com placetime.andrewahale.com; do
  printf '%-30s %s\n' "$h" "$(curl -s -o /dev/null -w '%{http_code}' https://$h/)"
done
curl -s http://ralph/static/dht.json            # live JSON, timestamp seconds old
ssh ralph 'systemctl is-active andrewhale-web nginx cloudflared'
sudo journalctl -u cloudflared -n 30            # tunnel reconnects
```

## Security

- The site is public by design — static HTML, `/blog`, `/map/`, `/pong/`. No
  user input reaches the filesystem: the only handlers are `http.FileServer`
  over `static/`, `pong/` and per-host routing.
- `petcam.andrewahale.com` is behind **Cloudflare Access** (email OTP, one
  address). Jellyfin is protected only by its own login.
- Access API tokens: the tunnel's `cert.pem` holds a `cfut_…` token with **read**
  scope on Access apps only. Writes need a dashboard token or a click.

History: `completed/` (tunnel 502s, `tom.local`), `../ralph/complete/public-ingress-2026-11-07.md`
(the tunnel and everything web-related moving off Tom).
