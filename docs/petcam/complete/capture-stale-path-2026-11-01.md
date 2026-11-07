# /capture stale path — the third `/home/tom/petcam-detect.py` reference (2026-11-01)

**Symptom:** the Capture button on `/live` returned
`capture failed: python3: can't open file '/home/tom/petcam-detect.py'`.

**Cause:** `handleCapture` in the website's `main.go` still invoked the
detector at its pre-git path. The 2026-10-27 move to
`/home/tom/projects/homelab/scripts/petcam-detect.py` fixed `train-model.sh` and
the retrain skill, but the web app was a third stale reference nobody swept.

**Fix:** `main.go` now execs the git-checkout path. Verified live: `/capture`
redirects and a frame lands in `~/petcam/tolabel/` with the YOLO proposal.

**Lesson:** when a path moves, search every repo that names it — the web app
and the scripts live in different repositories, so a fix in one looks complete
from inside it. The retrain skill's gotcha list is now the checklist for this
move.
