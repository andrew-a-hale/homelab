# Model reset 2026-10-28 — back to base yolov8n, corpus wiped, fresh start

Follows `retrain-2026-10-27.md`. The user felt the retrained model had
regressed (rollback to `.bak` was done first), and chose to go back to the
default YOLO model and delete the labeled images to start again.

## What changed

- **Model**: base `yolov8n` (COCO) exported ONNX (`imgsz=640`) replaces the
  fine-tune at `~/petcam/model/yolov8n.onnx`. The fine-tune is preserved at
  `~/petcam/model/yolov8n.onnx.bak`.
- **Corpus**: `~/petcam/training/{images,labels}/` on Tom wiped (1492 pairs).
  Archived on Jason: `~/petcam-train/archive/training-2026-10-28/` (183M).
  Collection re-starts from zero (auto-labeled confident detections + `/label`
  queue for near-misses).
- **Naming**: `petcam-detect.py` now names detections via the hue classifier
  when the model has no pancake/willow classes (COCO base). Without this, every
  shot would be labeled "cat" and new training pairs would be written as
  class 0 (pancake) — corrupting the fresh corpus.

## Decision + caveat

The user explicitly chose the base model and a clean slate. **But measured on
60 archived known-cat frames, base yolov8n detects only 7 (12%)** — it is
near-blind to small/curled cats in this wide indoor frame; the fine-tune hit
~90%+ on the same kind of frames. Expect many missed detections and a sparse
gallery until a fine-tune is trained again.

Options kept open:

1. Stay on base now, retrain once ~50–200 fresh boxes exist (the standard
   loop). Names still work meanwhile (hue classifier).
2. Restore the known-good fine-tune now
   (`cp ~/petcam/model/yolov8n.onnx.bak ~/petcam/model/yolov8n.onnx` + restart
   the detector) and keep collecting fresh data for the next retrain.
3. Wipe-free redo: retrain from the archived corpus if the wipe is reconsidered.

## Verification

- `--selftest` ok on Tom after the swap (detector pid verified single).
- COCO decode path + hue naming verified against archived frames:
  `pancake(cls=15)` on a confident frame; `top=0.00–0.02` live scans on an
  empty scene are expected.
