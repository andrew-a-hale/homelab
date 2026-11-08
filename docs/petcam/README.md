# Pet Cam — from-scratch rebuild

Two boxes, one pet cam since 2026-11-08: **Tom** is a camera appliance (capture
plus a static file server) and **Ralph** holds every stateful part (detector,
app, gallery, training corpus). See
[`complete/tom-camera-appliance-2026-11-08.md`](complete/tom-camera-appliance-2026-11-08.md)
for the why, the measurements and the rollback.

Everything needed to rebuild it is in this repo (`petcam/` + `scripts/`). The
website source has its own repo (`git@github.com:andrew-a-hale/andrewahale.com.git`)
— everything else is here. Petcam used to be one file inside the website binary;
since 2026-11-07 it is a standalone app, so a petcam change cannot break the
public site build
([`complete/standalone-app-2026-11-07.md`](complete/standalone-app-2026-11-07.md)).

## What runs where

| Piece | Where | Notes |
|---|---|---|
| `petcam.sh` | **Tom**, `~/projects/homelab/scripts/petcam.sh` | always-on capture supervisor: 720p@1fps capture → 480p HLS + 1fps still in `/dev/shm/petcam`; relaunches dead pipelines (60 s backoff if it flaps), logs to `~/petcam/logs/`. Byte-identical since before the split |
| `petcam-static.service` | **Tom**, `/etc/systemd/system/` | `python3 -m http.server 8081 --bind 100.77.132.110 --directory /dev/shm/petcam`. Tailnet only. No Go, no python packages, no model |
| `petcam-detect.py` | **Ralph**, `~/projects/homelab/scripts/` | 5 s loop, multi-pass: fetch the still over HTTP → movement diff → YOLOv8n (2-class: pancake/willow) → shots + log + training pairs in `~/petcam` |
| `petcam-detect.service` | **Ralph**, `/etc/systemd/system/` | `Restart=always` (Ralph has no cron — this replaces the 2-min watchdog) |
| `petcam` (app) | **Ralph**, `~/projects/homelab/petcam/` → `petcam.service` | standalone Go binary (stdlib only, templates embedded), gallery `/`, `/live`, `/log`, `/label`, `/review`; binds **loopback** `127.0.0.1:8082` (8080 is the website app) |
| nginx | **Ralph**, `/etc/nginx/conf.d/petcam.conf` | `petcam.andrewahale.com`: `location /hls/` → `100.77.132.110:8081/` (Tom, with `Cache-Control: no-store` added), everything else → `127.0.0.1:8082`. Ralph is the tunnel's only origin |
| state | **Ralph**, `~/petcam/` | 129M: `shots/`, `tolabel/`, `training/`, `model/yolov8n.onnx`, `detections.log` |
| cron | **Tom**, see [`crontab.txt`](crontab.txt) | capture `@reboot` + 2-min watchdog, health sample. No detector lines any more |

## Rebuild steps

### Tom — capture + static files (~10 minutes on a fresh SD card)

1. **Packages**: `sudo apt install ffmpeg` (`rpicam-apps` ships with Raspberry Pi
   OS). Nothing else — no Go toolchain, no `python3-opencv`, no numpy, no model.
2. **Capture**: clone this repo to `~/projects/homelab`, then the capture cron
   lines from `crontab.txt` (`petcam.sh` runs from the repo in place).
3. **Static server**: `sudo install -m644 petcam/petcam-static.service
   /etc/systemd/system/ && sudo systemctl enable --now petcam-static`.
4. **Tailnet**: `tailscale up`; the unit binds `100.77.132.110` specifically, so
   it needs `tailscaled` up (`After=tailscaled.service` is already in the unit).
   Check: `curl -sI http://100.77.132.110:8081/frames/latest.jpg` → 200.

### Ralph — detector, app, state

1. **Packages**: `sudo pacman -S python-opencv python-numpy nginx go`
   (OpenCV DNN + numpy for the detector, Go for the app). Guix is not needed.
2. **State**: worth backing up off-box — `rsync -a tom:~/petcam/ ~/petcam/`
   (129M: shots, tolabel, training, model, log; see the complete/ doc for why a
   tar pipe through a third host may be needed when SSH between them is
   restricted by the tailnet ACL).
3. **Model**: `~/petcam/model/yolov8n.onnx` (not in git — export it anywhere,
   e.g. Colab: `yolo export model=yolov8n.pt format=onnx imgsz=640`). The
   detector auto-detects COCO-84, 1-class, or 2-class (pancake/willow) outputs.
4. **App**: `git clone git@github.com:andrew-a-hale/homelab.git
   ~/projects/homelab && cd ~/projects/homelab/petcam && make`, then
   `sudo install -m644 petcam.service /etc/systemd/system/ && sudo systemctl
   enable --now petcam`. `BIND`/`PORT` (loopback, 8082) live in the unit.
