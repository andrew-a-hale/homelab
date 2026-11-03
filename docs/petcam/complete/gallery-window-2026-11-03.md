# Gallery window — show 10, keep 20 (2026-11-03)

**Task:** the owner found the gallery "less useful" after the extra labeled
images — with detections more frequent, the keep-1-shot-per-cat design churned
two cards constantly, and manually deleted false positives took history with
them.

**Decision:** the snapshot feed is **any cat detection**, newest first:

- Gallery (`/` and `/shots.json`) shows the newest **10** snapshots.
- The detector keeps the newest **20** on disk (`KEEP_SHOTS`, replacing
  `KEEP_PER_CAT=1`), so a manual delete on the page backfills the view from the
  pool instead of losing history.
- Identity stays as annotation (name drawn on the image and in the filename);
  the labeling/review loop continues — detection of *any* cat is the priority,
  names are the human-verified layer on top.

**Verification:** `--selftest` ok after the detector restart; `/` and `/review`
200; `shots.json` serves the capped list. The pool was near-empty at deploy
(old rule pruned to 1 per cat) — the window fills as detections roll in.
