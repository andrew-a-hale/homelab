---
name: petcam-retrain
description: >
  Retrain/fine-tune the petcam YOLO cat detector on Jason and push the
  model to Tom. Use when the user says retrain the model, fine-tune, train the
  cat detector, improve detection, push a new model, or asks when/how the model
  learns. Triggers: retrain, fine-tune, train yolo, new model, detection missing
  cats, training data, push model to the pi. Covers the label queue, the
  train-model.sh pipeline, the quality gate, and rollback.
---

# Retraining the petcam detector

> **Hosts changed 2026-11-08.** The corpus, the model and the detector live on
> **Ralph** now (`~andy/petcam`, `petcam-detect.service`), not Tom — see
> `docs/petcam/complete/tom-camera-appliance-2026-11-08.md`. In everything below,
> read `tom@…`/`ssh tom` as `ssh ralph` (alias; user **andy**, not `ralph` —
> the `ralph@ralph…` form fails with `Permission denied`), `/home/tom/…` as
> `/home/andy/…`, and restart the detector with
> `sudo systemctl restart petcam-detect.service` instead of the pkill/setsid
> lines (Tom has no detector any more).

Supervised fine-tuning with active-learning data collection. Training happens
on this rig (RTX 3070, CUDA); the Pi only runs inference. Never put PyTorch on
Tom.

## When to retrain

Deliberately manual. Trigger when the `/label` queue is worked through and real
misses remain (the curled-cat ceiling is the known one), or `--checknames`
reports hue-classifier disagreements worth fixing with data. ~50–200 labeled
boxes is plenty for yolov8n on one fixed camera angle. Training takes seconds.

## Data (already collected by the detector)

- `tom@tom.tailad1015.ts.net:~/petcam/training/{images,labels}/` — YOLO pairs (class 0 =
  pancake, class 1 = willow). Confident detections are auto-labeled by the
  2-class model; names (`_willow`/`_pancake`) may still ride in the filename
  for the legacy hue-classifier corpus. Rejected near-misses are saved as
  negatives (empty label files); corrupt frames are deleted via `/label`.
- Near-miss frames queue up in `~/petcam/tolabel/` and get labeled at
  `https://petcam.andrewahale.com/label` (approve / draw / reject, name buttons).

## Train + push

Only human-verified pairs train: label at `/label` (name travels in the
filename), verify auto-labeled frames at `https://petcam.andrewahale.com/review`
(they land in `training/reviewed.txt`), and `train-model.sh` drops everything
else — unverified colour-classifier guesses never reach training.

```bash
cd ~/projects/homelab
EPOCHS=100 scripts/train-model.sh
```

The script pulls the pairs from the Pi (rsync), splits 80/20, fine-tunes
`yolov8n` at `imgsz=640` (must match the detector's `INPUT`), exports ONNX,
pushes it to `~/petcam/model/yolov8n.onnx` (previous kept as `.bak`), and
restarts the detector. Venv: `~/petcam-train/.venv` (Python 3.12 + ultralytics;
system Python 3.14 has no torch wheels — don't).

## Quality gate (before trusting the swap)

1. Score known cat frames and a cat-free frame with the new model vs `.bak` —
   run the detector's decode via `importlib` from `petcam-detect.py` on the Pi
   (`spec_from_file_location("pd", "/home/tom/projects/homelab/scripts/petcam-detect.py")`).
   Monkeypatch `pd.harvest`/`pd.log_raw` to a no-op so A/B scoring doesn't
   pollute the tolabel queue.
2. `ssh tom@tom.tailad1015.ts.net 'python3 ~/petcam-detect.py --selftest'`
3. Watch the gallery + `/log` for a couple of real detections.

## Roll back

```bash
ssh tom@tom.tailad1015.ts.net 'cp ~/petcam/model/yolov8n.onnx.bak ~/petcam/model/yolov8n.onnx'
# then restart the detector:
ssh tom@tom.tailad1015.ts.net 'pkill -f "petcam-detect[.]py$"; sleep 1;
  setsid python3 /home/tom/projects/homelab/scripts/petcam-detect[.]py >>/tmp/petcam-detect.log 2>&1 < /dev/null &'
```

## Gotchas

- ultralytics resolves a **relative** `project=` against its own runs root and
  splatters `runs/` into whatever directory it likes (it landed in the homelab repo
  once). `train-model.sh` uses absolute paths — leave them absolute.
- Don't push a model trained on a handful of images just to test the pipeline;
  it regresses detection. The pipeline check is the run itself, not the model.
- The ONNX decoder auto-detects output shape: COCO-84 (base yolov8n), a
  1-class fine-tune, or a 2-class (pancake/willow) fine-tune. Training
  labels use class 0 = pancake, 1 = willow.
- The detector lives in the git checkout (`/home/tom/projects/homelab/scripts/petcam-detect.py`),
  not `/home/tom/` — a stale path here once killed the detector and failed to
  restart it. When the path moved (2026-10-27), this skill and `train-model.sh`
  were fixed but the website's `handleCapture` was missed until the owner hit it
  (2026-11-01) — when the path moves again, grep **both** repos (`tom` and
  `andrewahale.com`) for it. Cron re-launches it within 2 min regardless (`crontab -l` on Tom).
- Killing/restarting the detector from a command that literally contains
  `petcam-detect.py` self-matches `pkill -f`; use the bracketed pattern
  `petcam-detect[.]py` in anything on the same command line.