5. **Detector**: `sudo install -m644 petcam/petcam-detect.service
   /etc/systemd/system/ && sudo systemctl enable --now petcam-detect`.
6. **nginx**: `docs/ralph/nginx-ralph.conf` → `/etc/nginx/conf.d/` (it contains
   `00-upgrade-map.conf`, `ralph.conf` and the petcam server block), plus the
   tunnel ingress in `docs/ralph/cloudflared-config.yaml` and cloudflared itself
   per `docs/ralph/README.md`. `nginx-site.conf` here is historical (Tom used to
   serve `/jf/` and `/bt/`; both moved to Ralph). Petcam has no server of its own
   on Tom: the tailnet static server is the only thing there.

## Verify

```bash
# Tom: still + playlist served on the tailnet only
curl -sI http://100.77.132.110:8081/frames/latest.jpg      # 200, ~100 KB
curl -s  http://100.77.132.110:8081/index.m3u8 | head -3
# Tom: camera pipeline alive
ssh tom 'pgrep -af "petca[m].sh$|rpicam-vid|ffmpeg" | wc -l'   # 3

# Ralph: detector + app
python3 ~/projects/homelab/scripts/petcam-detect.py --selftest   # classifier + label math
python3 ~/projects/homelab/scripts/petcam-detect.py --once && tail -3 ~/petcam/detections.log
curl -s http://127.0.0.1:8082/shots.json | head -c 200

# Ralph: through nginx, the tunnel's origin — 200 each, and no-store on the playlist
for p in / /live /log /label /review /shots.json /hls/index.m3u8; do
  printf '%-16s %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' \
    -H 'Host: petcam.andrewahale.com' http://127.0.0.1$p)"
done
```

Then kill each process once: `systemctl restart petcam` / `petcam-detect` on
Ralph, and the capture cron on Tom revives `petcam.sh` within 2 min. Kill Tom's
static server to check the failure mode: `/hls/` should 502 instantly and the
gallery should still load.

## Data contract

- Shots: `~/petcam/shots/YYYY-MM-DD_HH-MM-SS_<cat>.jpg` — the filename is the
  whole gallery contract (timestamp + label). The detector keeps the newest 20
  on disk (`KEEP_SHOTS`, 2026-11-03: was newest-1-per-cat); the gallery shows
  the newest 10, and a manual delete on the page backfills the view from the
  pool instead of losing history. **Deleting a snapshot means "not a cat"** —
  it also marks the matching training pair a verified negative, so FP cleanup
  teaches the next retrain (skipped when a sibling snapshot of the frame
  survives). Saves are rate-limited by `SAVE_COOLDOWN_S` (120 s) so one firing
  trigger cannot flood the feed.
- Log: `~/petcam/detections.log` — one timestamped line per processing pass
  (scan scores vs threshold, classifier fracs vs thresholds, saved/updated latest).
  Rolling 2-week window. `/log` shows it newest-first, 200 lines/page.
- Throttle: removed. A detection now always saves a snapshot;
  `KEEP_SHOTS=20` bounds storage and the gallery window. (Historical:
  `/dev/shm/petcam/throttle.json` and the web app's reset-on-delete are no
  longer used.)
- Training data: `~/petcam/training/` contains YOLO pairs (`images/` + `labels/`).
  Labels use class `0 = pancake`, `1 = willow`. Auto-saved confident detections
  are written by the detector; near-miss frames queue in `~/petcam/tolabel/` for
  hand-labeling on the site at `/label`. Auto-labels come from the hue
  classifier while a base COCO model is deployed — hue breaks under lighting
  (backlit pancake reads gray; warm lamps read willow orange), so those labels
  are suggestions until verified at `/review`.
- Labeling actions on `/label`:
  - **save** requires an explicit cat (`cat=pancake|willow`, server-enforced) and
    writes an approved box to training with that class id; the name travels in
    the filename. "save · suggested name" applies the displayed suggestion —
    which is a colour hint, not a decision.
  - **reject** saves the frame as a **negative** (empty label file) so YOLO
    learns "no cat here".
  - **delete** removes corrupt/error frames entirely (no training entry).
  - `/live` has a **Capture** button that snapshots the current 1 fps still,
    runs YOLO, and queues it with a proposed box + cat name.
- `/review` audits the labeled corpus before a retrain: every pair with its box
  and class drawn, per-box colour stats, and actions to flip the class, remove a
  box, mark the frame negative, delete the pair, or mark it reviewed. Color-flag
  disagreements sort first (advisory only — the hint never sets a label).
  Colour stats are cached in `training/review-stats.json` (invalidated per
  frame by image/label mtime), so a load only decodes new or changed frames.
  `~/petcam/training/reviewed.txt` (one stem per line) records what the owner
  verified. `train-model.sh` trains **only** on verified pairs: reviewed stems,
  `/label`-named pairs, and `_neg` rejects — unverified auto-labels are dropped.
