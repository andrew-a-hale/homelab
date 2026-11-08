# Pet Cam — from-scratch rebuild

Everything needed to rebuild the pet cam on a wiped Pi: the app, the capture
and detector scripts, the unit, and the config references. All of it is in this
repo (`petcam/` + `scripts/`). The website source has its own repo
(`git@github.com:andrew-a-hale/andrewahale.com.git`) — everything else is here.

Petcam used to be one file inside the website binary; since 2026-11-07 it is a
standalone app, so a petcam change cannot break the public site build
([`complete/standalone-app-2026-11-07.md`](complete/standalone-app-2026-11-07.md)).

## What runs where

| Piece | Where | Notes |
|---|---|---|
| `petcam.sh` | `~/projects/homelab/scripts/petcam.sh` | always-on capture supervisor: 720p@1fps capture → 480p HLS stream + 1fps still; relaunches dead pipeline (60 s backoff if it flaps), logs to `~/petcam/logs/` |
| `petcam-detect.py` | `~/projects/homelab/scripts/petcam-detect.py` | 5 s loop, multi-pass: movement diff → YOLOv8n (2-class: pancake/willow), writes shots + log |
| `petcam` (app) | `~/projects/homelab/petcam/` → `/etc/systemd/system/petcam.service` | standalone Go binary (stdlib only, templates embedded), gallery `/`, `/live`, `/log`, `/label`, `/review`; binds **tailnet only** `100.77.132.110:8080` |
| nginx (Ralph) | `/etc/nginx/conf.d/petcam.conf` | `petcam.andrewahale.com` → `100.77.132.110:8080`; the tunnel points at Ralph nginx, so Tom runs **no** web server |
| cron | see `crontab.txt` | capture + detector `@reboot` + 2-min watchdogs (the app is a systemd unit now) |

## Rebuild steps

1. **Packages**: `sudo apt install ffmpeg python3-opencv python3-numpy`
   (`rpicam-apps` ships with Raspberry Pi OS). Install Go (tarball to
   `/usr/local/go` — the website builds with it).
2. **cloudflared**: binary at `/usr/local/bin/cloudflared`, then
   `cloudflared tunnel login` (writes `cert.pem`) and either reuse tunnel ID
   `5b7e3976-7429-495d-beee-45d5213a0798` or `cloudflared tunnel create andrewahale`.
   Copy `cloudflared-config.yaml` → `~/.cloudflared/config.yaml`.
   **Secrets never live in this repo**: `cert.pem` and the tunnel credentials
   JSON are recreated by `cloudflared tunnel login` / `create`.
   DNS: `cloudflared tunnel route dns andrewahale <hostname>` for each ingress
   hostname. Edge setup (Access on `petcam.andrewahale.com`) is in
   `docs/website/README.md`.
3. **Petcam app**: `git clone git@github.com:andrew-a-hale/homelab.git
   ~/projects/homelab && cd ~/projects/homelab/petcam && make`, then
   `cp petcam.service /etc/systemd/system/ && systemctl enable --now petcam`.
   `BIND`/`PORT` live in the unit. No nginx on Tom: Ralph proxies to the tailnet.
4. **Petcam scripts**: copy `scripts/petcam.sh` + `scripts/petcam-detect.py`
   to `~/`, `chmod +x`, then `mkdir -p ~/petcam/model ~/petcam/shots`.
5. **Model**: `~/petcam/model/yolov8n.onnx` (not in git — export it anywhere,
   e.g. Colab: `yolo export model=yolov8n.pt format=onnx imgsz=640`). The
   detector auto-detects COCO-84, 1-class, or 2-class (pancake/willow) outputs.
6. **Ralph side**: `docs/ralph/nginx-ralph.conf` → `/etc/nginx/conf.d/`, and
   the tunnel ingress in `docs/ralph/cloudflared-config.yaml`. `nginx-site.conf`
   here is historical (Tom used to serve `/jf/` and `/bt/`; both moved to Ralph).
7. **Cron**: `crontab crontab.txt` (from this folder).

## Verify

```bash
rpicam-still --list-cameras            # one imx708 (two once the NoIR lands)
python3 ~/projects/homelab/scripts/petcam-detect.py --selftest  # classifier + label math + empty-frame
curl -s http://100.77.132.110:8080/shots.json   # from Ralph; no Host header needed
curl -s http://100.77.132.110:8080/log | head
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: petcam.andrewahale.com" \
     http://127.0.0.1/            # on Ralph: through nginx, the tunnel's origin
ls /dev/shm/petcam/index.m3u8          # HLS stream alive
```

