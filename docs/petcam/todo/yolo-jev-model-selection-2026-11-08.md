# YOLO vs Jev: a fair experiment (model selection) — planned 2026-11-08

The 2026-11-08 corpus audit (see `../complete/jev-corpus-flag-2026-11-08.md`)
compared models unfairly: YOLO's 93% naming was measured on its own training
data (resubstitution accuracy — optimistic if the model overfits), while Jev
scored 85% zero-shot on the same frames. The owner's flag-queue review does not
fix this: the flag queue is *by construction* the set where Jev disagreed with
the label, so "Jev was wrong on every flagged frame" just means the labels
survived the audit — it measures label quality, not model ranking.

## Why it matters here

The detector's auto-labels feed the next retrain (a feedback loop): if the
deployed model overfits or drifts, its errors compound into future training
data with nothing to catch them. A held-out benchmark is the tripwire.

## Design (standard model selection, adapted to this corpus)

1. **Metrics** (decided now, before looking at test data):
   - naming: per-frame accuracy on cat-present frames vs the verified label,
   - detection recall on cat-present frames, presence false-positive rate on
     verified negatives (for YOLO at MIN_CONF=0.3),
   - reported with Wilson 95% CIs; paired model comparisons get McNemar's
     exact test on the same test frames; the day-clustered bootstrap gives the
     CI for the difference (frames within a day are correlated).
2. **Split: by calendar day, not by frame.** Random splits leak near-duplicates
   (the same cat, pose and lighting seconds apart) into both sides — the
   existing 80/20 random split (val mAP50 0.77) and the val set used at
   training time both have this problem. Hold out ~20% of days as test; train
   on the rest. The test days stay frozen and get re-used after every retrain.
3. **Retrain** yolov8n on train-days only (Jason, `train-model.sh` variant
   that takes the split; EPOCHS=100 as usual). The currently deployed model
   has no clean held-out set (it trained on ~all verified pairs), so the fair
   comparison needs this retrain.
4. **Evaluate on test days only**: retrained YOLO, deployed YOLO (for drift),
   hue classifier (comes free from `--score-corpus`), and Jev
   (`petcam-jev.py --stems …` restricted to test frames, ~$0.01).
5. **Decision rule**: switch the naming stage only if the challenger beats
   YOLO with statistical significance; otherwise YOLO wins ties on cost and
   latency (free + local vs $0.00012/request + network). Either way the
   benchmark stays as the regression check for future retrains.

## Steps

- [ ] Pick the test days (deterministic: e.g. every 5th day of the corpus span)
- [ ] Add a split option to `train-model.sh` (train on N-1 day groups)
- [ ] Retrain on Jason; export ONNX
- [ ] Score test days with all four models; compute metrics + tests
- [ ] Write up the result in `../complete/` and decide

n is the honest limitation: ~206 cat frames total → ~40 in test → CIs around
±10pp. Fine for rejecting large claims; not fine for 2–3pp differences. The
corpus grows every day, so the benchmark sharpens with use.