- `petcam-detect.py --checknames` regression-checks the legacy hue classifier
  over the named corpus; `--selftest` covers classifier + label math + empty frame.
- **Review filters** (2026-11-08): the review queue has all / unreviewed
  views. Hue-vs-label mismatches and audit flags sort first, and a frame can
  be pushed back into `/label` for a fresh hand label (R or the button).

## Stability note
**Proven 2026-11-08 by a kernel dump.** The 24/7 `rpicam-vid` pipeline is the
trigger for Tom's random watchdog reboots: the imx708 stops acknowledging writes
on its RP1 I2C bus (`i2c_designware ... controller timed out`, `Failed to write
reg 0x0342. error = -5`), **CPU 3 hard-locks** — it never answers the NMI
backtrace and `SMP: failed to stop secondary CPUs 3` follows — and
`panic_on_rcu_stall=1` turns that into a panic + pstore dump instead of a silent
watchdog reset. Evidence, frequency (87 boots in 7 days) and the demotions (SD
card, PSU, wifi are not implicated by the dump):
[`../server/todo/tom-reboots-hang-2026-10-31.md`](../server/todo/tom-reboots-hang-2026-10-31.md).
Earlier diagnosis:
[`complete/camera-i2c-rcu-stall-reboot-2026-10-25.md`](complete/camera-i2c-rcu-stall-reboot-2026-10-25.md).

**Fix order:** (1) reseat the CSI ribbon at both ends, (2) replace the ribbon,
(3) replace the camera module, (4) if it persists, switch to a **USB UVC
webcam**, which removes RP1 I2C from the petcam path entirely. Keep
`kernel.panic_on_rcu_stall=1` armed — it is what produces the dump.

Action taken 2026-10-25: capture/stream framerate reduced from 10 to 1 fps
(`FPS=1`, `STREAM_FPS=1`) in `scripts/petcam.sh` (run in place from the repo);
pipeline restarted. Detection unaffected (stills remain 1 fps).

Reboots continued, so follow-up work and the durable instrumentation
(journald 5 s sync, `tom-health` cron sample, persistent
`~/petcam/logs/{rpicam,ffmpeg}.log`, supervisor `$$` fix + flap backoff) are
documented in
[`complete/camera-reboots-2026-10-27.md`](complete/camera-reboots-2026-10-27.md).
Remaining fix is physical (ribbon reseat/replace, then the module); a UVC webcam
is the fallback if it persists.

Diagnose a new reboot with:

```bash
journalctl -t tom-health -n 40        # throttled / ext5v / temp trend
journalctl -b -1 | grep -iE "i2c_designware|rcu_preempt|imx708"
tail -50 ~/petcam/logs/rpicam.log
```

## Knobs

