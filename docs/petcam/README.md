# Pet Cam

Two boxes, one pet cam. **Tom** is a camera appliance (capture + a static file
server); **Ralph** holds every stateful part (detector, app, gallery, training
corpus). This file is how to rebuild and operate it; the reasoning and the
measurements live in `complete/`.

Everything needed is in this repo (`petcam/` + `scripts/`). The website source
has its own repo (`andrew-a-hale/andrewahale.com`) and knows nothing about
petcam.

## What runs where

| Piece | Where | Notes |
|---|---|---|
| `petcam.sh` | **Tom**, `~/projects/homelab/scripts/petcam.sh` (cron) | always-on capture supervisor: 720p@1 fps → 480p HLS + 1 fps still in `/dev/shm/petcam`; relaunches dead pipelines (60 s backoff if it flaps), logs to `~/petcam/logs/` |
| `petcam-static.service` | **Tom**, `/etc/systemd/system/` | `python3 -m http.server 8081 --bind 100.77.132.110 --directory /dev/shm/petcam` — tailnet only, not nginx, no Go, no model (bind is scheduled to become `192.168.1.24`, Ralph-only: `../security/todo/lan-trust-2026-11-08.md` §5) |
| `petcam-detect.py` | **Ralph**, `~/projects/homelab/scripts/`, unit `petcam-detect` | 5 s loop: fetch the still → movement diff → YOLOv8n (2-class: pancake/willow) → shots + log + training pairs in `~/petcam` |
| `petcam` (app) | **Ralph**, `~/projects/homelab/petcam/`, unit `petcam` | standalone Go binary (stdlib only, templates embedded): gallery `/`, `/live`, `/log`, `/label`, `/review`; binds **loopback** `127.0.0.1:8082` (8080 is the website) |
| nginx | **Ralph**, `/etc/nginx/conf.d/petcam.conf` | `petcam.andrewahale.com`: `/hls/` → Tom, everything else → `127.0.0.1:8082`; adds `Cache-Control: no-store` for the playlist |
| state | **Ralph**, `~/petcam/` | 129M: `shots/`, `tolabel/`, `training/`, `model/yolov8n.onnx`, `detections.log` |

Ralph is the tunnel's only origin; the browser pulls HLS segments straight from
Tom over the tailnet, so a Tom outage kills `/live` (502) while the gallery keeps
working.

## Access

`petcam.andrewahale.com` is behind **Cloudflare Access** (email OTP, one address,
24 h session). The origin binds loopback, so the tunnel is the only way in.

## Rebuild

### Tom — capture + static files (~10 min on a fresh SD card)

1. `sudo apt install ffmpeg` (`rpicam-apps` ships with Raspberry Pi OS). Nothing
   else — no Go, no `python3-opencv`, no numpy, no model.
2. Clone this repo to `~/projects/homelab`, add the capture cron lines from
   [`crontab.txt`](crontab.txt) (`petcam.sh` runs from the repo in place).
3. `sudo install -m644 petcam/petcam-static.service /etc/systemd/system/ &&
   sudo systemctl enable --now petcam-static`.
4. `tailscale up` — the unit binds `100.77.132.110` and `After=tailscaled.service`
   is already in it. Check: `curl -sI http://100.77.132.110:8081/frames/latest.jpg`
   → 200.

### Ralph — detector, app, state

1. `sudo pacman -S python-opencv python-numpy nginx go`.
2. State: `~/petcam/` (129M) — copy it or rebuild it; the model is the only part
   that cannot be regenerated cheaply.
3. Model: `~/petcam/model/yolov8n.onnx` (not in git). The detector auto-detects
   COCO-84, 1-class or 2-class outputs.
4. App: `cd ~/projects/homelab/petcam && make`, then
   `sudo install -m644 petcam.service /etc/systemd/system/ &&
   sudo systemctl enable --now petcam`. `BIND`/`PORT` (loopback, 8082) live in the
   unit.
5. Detector: `sudo install -m644 petcam/petcam-detect.service /etc/systemd/system/
   && sudo systemctl enable --now petcam-detect`.
6. nginx + tunnel: `docs/ralph/nginx-ralph.conf`, `docs/ralph/cloudflared-config.yaml`,
   per `../ralph/README.md`. `nginx-site.conf` here is historical (Tom used to
   serve `/jf/` and `/bt/`).

## Verify

```bash
# Tom: still + playlist on the tailnet only; pipeline alive
curl -sI http://100.77.132.110:8081/frames/latest.jpg       # 200, ~100 KB
curl -s  http://100.77.132.110:8081/index.m3u8 | head -3
ssh tom 'pgrep -af "petca[m].sh$|rpicam-vid|ffmpeg" | wc -l'  # 3

# Ralph: detector + app
python3 ~/projects/homelab/scripts/petcam-detect.py --selftest
python3 ~/projects/homelab/scripts/petcam-detect.py --once && tail -3 ~/petcam/detections.log
curl -s http://127.0.0.1:8082/shots.json | head -c 200

# Ralph: through nginx (the tunnel's origin) — 200 each, no-store on the playlist
for p in / /live /log /label /review /shots.json /hls/index.m3u8; do
  printf '%-16s %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' \
    -H 'Host: petcam.andrewahale.com' http://127.0.0.1$p)"
done
```

Failure modes are deliberate: kill `petcam-static` and `/hls/` 502s instantly
while the gallery loads; kill the capture cron and `petcam.sh` is back within
2 min; restart `petcam`/`petcam-detect` on Ralph and they come back via systemd.

