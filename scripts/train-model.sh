#!/bin/bash
# Train yolov8n on the labeled petcam data (gaming rig) and push it to the Pi.
# Run after curating on https://petcam.andrewahale.com/label
#   EPOCHS=50 scripts/train-model.sh   # optional override (default 100)
#
# Held-out experiment mode (see docs/petcam/complete/yolo-jev-heldout-2026-11-08.md):
#   HOLDOUT_DAYS=2026-10-31,2026-11-05,2026-11-08 \
#   VAL_DAYS=2026-10-30,2026-11-04 \
#   RUN=petcam-heldout scripts/train-model.sh
# Splits by calendar day (no near-duplicate leakage across the split), keeps the
# holdout days out of training entirely, writes their stems to test-stems.txt
# for offline scoring, and never deploys — the weights stay in runs/$RUN/.
set -euo pipefail

PI=tom@tom.tailad1015.ts.net
WORK="$HOME/petcam-train"
YOLO="$WORK/.venv/bin/yolo"
EPOCHS=${EPOCHS:-100}
HOLDOUT_DAYS=${HOLDOUT_DAYS:-}
VAL_DAYS=${VAL_DAYS:-}
RUN=${RUN:-petcam}

cd "$WORK"

# 1. pull the labeled pairs (training/images + training/labels)
rm -rf data-src && mkdir -p data-src
rsync -a --include='*/' --include='*.jpg' --include='*.txt' --exclude='*' \
    "$PI:~/petcam/training/" data-src/
# drop corrupt pairs (0-byte images) and orphans so ultralytics doesn't choke
find data-src/images -type f -name '*.jpg' -size 0 -delete
for img in data-src/images/*.jpg; do
    [ -e "$img" ] || continue
    stem=$(basename "$img" .jpg)
    [ -f "data-src/labels/$stem.txt" ] || rm -f "$img"
done
for lbl in data-src/labels/*.txt; do
    [ -e "$lbl" ] || continue
    stem=$(basename "$lbl" .txt)
    [ -f "data-src/images/$stem.jpg" ] || rm -f "$lbl"
done

# Only human-verified labels train the model: pairs named at /label (cat name in
# the filename), _neg rejects, or stems marked reviewed at /review. Auto-labeled
# colour guesses never reach training unverified — hue breaks under lighting.
verified() {
    case "$1" in
        *_neg | *_pancake | *_willow) return 0 ;;
    esac
    grep -qxF "$1" data-src/reviewed.txt 2>/dev/null
}
dropped=0
for img in data-src/images/*.jpg; do
    [ -e "$img" ] || continue
    stem=$(basename "$img" .jpg)
    if ! verified "$stem"; then
        rm -f "$img" "data-src/labels/$stem.txt"
        dropped=$((dropped + 1))
    fi
done
[ "$dropped" -eq 0 ] || echo "dropped $dropped unverified auto-labeled pairs (verify them at /review)"
n=$(ls data-src/images/*.jpg 2>/dev/null | wc -l)
[ "$n" -gt 4 ] || { echo "only $n verified images - label at /label and verify at /review first"; exit 1; }

# 2. split. Default: 80/20 random (legacy — leaks near-duplicates, kept for
#    production retrains). HOLDOUT_DAYS set: day-grouped experiment split.
day_in() { case ",$2," in *",$1,"*) return 0 ;; esac; return 1; }
rm -rf data && mkdir -p data/{train,val}/{images,labels}
: > test-stems.txt
if [ -n "$HOLDOUT_DAYS" ]; then
    [ -n "$VAL_DAYS" ] || { echo "HOLDOUT_DAYS also needs VAL_DAYS (disjoint, day-grouped val)"; exit 1; }
    ntrain=0; nval=0
    while read -r img; do
        stem=$(basename "$img" .jpg)
        day=${stem:0:10}
        if day_in "$day" "$HOLDOUT_DAYS"; then
            echo "$stem" >> test-stems.txt  # frozen test day: never trains
            continue
        elif day_in "$day" "$VAL_DAYS"; then
            d=val; nval=$((nval + 1))
        else
            d=train; ntrain=$((ntrain + 1))
        fi
        cp "$img" "data/$d/images/"
        cp "data-src/labels/$stem.txt" "data/$d/labels/"
    done < <(ls data-src/images/*.jpg | sort)
    echo "held-out split: $ntrain train / $nval val / $(wc -l < test-stems.txt) test (test days $HOLDOUT_DAYS stay frozen)"
else
    # 80/20 train/val split, pairs kept together
    ls data-src/images/*.jpg | sort | shuf --random-source=/dev/zero > order.txt
    nval=$(( (n + 4) / 5 ))
    i=0
    while read -r img; do
        stem=$(basename "$img" .jpg)
        if [ "$i" -lt "$nval" ]; then d=val; else d=train; fi
        cp "$img" "data/$d/images/"
        cp "data-src/labels/$stem.txt" "data/$d/labels/"
        i=$((i + 1))
    done < order.txt
fi
echo "dataset: $(( $(find data/train/images -name '*.jpg' | wc -l) )) train / $(( $(find data/val/images -name '*.jpg' | wc -l) )) val"
printf 'train: %s/data/train/images\nval: %s/data/val/images\nnames: {0: pancake, 1: willow}\n' "$WORK" "$WORK" > data.yaml

# 3. train + export ONNX at the detector's input size
"$YOLO" detect train model=yolov8n.pt data=data.yaml epochs="$EPOCHS" \
    imgsz=640 device=0 project="$WORK/runs" name="$RUN" exist_ok=True
"$YOLO" export model="$WORK/runs/$RUN/weights/best.pt" format=onnx imgsz=640

# 4. validate on the val split (metrics printed + saved for the quality gate)
"$YOLO" val model="$WORK/runs/$RUN/weights/best.pt" data=data.yaml imgsz=640 device=0 \
    project="$WORK/runs" name="$RUN-val" exist_ok=True

if [ -n "$HOLDOUT_DAYS" ]; then
    echo "experiment run: nothing deployed. weights at $WORK/runs/$RUN/weights/best.onnx,"
    echo "test-day stems in $WORK/test-stems.txt - score them offline with petcam-metrics.py"
    exit 0
fi

# 5. push to the Pi (previous model kept as .bak for rollback)
scp "$WORK/runs/$RUN/weights/best.onnx" "$PI:~/petcam/model/yolov8n.onnx.new"
ssh "$PI" 'cp ~/petcam/model/yolov8n.onnx ~/petcam/model/yolov8n.onnx.bak &&
    mv ~/petcam/model/yolov8n.onnx.new ~/petcam/model/yolov8n.onnx &&
    pkill -f "petcam-detect[.]py$"; sleep 1
    setsid python3 /home/tom/projects/homelab/scripts/petcam-detect[.]py >>/tmp/petcam-detect.log 2>&1 < /dev/null &'
echo "pushed + detector restarted. verify against known shots, else roll back:"
echo "  ssh $PI 'cp ~/petcam/model/yolov8n.onnx.bak ~/petcam/model/yolov8n.onnx'"