Top of `petcam.sh`: capture/stream resolution, fps, bitrates.
Top of `petcam-detect.py`: `STILL` (Tom's still URL), `STILL_TIMEOUT_S`,
`MIN_CONF`, `MOTION_*`, `HEARTBEAT_S`,
`KEEP_SHOTS`, `SAVE_COOLDOWN_S`, `LOG_KEEP_DAYS`, `HARVEST_SAMPLING_RATE`.
(No `THROTTLE_S` anymore — detections always save a snapshot.)
`ORANGE_*`/`GRAY_MAX_SAT`/`ORANGE_FRAC` drive the hue classifier: naming comes
from the 2-class model when a fine-tune is loaded, else the hue classifier
(names COCO cats as pancake/willow). `--checknames` regression-checks it.

## Model Fine Tuning

**Status 2026-11-01:** 2-class fine-tune live, trained on `/review`-verified
labels (val mAP50 0.77; on the reviewed truth it names 73/81 boxes correctly vs
the old hue pipeline's 32/81). See `complete/retrain-2026-11-01.md` and
`complete/review-ui-2026-11-01.md`. Historical: the corpus was wiped
2026-10-28 (archived on Jason at `~/petcam-train/archive/training-2026-10-28/`)
and base yolov8n (COCO) — which detects only ~12% of cat appearances on this
camera — ran while data re-accumulated. See
`complete/model-reset-base-yolo-2026-10-28.md`.

Training runs on the gaming rig (Jason, RTX 3070) — never PyTorch on Tom or
Ralph. Full procedure in `skills/petcam-retrain/SKILL.md`.

- Data: `~/petcam/training/` on **Ralph** (YOLO pairs; class 0 = pancake,
  1 = willow). `~/petcam/tolabel/` holds near-miss frames queued for `/label`.
  (Moved off Tom 2026-11-08; Tom's copy is a rollback spare for a week.)
- Trigger: after the `/label` queue is worked through and misses remain, or
  `--checknames` reports hue-classifier disagreements. ~50–200 labeled boxes is
  plenty for yolov8n on one (or a few) camera angles.
- **Verify labels at `/review` first** (2026-11-01): auto-labels carry
  colour-classifier errors, and `train-model.sh` drops any pair that is not
  human-verified (`reviewed.txt`, `/label` names, `_neg` rejects).
- Run: `cd ~/projects/homelab && EPOCHS=100 scripts/train-model.sh`
  - pulls pairs via rsync (drops 0-byte / orphan pairs),
  - 80/20 split (deterministic), fine-tunes `yolov8n` at `imgsz=640`,
  - exports ONNX, pushes to `~/petcam/model/yolov8n.onnx` (previous kept as
    `.bak`), restarts the detector.
- Quality gate (manual): score known cat + cat-free frames vs `.bak`,
  `ssh ralph 'python3 ~/projects/homelab/scripts/petcam-detect.py --selftest'`, watch `/log` for real
  detections.
- Roll back: `ssh ralph 'cp ~/petcam/model/yolov8n.onnx.bak ~/petcam/model/yolov8n.onnx'`
  then `sudo systemctl restart petcam-detect` on Ralph.
- Notes: ultralytics resolves relative `project=` against its runs root, so
  paths stay absolute. Detector auto-detects COCO-84 / 1-class / 2-class
  ONNX outputs. Venv: `~/petcam-train/.venv` (Python 3.12; system 3.14 has no
  torch wheels).

### Jev second-opinion pass (2026-11-08)

`typesafe/jev-1.14` (OpenRouter Decisions API) sees images and answers typed
questions with probabilities — audited the corpus 2026-11-08: 95% presence,
85% naming vs YOLO's 93% (label-trained) and hue's 79%. The owner then worked
the 119 flagged frames and confirmed **none** of Jev's flags: YOLO stays the
only model in the pipeline, Jev is an occasional audit tool. Full numbers,
cost and the inverted-coat-description lesson in
`complete/jev-corpus-flag-2026-11-08.md`. The pieces:

- `scripts/petcam-detect.py --score-corpus [out.json]` (on Ralph, where the ONNX
  lives): YOLO class/conf + hue name for every corpus frame → JSON for offline
  comparison. Read-only; never writes training or tolabel data.
- `scripts/petcam-jev.py` (anywhere with the OpenRouter key in
  `$OPENROUTER_API_KEY` or `pass dev/openrouter`): one Jev request per frame
  (noul "cat visible" + choice `pancake/willow/none` + box), writes
  `jev-scores.json` + `flags.txt`, prints a label-vs-Jev-vs-YOLO report.
  `--from-tom` rsyncs the corpus first (from Ralph, the state host — the flag
  kept its name), `--push-flags` copies flags.txt back.
  ~$0.00012/frame (~2,850 input tokens, output free).
- `~/petcam/training/flags.txt` (`stem reason` per line) feeds the /review
  flagged filter; the app clears a flag when the frame is reviewed/negated/
  deleted. Regenerate flags by re-running the batch.
- Cascade shape if it goes live: YOLO keeps detection (free, local), Jev names
  the detected cat (~$0.00012 per detection, ~$0.50/month at the current
  ~134 detections/day). Per-frame Jev was rejected: ~$10/day at 1 fps.
  **Retired 2026-11-08**: the owner confirmed 0 of Jev's flags were real, so
  Jev gets no live role — audit runs only (see the complete/ doc).

### Held-out benchmark (2026-11-08)

The audit's YOLO 93% was resubstitution (training-data accuracy). A fair
day-grouped experiment (frozen test days 2026-10-31 / 11-05 / 11-08, clean
retrain, Wilson CIs + exact McNemar, `scripts/petcam-metrics.py`) found:
deployed YOLO drops to **61% naming on days it never trained on**, a cleanly
retrained model scores 47% (the hardest scene exists only on test days), and
zero-shot Jev scores **95%** — ahead everywhere but not significantly vs the
deployed model (p = 0.18). Decision: **YOLO stays the live detector + namer,
Jev stays audit-only, YOLO-filter + Jev-namer cascade rejected** (82%
end-to-end, loses Jev's edge). Full numbers, design and the frozen-day
benchmark for future retrains in
[complete/yolo-jev-heldout-2026-11-08.md](complete/yolo-jev-heldout-2026-11-08.md).

- `scripts/petcam-metrics.py --labels DIR --stems test-stems.txt --model
  name=scores.json [--hue name=scores.json] --jev jev-scores.json`: per-model
  naming/recall/FPR with Wilson CIs, exact McNemar between model pairs, and
  the day-cluster bootstrap CI — the frozen-day benchmark report.