## Data contract

- **Shots**: `~/petcam/shots/YYYY-MM-DD_HH-MM-SS_<cat>.jpg` — the filename is the
  whole gallery contract (timestamp + label). The detector keeps the newest
  `KEEP_SHOTS` (20) on disk; the gallery shows the newest 10, and deleting one on
  the page backfills from the pool instead of losing history. **Deleting a
  snapshot means "not a cat"** — it also marks the matching training pair a
  verified negative, so FP cleanup teaches the next retrain (skipped when a
  sibling snapshot of the frame survives). Saves are rate-limited by
  `SAVE_COOLDOWN_S` (120 s) so one trigger cannot flood the feed.
- **Log**: `~/petcam/detections.log` — one line per pass (scan scores vs
  threshold, classifier fracs vs thresholds, saved/updated). Rolling 2-week
  window; `/log` shows it newest-first, 200/page.
- **Training data**: `~/petcam/training/` = YOLO pairs (`images/` + `labels/`),
  class `0 = pancake`, `1 = willow`. Confident detections auto-save pairs;
  near-misses queue in `~/petcam/tolabel/` for hand-labeling.
- **Labeling on `/label`**: *save* needs an explicit cat (`cat=pancake|willow`,
  server-enforced) and writes an approved box; *reject* saves the frame as a
  negative (empty label); *delete* removes corrupt frames entirely. `/live` has a
  **Capture** button that snapshots the current still, runs YOLO and queues it.
- **`/review`** audits the corpus before a retrain: every pair with box, class and
  per-box colour stats; actions flip the class, remove a box, mark negative,
  delete, or mark reviewed. `training/reviewed.txt` records what the owner
  verified, and `train-model.sh` trains **only** on verified pairs —
  `/label`-named pairs, `_neg` rejects and reviewed stems. Colour-flag
  disagreements sort first (advisory only, a hint never sets a label); stats are
  cached in `training/review-stats.json`, invalidated per frame by mtime.
- `--checknames` regression-checks the legacy hue classifier over the named
  corpus; `--selftest` covers classifier + label math + the empty frame.

## Knobs

Top of `petcam.sh`: capture/stream resolution, fps, bitrates.
Top of `petcam-detect.py`: `STILL` (Tom's still URL), `STILL_TIMEOUT_S`,
`MIN_CONF`, `MOTION_*`, `HEARTBEAT_S`, `KEEP_SHOTS`, `SAVE_COOLDOWN_S`,
`LOG_KEEP_DAYS`, `HARVEST_SAMPLING_RATE`.
`ORANGE_*`/`GRAY_MAX_SAT`/`ORANGE_FRAC` drive the hue classifier: naming comes
from the 2-class model when a fine-tune is loaded, else the hue classifier (which
names COCO cats as pancake/willow).

## Model

Live: a 2-class `yolov8n` fine-tune, trained only on `/review`-verified labels.
Measured on days it never trained on, naming accuracy is **61%**, a cleanly
retrained model scores 47% (the hardest scene exists only on the test days), and
zero-shot `typesafe/jev-1.14` scored **95%** — not significantly better than the
deployed model (p = 0.18). Decision: **YOLO stays the live detector and namer;
Jev is an audit tool only**, no cascade. Numbers, frozen test days and the
benchmark procedure: [`complete/yolo-jev-heldout-2026-11-08.md`](complete/yolo-jev-heldout-2026-11-08.md).

Training runs on **Jason** (RTX 3070), never on Tom or Ralph.

```bash
ssh jason
cd ~/projects/homelab && EPOCHS=100 scripts/train-model.sh
```

- Pulls pairs via rsync (drops 0-byte / orphan pairs), 80/20 deterministic split,
  fine-tunes at `imgsz=640`, exports ONNX, pushes to `~/petcam/model/yolov8n.onnx`
  on Ralph (previous kept as `.bak`), restarts the detector.
- Trigger: after the `/label` queue is worked through and misses remain, or
  `--checknames` disagrees. ~50–200 verified boxes is plenty for one camera angle.
- Quality gate (manual): score known cat + cat-free frames against `.bak`, run
  `--selftest`, watch `/log` for real detections.
- Roll back: `cp yolov8n.onnx.bak yolov8n.onnx` on Ralph, then
  `sudo systemctl restart petcam-detect`.
- Tooling: `scripts/petcam-metrics.py` (per-model naming/recall/FPR with Wilson
  CIs, exact McNemar, day-cluster bootstrap) and `scripts/petcam-jev.py` for audit
  runs (~$0.00012/frame). `petcam-detect.py --score-corpus` writes the per-frame
  YOLO/hue scores those tools compare against.

## Tom's camera fault

The 24/7 pipeline is the trigger for Tom's ~12 reboots/day: the imx708 stops
answering I²C writes on the RP1 bus, CPU 3 hard-locks, and
`kernel.panic_on_rcu_stall=1` panics + dumps rather than waiting for the watchdog.
Keep that sysctl armed. Fix order: reseat the CSI ribbon → replace it → replace
the module → USB UVC webcam (takes RP1 I²C out of the path). Evidence and triage:
[`../server/todo/tom-reboots-hang-2026-10-31.md`](../server/todo/tom-reboots-hang-2026-10-31.md)
and [`../server/README.md`](../server/README.md).

History: `complete/` — the split from the website binary, the move to Ralph, the
classifier and retrain lineage, the throttle/FP/gallery changes, and the camera
reboot investigations.
