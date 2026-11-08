# Tom becomes a camera appliance (2026-11-08)

**Status:** proposed, not started. Nothing is blocked on it.

Tom's only irreplaceable part is the CSI `imx708`. Everything else the petcam
runs — YOLO inference, the HLS transcode, the web app, and ~120M of state — is
movable, and moving it leaves Tom with two processes and removes its SD card
from the "sustained writes" list.

Do this for the SD card and for rebuild simplicity, **not for load**: Tom is
86% idle (measured 2026-11-08).

## Measured (2026-11-08, live on Tom)

| Process | CPU | RSS | Notes |
|---|---|---|---|
| `petcam-detect.py` | ~13% of a core | 266M | ~½ the box's total usage |
| `ffmpeg` (HLS 480p + 1fps still) | 3.3% | 167M | |
| `rpicam-vid` | 2.3% | 120M | Pi 5 has no HW H.264 encoder; this already software-encodes |
| `petcam` (app) | 0.0% | 14M | file handlers only |

4 cores / 8G, 57 °C, 86% idle. Moving the detector frees ~0.6 of 4 idle cores —
worth nothing on CPU.

State: `shots` 1.7M, `tolabel` 20K, `training` 94M (622 frames), `model` 25M,
`detections.log` 7M (appended every 5 s, rolling 14 days).

Tom↔Ralph is **wifi only** (`eth0` and `eno2` both DOWN), raw ~0.74 MB/s per
`docs/ralph/todo/migration-2026-11-07.md`, 21 ms RTT. The still is 94 KB polled
every 5 s ≈ 19 KB/s ≈ 2.5% of the link; the HLS stream is another 200 kbps.
Acceptable, but it is not free — see Risks.

## Why

1. **SD writes.** `detections.log` every 5 s plus a training pair per save
   (120 s cooldown) is the only *sustained* write on Tom's card, and the card is
   a listed suspect in the reboot saga
   (`docs/server/todo/tom-reboots-hang-2026-10-31.md`). `/dev/shm` frames are
   tmpfs and cost nothing.
2. **Rebuild.** Tom becomes: flash SD, `petcam.sh`, one static server. No Go
   toolchain, no `python3-opencv`/numpy, no 25M model, no detector cron. That is
   the AGENTS.md bootstrap goal.
3. **One data home.** `scripts/train-model.sh` loses `PI=tom` and the rsync
   pull; the corpus and the pushed model are local. Net ~10 lines deleted.

**It does not help the reboots.** Those are an I2C camera-bus stall, not load;
`petcam.sh` stays byte-identical.

## Target split

**Tom** — `petcam.sh` unchanged (`rpicam-vid | ffmpeg` → `/dev/shm/petcam`),
plus one read-only static server for that dir on the tailnet, `:8081`:

```bash
python3 -m http.server 8081 --bind 100.77.132.110 --directory /dev/shm/petcam
```

Needs `Cache-Control: no-store` on the `.m3u8` (hls.js refetches it) — if
`http.server` can't be made to send that, a ~6-line Go handler replaces it.

**Ralph** — everything stateful:

| Piece | Change |
|---|---|
| `petcam-detect.py` | `STILL` → `http://100.77.132.110:8081/frames/latest.jpg`; `TRAIN_*`, `TOLABEL`, `LOG`, `MODEL` → `~/petcam/*` |
| `petcam` app | `shotsDir`/`hlsDir`/`tolabelDir`/`train*`/logs → `~/petcam/*`; `BIND=127.0.0.1` |
| nginx | `petcam.andrewahale.com`: `location /hls/ → 100.77.132.110:8081/`, rest → `127.0.0.1:8080` (so the browser never touches Tom) |
| cron | detector watchdog moves here; delete Tom's `petcam-detect` lines |
| data | one `rsync -a tom:~/petcam/ ~/petcam/` (~120M) |

The app's own `/hls/` route becomes dead but harmless — nginx answers first.
`/capture` keeps working because it shells out to the detector, which is now
also on Ralph.

## Risks

- **New failure mode:** Tom's static server down → `/live` dead and the detector
  silent. `cv2.imread` returning None already has the right path (retry in 5 s),
  but the HTTP fetch needs a timeout, or a hung socket stalls the loop instead
  of skipping a pass.
- **Detector depends on the wifi link.** A 20 s stall = a missed cat, not data
  loss. The 0.74 MB/s link is shared with Jellyfin and the tunnel.
- Ralph down = no detections. Nearly free: Ralph is the only ingress, so the
  site is already gone in that case.
- The app must bind loopback on Ralph — it currently exposes on the tailnet and
  nginx is the only gate.

**Do not do the half-measure** (move only the detector, leave its output on
Tom): its entire job is writing files, so that trades local writes for a
network filesystem. All or nothing.

## Verify

```bash
# on Tom: still + stream served, tailnet only
curl -sI http://100.77.132.110:8081/frames/latest.jpg
curl -s  http://100.77.132.110:8081/index.m3u8
# on Ralph: detector runs, app answers, nginx proxies the stream
python3 ~/projects/homelab/scripts/petcam-detect.py --once && tail -3 ~/petcam/detections.log
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: petcam.andrewahale.com" http://127.0.0.1/
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: petcam.andrewahale.com" http://127.0.0.1/hls/index.m3u8
```

Then check `/live` shows motion, `/log` shows fresh passes, and kill Tom's
static server once to confirm the app degrades instead of hanging.

## Rollback

Nothing is deleted on Tom until the split is proven: the detector cron and
`~/petcam` state stay for a week. Revert = point Ralph's nginx back at
`:8080` on Tom and restart Tom's detector cron.
