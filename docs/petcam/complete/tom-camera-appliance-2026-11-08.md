# Tom becomes a camera appliance (2026-11-08)

**Status: done, 2026-11-08.** Tom captures and serves files. The detector, the
app and all 129M of state live on Ralph. Tom now runs `petcam.sh` (`rpicam-vid
| ffmpeg` → `/dev/shm/petcam`) plus one static file server for that tmpfs.
Nothing stateful is written to Tom's SD card any more except its own process
logs.

## What actually happened

| Piece | As built |
|---|---|
| Tom capture | `petcam.sh` unchanged, same crontab watchdogs |
| Tom serving | `petcam/petcam-static.service` → `python3 -m http.server 8081 --bind 100.77.132.110 --directory /dev/shm/petcam` (tailnet only) |
| Detector | `scripts/petcam-detect.py` on Ralph, `petcam/petcam-detect.service`, still pulled from `http://100.77.132.110:8081/frames/latest.jpg` with a 5 s timeout |
| App | `~/projects/homelab/petcam` on Ralph, `petcam/petcam.service`, `BIND=127.0.0.1` **`PORT=8082`** |
| State | `rsync`/tar copy of `~/petcam` → Ralph (129M: shots, tolabel, training, model, log) |
| nginx (Ralph) | `location /hls/` → `100.77.132.110:8081/` with `Cache-Control: no-store`; everything else → `127.0.0.1:8082` |
| Tom retired | `petcam.service` stopped + disabled, detector cron lines and the running detector removed. Files, `petcam.sh`, state and the old binary all kept |

### Deviations from the plan, and why

1. **App port 8082, not 8080.** 8080 on Ralph is the website (`andrewhale-web`,
   `127.0.0.1:8080`). The first start of `petcam.service` died on
   `address already in use`; the unit shipped with `PORT=8080` would have
   crash-looped.
2. **Paths are home-relative, not `/home/andy/...`.** `~/petcam` in the detector
   (`os.path.expanduser`) and in the app (`os.UserHomeDir()` in the Go var
   block) instead of hard-coded absolute paths. Same resolution on Ralph
   (`/home/andy/petcam`), and it keeps the rollback host working: Tom's own
   `petcam.service` and detector still resolve to `/home/tom/petcam` if they are
   ever re-enabled. Cost: three lines, one small helper.
