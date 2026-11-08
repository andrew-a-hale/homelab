#!/usr/bin/env python3
"""petcam-jev.py — run the deployed review corpus past typesafe/jev-1.14
(OpenRouter Decisions API) and flag frames whose label disagrees with Jev.

One request per frame (noul + choice + box share the image, ~$0.00012/frame at
720p). Writes:
  <out>/jev-scores.json  per-frame Jev answer + usage (the raw evidence)
  <out>/flags.txt        `stem reason...` per disagreement -> Tom's
                         ~/petcam/training/flags.txt, shown by /review
and prints a label-vs-Jev-vs-YOLO report when --yolo-scores is given.

Usage:
  petcam-jev.py --from-tom                    # rsync corpus from tom, full run
  petcam-jev.py --corpus-dir DIR [--limit N]  # local corpus (images/ + labels/)
  petcam-jev.py --from-tom --push-flags       # + scp flags.txt to tom
  petcam-jev.py --from-tom --yolo-scores y.json   # merge the detector pass
Key: $OPENROUTER_API_KEY, else `pass dev/openrouter`. Never stored here.
"""

import argparse
import base64
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

TOM = "tom"
MODEL = "typesafe/jev-1.14"
URL = "https://openrouter.ai/api/alpha/decisions"
CATS = ["pancake", "willow"]

# Same three questions as the 2026-11-08 trial (they separated the cats well).
QUESTIONS = {
    "cat_present": {
        "type": "noul",
        "instructions": "Is a cat visible in this photo?",
        "criteria": {
            "true": "One or more cats are visible in the photo.",
            "false": "No cat is visible in the photo.",
        },
    },
    "which_cat": {
        "type": "choice",
        "instructions": "Which cat is in this photo?",
        "criteria": {
            "pancake": "Pancake: the orange ginger cat.",
            "willow": "Willow: the grey/brown tabby cat.",
            "none": "No cat is visible in the photo.",
        },
    },
    "cat_box": {"type": "box", "instructions": "the cat in this photo"},
}


def api_key():
    if os.environ.get("OPENROUTER_API_KEY"):
        return os.environ["OPENROUTER_API_KEY"].strip()
    return subprocess.run(["pass", "dev/openrouter"], capture_output=True,
                          text=True, check=True).stdout.strip()


def ask_jev(key, jpg):
    b64 = base64.b64encode(pathlib.Path(jpg).read_bytes()).decode()
    body = {
        "model": MODEL,
        "state": ["A frame from a fixed indoor pet camera:",
                  {"type": "image_url",
                   "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}],
        "questions": QUESTIONS,
    }
    req = urllib.request.Request(
        URL, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 "X-Title": "petcam-jev"}, method="POST")
    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 529):
                last = e
                time.sleep(2 * (attempt + 1))
                continue
            raise RuntimeError(f"{jpg}: HTTP {e.code}: {e.read().decode()[:300]}") from e
    raise RuntimeError(f"{jpg}: giving up after retries: {last}")


def label_of(lbl_path):
    """pancake / willow / none from a YOLO label file (class ids 0/1)."""
    p = pathlib.Path(lbl_path)
    if not p.exists():
        return None  # not in the corpus
    text = p.read_text().strip()
    if not text:
        return "none"  # empty file = verified negative
    cids = {int(line.split()[0]) for line in text.splitlines() if line.split()}
    if 0 in cids:
        return "pancake"
    if 1 in cids:
        return "willow"
    return "none"


def jev_choice(ans):
    ch = ans["answers"]["which_cat"]
    probs = {k: ch["probabilities"].get(k, 0.0) for k in CATS + ["none"]}
    return ch["choice"], probs


def run_frame(key, jpg, lbl):
    raw = ask_jev(key, jpg)
    choice, probs = jev_choice(raw)
    stem = pathlib.Path(jpg).stem
    want = label_of(lbl)
    flag = ""
    if want in CATS and choice == "none":
        flag = f"jev=none p={probs['pancake']:.2f}/{probs['willow']:.2f}/{probs['none']:.2f}"
    elif want in CATS and choice != want:
        flag = f"jev={choice} label={want} p={probs['pancake']:.2f}/{probs['willow']:.2f}/{probs['none']:.2f}"
    elif want == "none" and choice in CATS and max(probs["pancake"], probs["willow"]) > 0.5:
        flag = f"jev={choice} on a negative frame p={probs['pancake']:.2f}/{probs['willow']:.2f}/{probs['none']:.2f}"
    usage = raw.get("usage", {})
    record = {
        "label": want, "choice": choice, "probs": probs,
        "noul": raw["answers"]["cat_present"].get("noul"),
        "box": raw["answers"]["cat_box"].get("box"),
        "flag": flag,
        "cost": usage.get("cost", 0.0), "in_tokens": usage.get("input_tokens"),
    }
    print(f"{stem}: label={want} jev={choice} "
          f"p={probs['pancake']:.2f}/{probs['willow']:.2f}/{probs['none']:.2f} "
          f"{'FLAG ' + flag if flag else ''}", flush=True)
    return record


