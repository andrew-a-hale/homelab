# Ralph: public ingress moved off Tom (2026-11-07)

**Date:** 2026-11-07
**Status:** done, verified from the public internet. Reversible.

Ralph is now the gateway. Cloudflare terminates into Ralph, Ralph serves the
website itself, Jellyfin itself, and forwards only petcam to Tom.

## What runs where now

| Hostname | Origin |
|---|---|
| `andrewahale.com`, `www`, `placetime` | Ralph nginx:80 → Go app 127.0.0.1:8080 |
| `jellyfin.andrewahale.com` | Ralph 127.0.0.1:8096 (direct, not via nginx) |
| `petcam.andrewahale.com` | Ralph → Tom nginx:80 → Go app 127.0.0.1:8080 |
| `/static/dht.json` | Ralph nginx `alias /srv/dht/dht.json` (USB DHT on Ralph) |

New on Ralph: `andrewhale-web.service`, `nginx`, `cloudflared.service`,
`dht.service`. All `Restart=always` / enabled at boot. nginx config lives in
`docs/ralph/nginx-ralph.conf`, tunnel ingress in
`docs/ralph/cloudflared-config.yaml`.

## Decisions

- **Jellyfin goes straight to 8096, not through nginx.** Its `BaseUrl` is `/jf`,
  so routing `jellyfin.*` through nginx:80 would serve the *website* to anyone
  asking `jellyfin.*` for `/`.
- **The website goes through nginx**, purely so `/static/dht.json` can be
  intercepted. See below.
- **cloudflared is a systemd unit on Ralph, not cron.** On Tom it was
  `runuser -u cloudflared -- cloudflared ...` started by an `@reboot` line plus a
  `*/2` pgrep watchdog, i.e. up to two minutes of outage after any crash. Ralph's
  unit is `Restart=always`, `RestartSec=5`.
- **No VPN bypass needed on Ralph yet.** Tom needs `cloudflared-bypass.sh` because
  Proton VPN swallows its egress. Ralph has no VPN client, so the direct route is
  already the "bare ISP" route. It will need revisiting the day Proton lands here.

## Two things that would have broken the site silently

1. **`/static/dht.json` is a stale file committed in the repo.** The Go app
   overwrites it from GPIO on Tom; on Ralph it happily served
   `{"temp":31.2,...,"date":"Sat Nov  7 04:39:00 2026"}` — a plausible-looking
   reading from hours earlier. Fixed by nginx `location = /static/dht.json`
   serving `/srv/dht/dht.json`, written by `dht.service`. Note the ordering trap:
   that `location` must be exact (`=`) and must come before the proxy.
2. **The Go app binds `127.0.0.1:8080` only.** The original plan had Ralph's
   ingress proxy straight to `http://192.168.1.24:8080`; from Ralph that is
   `000` (connection refused), which would have been a 502 for petcam only, after
   the cutover, at night. Fixed with a Tom-side nginx vhost
   (`/etc/nginx/sites-available/petcam-lan`) that proxies the petcam hostname to
   the local app, and ingress pointing at Tom's `:80`. Chosen over rebinding the
   app to `0.0.0.0`, which would expose it on the LAN.

## The DHT sensor

The sensor is on Ralph, USB-serial (CH340) at `/dev/ttyUSB0`, streaming
`28.4 C 35.7 %` at **115200** baud. `scripts/dht-writer.sh` parses that and writes
the JSON the site's JS expects, atomically, once per reading. `dht.service` uses
`Requires=dev-ttyUSB0.device` so it starts after the device exists.

**Calibration:** Ralph's sensor and Tom's read ~2.8°C apart in the *same room*
(28.4/37 vs 31.2/27). One of them is wrong; until it is checked against a
reference, treat either number as ±3°C. Tom's copy is now unused.

## Cutover order actually used

1. Ralph: nginx + Go app + `dht.service` verified locally with `Host:` headers.
2. Ralph: cloudflared installed, credentials copied from Tom by hand
   (`cert.pem` + tunnel JSON → `/etc/cloudflared/`, mode 600), started. Both
   instances up simultaneously — safe here only because the ingress rules served
   the *same* content from both ends.
3. Tom: crontab backed up to `~/crontab.before-ralph-tunnel-2026-11-07`, all
   `cloudflared` lines removed (the `*/2` watchdog would otherwise resurrect it).
4. Tom: cloudflared stopped. **Done before the config was fixed for the
   localhost-bind problem, which is why the petcam gap had to be found fast.**
5. Public verification of all seven hostnames.

## Verified from the public internet

```
https://andrewahale.com/                    200
https://andrewahale.com/blog                200
https://andrewahale.com/static/dht.json     200  -> {"temp":28.3,"humidity":37.3,"date":"Sat Nov  7 19:11:25 AEDT 2026"}
https://www.andrewahale.com/                200
https://placetime.andrewahale.com/          200
https://jellyfin.andrewahale.com/jf/web/    200
https://petcam.andrewahale.com/             302 -> Cloudflare Access (correct, SSO gate)
```

## Rollback

```bash
# on Tom
crontab /home/tom/crontab.before-ralph-tunnel-2026-11-07
sudo runuser -u cloudflared -- env TUNNEL_EDGE_IP_VERSION=4 \
     /usr/local/bin/cloudflared tunnel run andrewahale &
# on Ralph
sudo systemctl stop cloudflared
```

Do not run both tunnels with *different* ingress for long: replicas of one tunnel
are picked per connection, so requests land on either config at random.

## Follow-up, done right after (same evening)

- **Jellyfin playback confirmed working on Ralph** by the owner, so Tom's Jellyfin
  was `disable --now`'d and its `/jf/` nginx alias removed. Tom is now petcam +
  qBittorrent only. Its nginx keeps `/bt/` (LAN, basic auth) and the
  `petcam-lan` vhost that Ralph's tunnel proxies to.
- **The DHT disagreement resolved in Ralph's favour:** Ralph's sensor is accurate,
  Tom's reads ~3°C high. The stale value the site was serving was Tom's, frozen at
  04:39. Tom's sensor is now unused and can be retired.
- Gotcha worth remembering: moving a config file into `/etc/nginx/sites-enabled/`
  as a "backup" makes nginx load it. Two `default_server` blocks, `nginx -t`
  fails, and the old config keeps serving so nothing *looks* broken.

## Still open
- qBittorrent + Proton split tunnel still on Tom (`/bt/` on Tom's nginx is now
  LAN-only, no longer published — the tunnel does not route it).
- Tom's `/jf/` nginx alias is now redundant.
- `systemd-networkd-wait-online.service` reports `failed` on Ralph at boot
  (wifi is slower than the timeout). Harmless — units still start — but noisy in
  `systemctl --failed`.
- Guix: `guix pull` still needed the `nss-certs` treatment, see the migration doc.