Then kill each process once: systemd revives the app, cron revives capture and
`petcam-detect.py` within 2 min.

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
- **Review filters** (2026-11-08): the review queue has all / unreviewed /
  flagged views. Flagged = a Jev disagreement (below) or a hue-vs-label
  mismatch, sorted first. Reviewing a frame (✓ reviewed, no cat, delete)
  clears its flag — the second-look queue only holds what still needs eyes.

## Stability note
The 24/7 `rpicam-vid` pipeline has been identified as the trigger for Tom's
random watchdog reboots: an `i2c_designware ... controller timed out` on the
imx708 bus stalls RCU and the hardware watchdog resets the Pi. See
`docs/petcam/complete/camera-i2c-rcu-stall-reboot-2026-10-25.md`. Mitigations
in priority order: (1) reseat the camera ribbon + verify PSU, (2) lower
`WIDTH/HEIGHT/FPS` in `petcam.sh`, (3) journald alert on i2c/RCU messages.

Action taken 2026-10-25: capture/stream framerate reduced from 10 to 1 fps
(`FPS=1`, `STREAM_FPS=1`) in `scripts/petcam.sh` (run in place from the repo);
pipeline restarted. Detection unaffected (stills remain 1 fps).

Reboots continued, so follow-up work and the durable instrumentation
(journald 5 s sync, `tom-health` cron sample, persistent
`~/petcam/logs/{rpicam,ffmpeg}.log`, supervisor `$$` fix + flap backoff) are
documented in `todo/camera-reboots-2026-10-26.md`. Remaining fix is physical
(ribbon reseat / PSU); UVC webcam is the fallback if it persists.

Diagnose a new reboot with:

```bash
journalctl -t tom-health -n 40        # throttled / ext5v / temp trend
journalctl -b -1 | grep -iE "i2c_designware|rcu_preempt|imx708"
tail -50 ~/petcam/logs/rpicam.log
```

## Knobs

Top of `petcam.sh`: capture/stream resolution, fps, bitrates.
Top of `petcam-detect.py`: `MIN_CONF`, `MOTION_*`, `HEARTBEAT_S`,
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

Training runs on the gaming rig (Jason, RTX 3070) — never PyTorch on Tom.
Full procedure in `skills/petcam-retrain/SKILL.md`.

- Data: `~/petcam/training/` on Tom (YOLO pairs; class 0 = pancake, 1 = willow).
  `~/petcam/tolabel/` holds near-miss frames queued for `/label`.
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
  `ssh tom 'python3 ~/projects/homelab/scripts/petcam-detect.py --selftest'`, watch `/log` for real
  detections.
- Roll back: `ssh tom 'cp ~/petcam/model/yolov8n.onnx.bak ~/petcam/model/yolov8n.onnx'`
  then restart the detector (bracketed pkill pattern — see skill).
- Notes: ultralytics resolves relative `project=` against its runs root, so
  paths stay absolute. Detector auto-detects COCO-84 / 1-class / 2-class
  ONNX outputs. Venv: `~/petcam-train/.venv` (Python 3.12; system 3.14 has no
  torch wheels).

### Jev second-opinion pass (2026-11-08)

`typesafe/jev-1.14` (OpenRouter Decisions API) sees images and answers typed
questions with probabilities — tried on the corpus 2026-11-08, it named every
cat frame right, including backlit silhouettes where the hue classifier fails,
and caught a mislabeled negative. Trial details in
`complete/jev-corpus-flag-2026-11-08.md`. The pieces:

- `scripts/petcam-detect.py --score-corpus [out.json]` (on Tom, where the ONNX
  lives): YOLO class/conf + hue name for every corpus frame → JSON for offline
  comparison. Read-only; never writes training or tolabel data.
- `scripts/petcam-jev.py` (anywhere with the OpenRouter key in
  `$OPENROUTER_API_KEY` or `pass dev/openrouter`): one Jev request per frame
  (noul "cat visible" + choice `pancake/willow/none` + box), writes
  `jev-scores.json` + `flags.txt`, prints a label-vs-Jev-vs-YOLO report.
  `--from-tom` rsyncs the corpus first, `--push-flags` copies flags.txt to Tom.
  ~$0.00012/frame (~2,850 input tokens, output free).
- `~/petcam/training/flags.txt` (`stem reason` per line) feeds the /review
  flagged filter; the app clears a flag when the frame is reviewed/negated/
  deleted. Regenerate flags by re-running the batch.
- Cascade shape if it goes live: YOLO keeps detection (free, local), Jev names
  the detected cat (~$0.00012 per detection — detections are a few per hour,
  not per frame).
