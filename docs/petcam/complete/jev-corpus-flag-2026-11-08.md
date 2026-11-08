# Jev second-opinion pass over the petcam corpus (2026-11-08)

**Decision:** Jev (`typesafe/jev-1.14` via OpenRouter's Decisions API) joins the
petcam as a *corpus auditor*, not a live detector. A batch pass flags training
frames whose label disagrees with Jev into the `/review` flagged filter. The
live pipeline keeps YOLO for detection; if we ever wire Jev into the live path,
it is as the naming stage behind YOLO (~$0.00012 per detection, not per frame).

## What shipped

- **`/review` filters**: all / unreviewed / flagged. Flagged = a Jev
  disagreement or a hue-vs-label mismatch, sorted first, with the Jev reason
  shown inline (`⚑ jev=willow on a negative frame p=0.11/0.52/0.37`). Marking a
  frame reviewed / negative / deleted clears its flag.
- **`~/petcam/training/flags.txt`** (`stem reason` per line) — written by the
  batch, read by the app.
- **`scripts/petcam-jev.py`** — one Jev request per frame (noul "cat visible" +
  choice `pancake/willow/none` + box, all sharing one image), writes
  `jev-scores.json` + `flags.txt`, prints the comparison report.
  `--from-tom` rsyncs the corpus, `--push-flags` copies flags.txt to Tom.
- **`scripts/petcam-detect.py --score-corpus [out.json] [img_dir]`** — YOLO
  class/conf + hue name for every corpus frame → JSON. Runs on Tom (default) or
  anywhere with `PETCAM_MODEL` pointing at a copy of the ONNX (Tom resets
  hourly-ish; the local laptop run is what survived).

## The numbers (622-frame corpus, 2026-11-08)

Ground truth is the corpus label itself, so "right" means "agrees with the
label" — and spot-checks show some labels are wrong (that is the point of the
flag queue). YOLO's naming score is partly circular: the 2-class fine-tune was
trained on these labels.

| Measure | Result |
|---|---|
| YOLO detects a labeled cat frame | 184/206 (89%) |
| Jev presence (noul > 0.5) on the same | 196/206 (95%) |
| Jev names a cat on YOLO's 22 detection misses | 21/22 |
| Naming, frames where both named (179): YOLO / Jev / hue | 93% / 85% / 79% |
| YOLO–Jev agreement when both name | 148/179 (83%) |
| On their 31 naming disagreements, label sides with | YOLO 23, Jev 8 |
| Flags pushed to `/review` | 94 |
| Spot-checked flags | 1 label error caught (orange cat labeled willow), 1 Jev over-call (garden ornament, correctly left to human eyes) |

## Cost

| Scenario | Cost |
|---|---|
| Corpus audit (622 frames, one pass) | $0.074 (~$0.00012/frame, ~2,850 input tokens, output free) |
| Per-detection live use (YOLO gates, Jev names) | ~134 detections/day avg over 14 days (4–435 range) → **~$0.02/day, ~$0.50/month** |
| Every 1 fps frame (rejected) | ~$10/day (~$310/month) |

## The lesson worth keeping

The first full run scored Jev at 33% — because the question descriptions had
pancake and willow's coats **inverted** ("Pancake: the grey cat"). Jev follows
the descriptions literally, so it answered colors, not identities. The trial's
clean-looking results on backlit silhouettes were coincidence (a grey-looking
silhouette matched the wrong "grey = pancake"). Ground truth for the coats came
from the detector's own calibration notes (orange fraction 0.27–0.75 → pancake)
and the hand-labeled `manual_willow` frames (willow is the grey/brown tabby).
After fixing the descriptions: 82% overall, 85% on the both-named subset. Rule:
describe the referents precisely and verify a description against ground truth
before trusting a batch result.

## Where this leaves us

- The 94 flags are the current second-review queue at `/review` (flagged
  filter). Working through them feeds the next retrain with cleaner labels.
- YOLO remains the detector. Its 93% naming beats Jev's 85% on the current
  labels, but it learned those labels — Jev is the independent second opinion,
  and it also covers 21 of YOLO's 22 detection misses.
- Re-run the audit after the next retrain (or any corpus clean-up):
  `scripts/petcam-jev.py --from-tom --yolo-scores … --push-flags`.
