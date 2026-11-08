#!/usr/bin/env python3
"""petcam-metrics.py — held-out comparison of petcam models on frozen test days.

Inputs are per-frame score files plus the corpus labels:
  yolo-format JSON  {stem: {yolo: name|null, conf, hue}}  (petcam-detect.py
                    --score-corpus; one file per YOLO model via --model)
  jev-format JSON   {stem: {choice, probs{pancake,willow,none}}} (petcam-jev.py,
                    given via --jev)
  labels dir        YOLO label files, empty = verified negative

A model "calls a cat" when its top call is pancake/willow (Jev additionally
needs max prob > 0.5). Metrics on the test frames only:
  naming      accuracy on cat-present frames vs the verified label
  recall      cat frames where the model calls a cat
  neg FPR     negative frames where the model calls a cat
Wilson 95% CIs; exact McNemar between model pairs on naming; day-cluster
bootstrap for the naming-accuracy difference (frames within a day correlate).

Usage:
  python3 scripts/petcam-metrics.py --labels .amp/in/jev-corpus-training/labels \
      --model deployed=yolo-scores.json --model retrained=retrained.json \
      --jev jev-scores.json [--stems test-stems.txt] [--days 2026-10-31,...]
"""

import argparse
import json
import math
import random
from itertools import combinations
from pathlib import Path

CATS = ("pancake", "willow")
# frozen 2026-11-08: every 4th day of the sorted corpus span (indices 3, 7, 11).
# Never train on these; reused after every retrain. See
# docs/petcam/complete/yolo-jev-heldout-2026-11-08.md.
TEST_DAYS = ("2026-10-31", "2026-11-05", "2026-11-08")
Z = 1.959963984540054
BOOT_N = 10000


def wilson(k, n):
    if n == 0:
        return None, None, None
    p = k / n
    den = 1 + Z * Z / n
    centre = (p + Z * Z / (2 * n)) / den
    half = Z * math.sqrt(p * (1 - p) / n + Z * Z / (4 * n * n)) / den
    return p, max(0.0, centre - half), min(1.0, centre + half)


def mcnemar_exact(b, c):
    """two-sided exact McNemar p-value for b/c discordant pairs."""
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    tail = sum(math.comb(n, i) for i in range(0, k + 1)) * 0.5 ** n
    return min(1.0, 2 * tail)


def load_labels(labels_dir, stems):
    out = {}
    for stem in stems:
        text = (labels_dir / (stem + ".txt")).read_text().strip()
        if not text:
            out[stem] = "none"
        else:
            cids = {int(line.split()[0]) for line in text.splitlines() if line.split()}
            out[stem] = "pancake" if 0 in cids else "willow"
    return out


def yolo_call(entry):
    """(name, confident) from a petcam-detect.py --score-corpus record."""
    if entry["yolo"] is None:  # below the deployed MIN_CONF=0.3
        return None, False
    return entry["yolo"], True


def jev_call(entry):
    """(name, confident) from a petcam-jev.py record."""
    if max(entry["probs"]["pancake"], entry["probs"]["willow"]) > 0.5:
        return entry["choice"], True
    return None, False


