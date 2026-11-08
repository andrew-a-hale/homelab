# YOLO vs Jev held-out experiment — run 2026-11-08

Planned in the same-named todo (moved here on completion). The 2026-11-08
corpus audit compared models unfairly: YOLO's 93% naming was measured on its
own training data (resubstitution), Jev scored 85% zero-shot. This run answers
"does YOLO actually generalize?" with a standard model-selection design:
frozen test days, a clean retrain, Wilson CIs, exact McNemar, day-cluster
bootstrap.

## Design (as executed)

- **Test days frozen 2026-11-08**: every 4th day of the sorted corpus span
  (indices 3, 7, 11 of 12 days) = **2026-10-31, 2026-11-05, 2026-11-08** —
  132 frames: 57 cat-present (50 pancake / 7 willow), 75 verified negatives.
  These days never train; reused after every retrain (see
  `scripts/petcam-metrics.py` `TEST_DAYS`).
- **Challenger retrain**: `HOLDOUT_DAYS=2026-10-31,2026-11-05,2026-11-08
  VAL_DAYS=2026-10-30,2026-11-04 RUN=petcam-heldout EPOCHS=100
  scripts/train-model.sh` on Jason (RTX 3070, ~13 min). 431 train-day pairs,
  day-grouped val (60 images). Val: mAP50 0.985, P 0.995, R 0.88 — **but val
  held 0 willow instances** (both val days are pancake-heavy), so willow was
  unmeasured at train time. Nothing deployed; weights at
  `~/petcam-train/runs/petcam-heldout/` on Jason.
- **Scorers** on the frozen frames only: deployed YOLO (md5-verified against
  Tom's), retrained YOLO, hue classifier (from the same score-corpus pass),
  Jev zero-shot (`petcam-jev.py --stems`, $0.0157 for 131 frames + $0.0001 for
  one frame added later — **$0.00012/frame, $119.6 per M frames**).
- `scripts/petcam-metrics.py` computes the table below from the score JSONs.

## Results (132 frozen test frames)

| model | naming (cat frames) | recall | neg FPR |
|---|---|---|---|
| deployed YOLO | 49/57 = 86% [75%, 93%] | 88% | 14/75 = 19% |
| retrained YOLO | 27/57 = 47% [35%, 60%] | 72% | 1/75 = 1% |
| hue | 36/57 = 63% [50%, 74%] | 100%* | 28/75 = 37% |
| Jev (zero-shot) | 54/57 = 95% [86%, 98%] | 96% | 13/75 = 16% |

\* hue only scores when YOLO produced a box, so its recall is YOLO's.

Naming by day (the contamination check):

| day | deployed | retrained | hue | Jev |
|---|---|---|---|---|
| 2026-10-31 | 38/39 | 27/39 | 18/39 | 38/39 |
| 2026-11-05 | 10/17 | 0/17 | 17/17 | 16/17 |
| 2026-11-08 | 1/1 | 0/1 | 1/1 | 0/1 |

Paired McNemar (naming): deployed beats retrained by +39pp (p < 0.001) and hue
by +23pp (p = 0.019); Jev beats retrained by +47pp (p < 0.001) and hue by
+32pp (p < 0.001). **Jev vs deployed: +9pp, p = 0.18 — not significant.** On
the honest subset (11-05 + 11-08, the days deployed never trained on, n = 18):
deployed 61%, Jev 89%, p = 0.18 again (n too small: 7 vs 2 discordant pairs).

## What it means

1. **The user's suspicion was right.** YOLO's 93% corpus naming is
   resubstitution: on the days it never trained on, the deployed model scores
   **61%** (n = 18, CI roughly ±20pp). Its 38/39 on 10-31 is memorized: every
   retrain round through 11-02 included those frames.
2. **But the corpus is scene-clustered, which cuts the other way.** The
   hardest scene in the corpus — pancake backlit on the cactus-tree top —
   exists only on 10-31 and 11-05, both test days. The cleanly retrained model
   never saw it and goes 0/17 on 11-05 (calls backlit pancake "willow", or
   nothing at all). The deployed model only handles 11-05 because it trained
   on 10-31's near-identical frames. So the retrained 47% is a harsh lower
   bound on a clean model, and the deployed 61% honest number is itself
   flattered by cross-day scene similarity. Random-split val (mAP50 0.985
   here, 0.77 before) sits at the leaky-easy end; day-split at the
   no-leakage-hard end; production truth is in between, closer to the
   deployed model's number because training keeps absorbing new days within
   a day or two (the auto-label feedback loop).
3. **Model selection (pre-registered rule: switch only on significance):**
   Jev is ahead everywhere — 95% vs 86% naming overall, 96% vs 88% presence
   recall, 16% vs 19% FPR — but not significantly vs the deployed model
   (p = 0.18). Ties go to YOLO on cost and latency. **Decision: keep deployed
   YOLO as the live detector + namer; Jev stays an offline audit tool.** The
   Jev-ahead signal is worth re-testing as the corpus grows (each doubling of
   test-day n tightens the CIs by ~1/√2).
4. **YOLO-filter + Jev-namer cascade: rejected.** End-to-end 82% naming —
   worse than deployed YOLO alone (86%) and far worse than Jev alone (95%):
   YOLO's detector drops 7 of 57 cat frames (Jev names all 7 right) and YOLO's
   naming on the frames it does detect is already strong. Filtering loses
   Jev's edge before naming starts. It does cut FPR (19% → 8%: Jev rejects
   half of YOLO's false positives), but at a real recall cost — not worth it.
5. **Cost**: Jev is $0.00012/frame ($119.6/M). As the audit tool over a day's
   corpus (~134 detections/day → ~$0.50/month): fine. Per-frame at 1 fps:
   ~$310/month: rejected, unchanged.

## Benchmark for future retrains

The frozen test days + `scripts/petcam-metrics.py` are now the regression
check. After any retrain: score the test days (`petcam-detect.py
--score-corpus` with `PETCAM_MODEL` pointed at the candidate weights, or run
the scorer on Jason and copy the JSON back) and run:

```
python3 scripts/petcam-metrics.py \
  --labels <corpus>/labels --stems test-stems.txt \
  --model deployed=<deployed-scores.json> --model candidate=<candidate.json> \
  --hue hue=<deployed-scores.json> --jev <jev-scores.json> --json out.json
```

Gate: a candidate must not lose naming accuracy on the frozen days vs the
deployed model before it deploys. Also fix the willow gap in the benchmark:
val had 0 willow instances and test only 7 — add willow-heavy days to the
frozen set as the corpus grows (next candidates: 2026-11-02, 2026-11-06 — the
two other willow-rich days).

## Artifacts

- Scores (laptop): `.amp/in/jev-corpus-training/` (corpus + deployed scores),
  `.amp/in/heldout/` (retrained ONNX + its test scores + val summary),
  `.amp/in/jev-test-heldout/jev-scores.json`, `.amp/in/metrics-final.json`.
- Jason: `~/petcam-train/runs/petcam-heldout/weights/{best.pt,best.onnx}`,
  `~/petcam-train/test-stems.txt`.
- Willow note for the next retrain: the only two naming errors Jev makes on
  the frozen days are an 11-05 early-morning frame and an 11-08 frame; the
  deployed model's 11-05 misses are all backlit pancake.

## Decision record

- Keep YOLO as live detector and namer (significance rule not met; challenger
  not deployable). Update the README's Jev section and retire the plan todo.
- Keep Jev as audit-only. Revisit the comparison when the corpus has grown
  ~2× on the frozen metrics; if Jev's edge becomes significant, revisit the
  cascade with a Jev-presence gate instead of YOLO's detector.
