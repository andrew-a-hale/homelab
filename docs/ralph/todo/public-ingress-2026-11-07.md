# Ralph as the public ingress (2026-11-07)

**Status:** planned. Nothing changed yet. Decision: the tunnel moves to Ralph,
because Ralph is the always-on gateway and everything else is just "on the
network".

## What exists today (facts, not assumptions)

The tunnel is **on Tom**, launched from **cron**, not systemd:

```
/usr/local/bin/cloudflared tunnel run andrewahale     # ~/.cloudflared/config.yaml
cgroup: /system.slice/cron.service                     # no unit, no supervision
watchdog: */2 * * * * pgrep -x cloudflared || runuser -u cloudflared -- cloudflared ...
```

Ingress is **locally managed** (`~/.cloudflared/config.yaml`, mirrored in
`docs/petcam/cloudflared-config.yaml`), not dashboard-side. Tunnel ID
`5b7e3976-7429-495d-beee-45d5213a0798`, name `andrewahale`.

| Hostname | Origin today |
|---|---|
| `andrewahale.com`, `www` | Tom `127.0.0.1:8080` (Go) |
| `placetime.andrewahale.com` | Tom `127.0.0.1:8080` (Go, host-routed) |
| `petcam.andrewahale.com` | Tom `127.0.0.1:8080` (Go, host-routed) |
| `jellyfin.andrewahale.com` | Tom `127.0.0.1:8096` |

## The two couplings that make this non-trivial

1. **Petcam's UI is the Go binary**, and it reads Tom's local filesystem:
   `/home/tom/petcam/shots/`, `/dev/shm/petcam/index.m3u8`. Camera capture and the
   YOLO detector are on Tom and must stay (the camera is plugged into it).
2. ~~The website embeds live sensor data from Tom's GPIO.~~ **Resolved
   2026-11-07: the DHT is on Ralph**, a USB-serial (CH340) device on
   `/dev/ttyUSB0` streaming `28.4 C 35.7 %` at 115200. `scripts/dht-writer.sh` +
   `dht.service` publish `/srv/dht/dht.json` in exactly the shape the Go app
   emitted, so nginx just serves that file. Nothing about the website needs Tom.

## Target shape

```
visitor → Cloudflare edge → tunnel (cloudflared on RALPH, systemd)
                              ├─ andrewahale.com / www / placetime → ralph nginx:80
                              │     ├─ /static/dht.json  → /srv/dht/dht.json (USB DHT on Ralph)
                              │     └─ everything else    → 127.0.0.1:8080 (Go on Ralph)
                              ├─ jellyfin.andrewahale.com → 127.0.0.1:8096 (Jellyfin on Ralph)
                              └─ petcam.andrewahale.com   → http://192.168.1.24:8080  (Go on Tom)
```

- Ralph runs the website **and** the tunnel.
- Tom keeps: camera, `petcam.sh`, `petcam-detect.py`, the DHT sensor, and a second
  instance of the same Go binary that only ever answers `petcam.*` traffic.
- nginx on Ralph intercepts `/static/dht.json` and serves `/srv/dht/dht.json`.
  One `location` block, no code change to the Go app. (Still needed: the Go app's
  own handler reads GPIO, which Ralph does not have.)
- **Petcam traffic hops through Ralph.** Every HLS segment goes Tom → Ralph →
  edge, i.e. Ralph's wifi carries it twice. At 480p (1–2 Mbps) that fits inside
  the measured 0.74 MB/s, but it means petcam depends on Ralph being up. If that
  ever bites, give Tom its own tunnel for `petcam.*` only: no hop, full
  independence, one more tunnel ID to manage.

### Why not the alternatives

- **Move petcam data to Ralph, run one Go app.** Needs the capture pipeline on Tom
  to write to Ralph (NFS/rsync/streaming) and `/dev/shm` HLS to be shipped
  cross-host. Real work, and it makes petcam fragile in a new way.
- **Point everything at Tom.** Keeps the website dependent on the box with a
  documented hourly hard-reset problem. Defeats the point of Ralph.
- **Lift the sensor with a network sensor node.** Correct long term, out of scope
  now; the DHT is a physical thing in a specific room.

## Cutover order (order matters)

1. Build the Go site on Ralph, run it on `127.0.0.1:8080`, verify `/`, `/blog`,
   `/static/*` locally with `Host:` headers.
2. Add nginx on Ralph: `:80`, proxy to Go, `location = /static/dht.json` →
   `alias /srv/dht/dht.json`. `dht.service` is already live.
3. Install `cloudflared` on Ralph, copy `cert.pem` + the tunnel credentials JSON to
   `/etc/cloudflared/` (mode 600, root), write the config with the ingress above,
   **run it as a systemd unit with `Restart=always`** — not cron.
4. **Remove Tom's cloudflared watchdog from cron first**, then stop Tom's
   cloudflared. Two instances of the same tunnel with different ingress split
   traffic unpredictably. The `*/2` cron line will resurrect Tom's on its own if
   it is left in place.
5. Verify each public hostname over the real edge (not the LAN — see the dnsmasq
   NXDOMAIN gotcha in `docs/website/README.md`). `curl -H "Host: ..."` against
   `127.0.0.1:80` proves the origin; only a public request proves the tunnel.
6. Only then remove Jellyfin/nginx/qBittorrent from Tom.

## Open questions

- `placetime` is `:8080` in the repo YAML but `:8081` in `docs/website/README.md`.
  Which is it? (`:8081` on Tom today is qBittorrent's WebUI, so `:8080` is likely
  correct and the doc is stale.)
- Jellyfin's `BaseUrl` is `/jf`, so `jellyfin.andrewahale.com` currently only works
  at `/jf/`. Worth clearing `BaseUrl` during the move so the hostname serves at
  root.
- The tunnel credentials are a secret. They come from Tom's
  `~/.cloudflared/`; nothing in the repo, and Ralph gets them by hand.
- Ralph's DHT and Tom's DHT read different numbers (28.4/37 on Ralph vs 31.2/27
  on Tom) because they are different physical sensors in different places.
  **Decided 2026-11-07:** the page shows Ralph’s reading — Tom’s sensor is gone
  (no USB serial on Tom, `dht-daemon` disabled), so there is only one sensor.