def hue_call(entry):
    """(name, confident) from the hue field of a score-corpus record."""
    if entry.get("hue") in CATS:
        return entry["hue"], True
    return None, False


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--labels", required=True, help="corpus labels/ dir")
    ap.add_argument("--days", default=",".join(TEST_DAYS), help="test days (frozen)")
    ap.add_argument("--stems", help="explicit stems file; overrides --days")
    ap.add_argument("--model", action="append", required=True, metavar="NAME=PATH",
                    help="yolo-format scores; repeat once per model")
    ap.add_argument("--hue", metavar="NAME=PATH",
                    help="also score the hue classifier in a yolo-format file")
    ap.add_argument("--jev", help="jev-format scores (counts as a model named jev)")
    ap.add_argument("--json", help="also write a machine-readable summary here")
    args = ap.parse_args()

    labels_dir = Path(args.labels)
    if args.stems:
        stems = [s for s in Path(args.stems).read_text().split() if s]
    else:
        days = set(args.days.split(","))
        stems = sorted(p.stem for p in labels_dir.glob("*.txt") if p.stem[:10] in days)
    label = load_labels(labels_dir, stems)

    models = {}
    for spec in args.model:
        name, _, path = spec.partition("=")
        raw = json.loads(Path(path).read_text())
        models[name] = {s: yolo_call(raw[s]) for s in stems if s in raw}
    if args.hue:
        name, _, path = args.hue.partition("=")
        raw = json.loads(Path(path).read_text())
        models[name] = {s: hue_call(raw[s]) for s in stems if s in raw}
    if args.jev:
        raw = json.loads(Path(args.jev).read_text())
        models["jev"] = {s: jev_call(raw[s]) for s in stems if s in raw}

    cat_frames = [s for s in stems if label[s] in CATS]
    neg_frames = [s for s in stems if label[s] == "none"]
    test_days = sorted({s[:10] for s in stems})
    print(f"test frames: {len(stems)} on {','.join(test_days)} "
          f"({len(cat_frames)} cat-present: "
          f"{sum(label[s] == 'pancake' for s in cat_frames)} pancake, "
          f"{sum(label[s] == 'willow' for s in cat_frames)} willow, "
          f"{len(neg_frames)} negatives)\n")

    def acc(model, subset):
        hits = sum(models[model][s][0] == label[s] for s in subset if s in models[model])
        seen = sum(1 for s in subset if s in models[model])
        return hits, seen

    def boot_diff(m1, m2, subset):
        obs = (sum(models[m1][s][0] == label[s] for s in subset) / len(subset)
               - sum(models[m2][s][0] == label[s] for s in subset) / len(subset))
        rng = random.Random(0)
        diffs = []
        for _ in range(BOOT_N):
            pick = [subset[rng.randrange(len(subset))] for _ in subset]
            d1 = d2 = 0
            for s in pick:
                if models[m1][s][0] == label[s]:
                    d1 += 1
                if models[m2][s][0] == label[s]:
                    d2 += 1
            diffs.append(d1 / len(subset) - d2 / len(subset))
        diffs.sort()
        return obs, diffs[int(0.025 * BOOT_N)], diffs[int(0.975 * BOOT_N)]

    print(f"{'model':<12}{'naming':>22}{'recall':>22}{'neg FPR':>22}")
    summary = {}
    for name in models:
        row = {}
        for metric, subset in (("naming", cat_frames), ("recall", cat_frames),
                               ("neg_fpr", neg_frames)):
            hits = sum((models[name][s][1] if metric != "naming" else
                        models[name][s][0] == label[s])
                       for s in subset if s in models[name])
            seen = sum(1 for s in subset if s in models[name])
            p, lo, hi = wilson(hits, seen)
            row[metric] = {"hits": hits, "n": seen,
                           "acc": p, "lo": lo, "hi": hi}
        summary[name] = row
        cells = []
        for metric in ("naming", "recall", "neg_fpr"):
            r = row[metric]
            cells.append(f"{r['hits']}/{r['n']}={r['acc']:.0%} "
                         f"[{r['lo']:.0%},{r['hi']:.0%}]")
        print(f"{name:<12}{cells[0]:>22}{cells[1]:>22}{cells[2]:>22}")

    print("\nnaming accuracy by day (contamination check for models trained on the corpus):")
    print(f"{'day':<12}" + "".join(f"{n:>16}" for n in models))
    for day in test_days:
        subset = [s for s in stems if s[:10] == day and label[s] in CATS]
        cells = []
        for name in models:
            hits, seen = acc(name, subset)
            cells.append(f"{hits}/{seen}" if seen else "-")
        print(f"{day:<12}" + "".join(f"{c:>16}" for c in cells))
    for name in models:
        summary[name]["by_day"] = {d: acc(name, [s for s in stems
                                                 if s[:10] == d and label[s] in CATS])
                                   for d in test_days}

    print("\npaired comparisons on naming (cat-present test frames):")
    for m1, m2 in combinations(sorted(models), 2):
        subset = [s for s in cat_frames if s in models[m1] and s in models[m2]]
        b = sum(models[m1][s][0] == label[s] and models[m2][s][0] != label[s] for s in subset)
        c = sum(models[m2][s][0] == label[s] and models[m1][s][0] != label[s] for s in subset)
        p = mcnemar_exact(b, c)
        obs, lo, hi = boot_diff(m1, m2, subset)
        verdict = ("significant" if p < 0.05 else "not significant")
        print(f"  {m1} - {m2}: diff {obs:+.0%} [boot {lo:+.0%},{hi:+.0%}], "
              f"discordant {b}/{c}, McNemar p={p:.3f} -> {verdict}")
        summary.setdefault("paired", []).append(
            {"models": [m1, m2], "diff": obs, "boot_lo": lo, "boot_hi": hi,
             "discordant": [b, c], "mcnemar_p": p})

    if args.json:
        Path(args.json).write_text(json.dumps(
            {"test_days": test_days, "n": {"total": len(stems), "cat": len(cat_frames),
                                           "neg": len(neg_frames)},
             "models": summary}, indent=1))
        print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()
