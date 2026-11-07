# Petcam is a standalone app (2026-11-07)

**Decision:** petcam is no longer part of the website binary. It is its own Go
module in this repo (`petcam/`), its own systemd unit on Tom, binding the
tailnet address only, and Ralph's nginx is the single way in.

## Why

Petcam was `petcam.go` + 5 templates inside `andrewahale.com/web`. Every petcam
change was a change to the public site's build, deployed with the public site,
and Tom's nginx existed mainly to bridge a `127.0.0.1:8080` bind to the LAN for
it. Two consequences we wanted gone:

- **Blast radius.** A broken petcam template or handler failed the *website*
  build on Tom. The site is public; petcam is a private toy.
- **A web server on Tom at all.** Tom is the flaky box (hourly hard resets) and
  its nginx was carrying exactly one job: `petcam.andrewahale.com` →
  `127.0.0.1:8080`. The tunnel now terminates on Ralph, so the origin should
  also be Ralph's nginx.

## What changed

| Before | After |
|---|---|
| `petcam.go` in `andrewahale.com/web`, host-routed via `mux.Handle(petcamHost+"/")` | `petcam/` module, root mux — routes are `/`, `/live`, `/log`, `/shots.json`, `/label*`, `/review*`, `/hls/`, `/shots/` |
| `template.ParseFiles("templates/...")`, relative `http.ServeFile` → only worked from the web repo dir | `//go:embed templates/*.html` + `http.ServeFileFS` — cwd-independent single binary |
| bound `127.0.0.1:8080`, reached through Tom's nginx:80 | `BIND=100.77.132.110` (tailnet), reached by Ralph nginx → `100.77.132.110:8080` |
| kept alive by cron's `@reboot make down run` | `petcam.service`, `Restart=always` |
| `curl -H "Host: petcam.andrewahale.com" localhost:8080/...` | plain `curl http://100.77.132.110:8080/...` |

Nothing in the *contract* changed: `~/petcam/{shots,tolabel,training}`,
`detections.log`, filename-as-timestamp, HLS out of `/dev/shm/petcam`. The
detector (`scripts/petcam-detect.py`) and capture (`scripts/petcam.sh`) are
untouched, still cron-supervised.

## Deliberately not done

- **No auth in the app.** Cloudflare Access (SSO) is still the front door and
  the bind is tailnet-only, so the LAN cannot reach `/delete`, `/label` or
  `/review` either. Two layers already; a third is a liability.
- **No framework, no config file, no DB.** `http.ServeMux` and filenames. The
  only knobs are `BIND`/`PORT` env vars in the unit.
- **Detector stays Python.** Porting YOLO to Go buys nothing; the file contract
  is the interface.
- **`andrewhale-web` still runs on Tom** (127.0.0.1:8080, now unused). Its repo
  and build are untouched on purpose — the website source stays cloned there,
  it just is not the ingress for anything.

## Wiring, as built

- Tom: `/etc/systemd/system/petcam.service` (`BIND=100.77.132.110`,
  `PORT=8080`, `Restart=always`). `nginx` disabled and its `petcam-lan` vhost
  removed — Tom serves nothing over HTTP now.
- Ralph: `/etc/nginx/conf.d/petcam.conf` — `server_name petcam.andrewahale.com`
  → `http://100.77.132.110:8080`, plus `00-upgrade-map.conf` for
  `$connection_upgrade` (needed by the websocket-capable Jellyfin/qBittorrent
  blocks too).
- Ralph: `/etc/cloudflared/config.yaml` — `petcam.andrewahale.com` now points at
  `http://127.0.0.1:80` (Ralph nginx) instead of `192.168.1.24:8080`. Repo
  copies: `docs/ralph/nginx-ralph.conf`, `docs/ralph/cloudflared-config.yaml`.
- Also fixed: `cloudflared.service` hung for minutes on `systemctl restart`
  (SIGTERM drain never completes). `KillSignal=SIGKILL` + `TimeoutStopSec=10`;
  the unit is now in `docs/ralph/cloudflared.service` so a rebuild gets it.

Verified: from Ralph, `/`, `/live`, `/log`, `/shots.json`, `/hls/index.m3u8`
all 200 over the tailnet, and 200 through Ralph nginx with the public Host
header. `go test` covers the embedded pages.

## Rollback

Tom: `systemctl enable --now nginx` (vhost is in git history), point Ralph's
cloudflared petcam ingress back at `http://192.168.1.24:8080`, start the old
`andrewhale-web` (it still has the petcam routes). Nothing was deleted from the
website repo.