def report(scores, yolo_path):
    have_yolo = {}
    if yolo_path:
        have_yolo = json.loads(pathlib.Path(yolo_path).read_text())
    cat_frames = [s for s, r in scores.items() if r["label"] in CATS]
    neg_frames = [s for s, r in scores.items() if r["label"] == "none"]
    agree = [s for s in cat_frames if scores[s]["choice"] == scores[s]["label"]]
    wrong_cat = [s for s in cat_frames if scores[s]["choice"] in CATS
                 and scores[s]["choice"] != scores[s]["label"]]
    jev_none = [s for s in cat_frames if scores[s]["choice"] == "none"]
    false_cat = [s for s in neg_frames if scores[s]["choice"] in CATS
                 and max(scores[s]["probs"]["pancake"], scores[s]["probs"]["willow"]) > 0.5]
    total_cost = sum(r["cost"] for r in scores.values())
    n = len(scores) or 1

    print("\n==== Jev vs labels ====")
    print(f"frames: {len(scores)}  (cat-labeled {len(cat_frames)}, negatives {len(neg_frames)})")
    print(f"Jev names the labeled cat right: {len(agree)}/{len(cat_frames)}"
          f" ({100 * len(agree) / max(len(cat_frames), 1):.0f}%)")
    print(f"Jev names the OTHER cat: {len(wrong_cat)}  {[s for s in wrong_cat][:10]}")
    print(f"Jev says none on a labeled cat: {len(jev_none)}  {jev_none[:10]}")
    print(f"Jev sees a cat on a negative: {len(false_cat)}  {false_cat[:10]}")
    print(f"cost: ${total_cost:.4f} total, ${total_cost / n * 1e6:.2f}/M-frame "
          f"(${total_cost / n:.6f}/frame avg)")

    if have_yolo:
        print("\n==== YOLO (deployed ONNX) vs labels ====")
        yolo_seen = [s for s in cat_frames if have_yolo.get(s, {}).get("yolo")]
        yolo_right = [s for s in yolo_seen if have_yolo[s]["yolo"] == scores[s]["label"]]
        yolo_missed = [s for s in cat_frames if not have_yolo.get(s, {}).get("yolo")]
        hue_right = [s for s in yolo_seen if have_yolo[s].get("hue") == scores[s]["label"]]
        print(f"detected the labeled cat at MIN_CONF: {len(yolo_seen)}/{len(cat_frames)}"
              f" ({100 * len(yolo_seen) / max(len(cat_frames), 1):.0f}%)")
        print(f"  missed entirely: {len(yolo_missed)}  {yolo_missed[:10]}")
        print(f"named the labeled cat right (2-class): {len(yolo_right)}/{len(yolo_seen)}"
              f" ({100 * len(yolo_right) / max(len(yolo_seen), 1):.0f}%)")
        print(f"hue classifier, same frames: {len(hue_right)}/{len(yolo_seen)}"
              f" ({100 * len(hue_right) / max(len(yolo_seen), 1):.0f}%)")
        # cascade: YOLO finds it, Jev names it
        both = [s for s in yolo_seen if scores[s]["choice"] == scores[s]["label"]]
        print(f"cascade (YOLO detect + Jev name): right {len(both)}/{len(cat_frames)}"
              f" ({100 * len(both) / max(len(cat_frames), 1):.0f}%)"
              f" — {yolo_missed and len(yolo_missed) or 0} misses are YOLO detection, not naming")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--from-tom", action="store_true",
                    help="rsync the training corpus from tom into a work dir first")
    ap.add_argument("--corpus-dir", help="local corpus with images/ and labels/")
    ap.add_argument("--yolo-scores", help="petcam-detect.py --score-corpus JSON to merge")
    ap.add_argument("--out-dir", default=".amp/in/jev-corpus",
                    help="where jev-scores.json + flags.txt are written")
    ap.add_argument("--push-flags", action="store_true",
                    help="scp flags.txt to tom:petcam/training/flags.txt")
    ap.add_argument("--limit", type=int, help="only the first N frames (alphabetical)")
    ap.add_argument("--stems", help="comma-separated stems to score (testing)")
    ap.add_argument("--jobs", type=int, default=4)
    args = ap.parse_args()

    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.from_tom:
        corpus = out_dir / "training"
        for sub in ("images", "labels"):
            subprocess.run(["rsync", "-aq", f"{TOM}:petcam/training/{sub}",
                            str(corpus / sub)], check=True)
    else:
        corpus = pathlib.Path(args.corpus_dir)
        if not corpus:
            ap.error("need --from-tom or --corpus-dir")

    images = sorted((corpus / "images").glob("*.jpg"))
    if args.stems:
        wanted = set(args.stems.split(","))
        images = [p for p in images if p.stem in wanted]
    if args.limit:
        images = images[: args.limit]
    if not images:
        sys.exit("no corpus images found")

    key = api_key()
    jobs = {}
    with ThreadPoolExecutor(max_workers=args.jobs) as ex:
        for stem, rec in zip([p.stem for p in images],
                             ex.map(lambda p: run_frame(key, p,
                                    corpus / "labels" / (p.stem + ".txt")), images)):
            jobs[stem] = rec

    (out_dir / "jev-scores.json").write_text(json.dumps(jobs, indent=1))
    flags = {s: r["flag"] for s, r in jobs.items() if r["flag"]}
    flags_path = out_dir / "flags.txt"
    flags_path.write_text("".join(f"{s} {f}\n" for s, f in sorted(flags.items())))
    print(f"\nwrote {out_dir / 'jev-scores.json'} and {flags_path} "
          f"({len(flags)} flagged frames)")
    if args.push_flags:
        subprocess.run(["scp", "-q", str(flags_path), f"{TOM}:petcam/training/flags.txt"],
                       check=True)
        print(f"pushed flags.txt to {TOM}:petcam/training/flags.txt")
    report(jobs, args.yolo_scores)


if __name__ == "__main__":
    main()