3. **The detector is a systemd service, not a cron watchdog.** Ralph has no
   cron installed. `petcam-detect.service` with `Restart=always` is the same
   guarantee with fewer moving parts: the kill test brought it back in 13 s
   (cron's window was up to 2 min). The ticket allowed "cron/watchdog"; this is
   the watchdog half, natively.
4. **`no-store` on the whole `/hls/` location.** `python3 -m http.server` cannot
   send `Cache-Control`, and nginx cannot special-case one proxied filename
   without duplicating the whole location. Segments are fetched once per
   playback, so no-store on them costs nothing. Verified: the playlist returns
   `Cache-Control: no-store`.
5. **`scripts/train-model.sh` retargeted too** (`PI=ralph`, model push restarts
   `petcam-detect.service`). Not in the ticket's file list, but the corpus moved
   to Ralph: left alone, the next retrain would have rsynced an empty directory
   from Tom and trained on nothing.
6. **Data moved by a tar pipe through the workstation, not `rsync -a
   tom:~/petcam/ ~/petcam/` from Ralph.** Ralph→Tom SSH is refused by the
   tailnet ACL (`tailnet policy does not permit you to SSH as user "andy"`),
   Tom has no key on Ralph, and Ralph has no working DNS for
   `tom.tailad1015.ts.net` (it timed out; it uses `getent`, no `dig`, and
   tailnet names do not resolve). Ralph→Tom over HTTP is fine and fast (4 ms
   RTT), and that is all the detector needs. **Ralph reaches Tom by IP, never by
   name.**
7. **Two corner-cases from the copy:** a 0-byte training image
   (`2026-11-08_15-07-30.jpg`) caught mid-write was deleted on Ralph, and
   `detections.log` was copied while Tom's detector was still appending — the
   rolling log simply continues on Ralph from that point.

### Measured effect (2026-11-08, right after the cutover)

| | Tom before | Tom after |
|---|---|---|
| `petcam-detect.py` | 13% CPU, 266M RSS, log append every 5 s | gone |
| `petcam` (app) | 0.0% CPU, 14M RSS | gone (now 0.0% / 37M on Ralph) |
| `ffmpeg` | 3.3%, 167M | 3.3%, 166M |
| `rpicam-vid` | 2.3%, 120M | 2.3%, 120M |
| static server | — | 0.0%, 20M |
| sustained SD writes | detector log 5 s + 2 training files per save | none from petcam (only `petcam.sh`'s own logs) |

Ralph: detector 7.1% of a core, 214M RSS, app 0.0% / 37M. The still is ~100 KB
fetched every 5 s ≈ 20 KB/s ≈ **2.5% of the 0.74 MB/s wifi link**, measured at
0.1 s per fetch; the browser's HLS stream is the other 200 kbps. Load on Ralph
went from 0.10 to 0.19 on 4 cores (i5-9500T), so it is noise there.

### Verified

```bash
curl -sI http://100.77.132.110:8081/frames/latest.jpg     # 200, 99927 bytes
curl -s -o /dev/null -w '%{http_code}\n' http://100.77.132.110:8081/index.m3u8   # 200
ssh ralph 'python3 ~/projects/homelab/scripts/petcam-detect.py --once && tail -3 ~/petcam/detections.log'
# -> fresh `scan ...` lines from the loop, and the --once pass exits 0
# on Ralph, through nginx with Host: petcam.andrewahale.com — 200 each:
#   /  /hls/index.m3u8  /shots.json  /live  /log  /label  /review
# /hls/index.m3u8 carries `Cache-Control: no-store`; a .ts behind it is 494 KB/200
# /shots.json lists real shots and /shots/<name>.jpg serves them (128 KB/200)
```

Failure modes checked:

- **Wedged socket:** pointing the detector at a socket that accepts and never
  answers returns `None` after exactly `STILL_TIMEOUT_S` (5.0 s) — the pass is
  skipped, the loop lives. Refused/no-route return `None` immediately.
- **Tom's static server down:** `curl /hls/index.m3u8` through nginx returns
  **502 in 17 ms** and the gallery still renders 200. No hang, no wedge.
- **Detector killed on Ralph:** back in 13 s (`Restart=always`), logging again.
- **cv2 5.0 on Ralph** (Arch's `python-opencv`, Tom ran 4.x): a known cat frame
  detects as class 0 `pancake` @ 0.43, `--selftest` passes.

### Rollback (keep this until 2026-11-15)

Everything needed is still on Tom: `petcam.sh`, `~/petcam` (129M), the built
binary, `petcam.service` (disabled, `BIND=100.77.132.110:8080`), and the old
crontab at `/tmp/crontab.before-petcam-split.txt`. To go back:

1. Tom: `sudo systemctl enable --now petcam.service` (keep
   `petcam-static.service` up — the repo's detector now fetches `STILL` over
   HTTP, and on Tom that is its own `:8081`).
2. Tom: restore the two `petcam-detect` cron lines (`crontab /tmp/crontab.before-petcam-split.txt`),
   or just run the detector by hand.
3. Ralph: nginx `location /` → `http://100.77.132.110:8080` (and drop the
   `/hls/` block, since the app serves `/hls/` itself again), and
   `sudo systemctl disable --now petcam.service petcam-detect.service`.

Copy `~/petcam` back from Ralph first if labels/shots changed in the meantime
(`~/petcam/training` is the only part that would be lost).

### What was deployed by hand and must be redone after the merge

Ralph's checkout is a real clone (`~/projects/homelab`, HTTPS) at upstream main,
with **my worktree's files rsynced over it** — a dirty tree, not a commit:

- `petcam/*.go` (paths), `petcam/petcam.service`, `petcam/petcam-detect.service`,
  `petcam/petcam-static.service`, `scripts/petcam-detect.py`,
  `scripts/train-model.sh` — all rsynced from the worktree. After the merge,
  `git -C ~/projects/homelab checkout -- . && git pull` restores the same
  content and the tree goes clean.
- The binary: `cd ~/projects/homelab/petcam && go build -o petcam .` (done on
  Ralph; amd64).
- Installed outside the repo by hand: `/etc/systemd/system/{petcam,petcam-detect}.service`
  on Ralph, `petcam-static.service` on Tom, `/etc/nginx/conf.d/petcam.conf` on
  Ralph (previous kept as `petcam.conf.bak-20261108`), and Tom's crontab.
- Packages installed for the detector: `python-opencv` + `python-numpy` from
  pacman on Ralph (cv2 5.0.0 / numpy 2.5.4). Nothing came from Guix.

---

## The plan as proposed

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
`docs/ralph/complete/migration-2026-11-07.md`, 21 ms RTT. The still is 94 KB polled
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

(as proposed — see "What actually happened" above for the two things that
changed: the app's port on Ralph, and home-relative paths instead of
`/home/andy/...`)

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
