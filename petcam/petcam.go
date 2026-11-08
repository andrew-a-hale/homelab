package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"image"
	"image/jpeg"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Paths are under the owner's home: ~/petcam is the whole state dir, which
// lives on Ralph since the 2026-11-08 appliance split (HOME comes from
// systemd's User=). Only the HLS stream is still Tom's, in its tmpfs.
var (
	home          = homeDir()
	shotsDir      = filepath.Join(home, "petcam/shots")
	hlsDir        = "/dev/shm/petcam"
	detectionsLog = filepath.Join(home, "petcam/detections.log")
	tolabelDir    = filepath.Join(home, "petcam/tolabel")         // near-miss queue for the /label UI
	trainImg      = filepath.Join(home, "petcam/training/images") // output: YOLO pairs (jpg + txt)
	trainLbl      = filepath.Join(home, "petcam/training/labels")
	// /review: stems the owner has verified by eye; anything absent still needs a look.
	reviewedFile = filepath.Join(home, "petcam/training/reviewed.txt")
	// /review flags: stems queued for a second look (petcam-jev.py writes them;
	// one per line, stem first, rest is the human-readable reason).
	flagsFile = filepath.Join(home, "petcam/training/flags.txt")
	// per-frame colour-hint stats cache (*.json never matches the training rsync)
	reviewStatsFile = filepath.Join(home, "petcam/training/review-stats.json")
	// the detector lives in the checkout next to this app
	detector = filepath.Join(home, "projects/homelab/scripts/petcam-detect.py")
)

func homeDir() string {
	h, err := os.UserHomeDir()
	if err != nil {
		panic("no home dir: " + err.Error())
	}
	return h
}

type shot struct {
	Name string `json:"name"`
	URL  string `json:"url"`
	When string `json:"when"`
}

// Templates are embedded so the binary does not depend on its working directory
// (it used to be one file inside the website repo and only worked from there).
//
//go:embed templates/*.html
var tplFS embed.FS

var (
	shotsTmpl = template.Must(template.ParseFS(tplFS, "templates/petcam.html"))
	logTmpl   = template.Must(template.ParseFS(tplFS, "templates/petcam-log.html"))
)

func serveTpl(w http.ResponseWriter, r *http.Request, name string) {
	http.ServeFileFS(w, r, tplFS, "templates/"+name)
}

func noStore(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		h.ServeHTTP(w, r)
	})
}

// listShots: newest 10 snapshots for the gallery. The detector keeps 20 on
// disk (KEEP_SHOTS), so a manual delete on the page backfills the view from
// the pool instead of losing history.
func listShots() []shot {
	names, _ := filepath.Glob(filepath.Join(shotsDir, "*.jpg"))
	sort.Sort(sort.Reverse(sort.StringSlice(names)))
	shots := make([]shot, 0, len(names))
	for _, n := range names {
		base := filepath.Base(n)
		stamp := strings.TrimSuffix(base, ".jpg")
		when := stamp
		if len(stamp) >= 19 {
			if t, err := time.Parse("2006-01-02_15-04-05", stamp[:19]); err == nil {
				when = t.Format("2006-01-02 15:04:05")
				if tag := strings.TrimPrefix(stamp[19:], "_"); tag != "" {
					when += " · " + tag
				}
			}
		}
		shots = append(shots, shot{base, "/shots/" + base, when})
	}
	if len(shots) > 10 {
		shots = shots[:10]
	}
	return shots
}

// Pet cam home: detection snapshots, newest first (page polls /shots.json for new ones).
func handleShots(w http.ResponseWriter, r *http.Request) {
	_ = shotsTmpl.Execute(w, listShots())
}

const logPageSize = 200

type logPage struct {
	Text             string
	Page, Prev, Next int
}

type labelItem struct {
	Name    string `json:"name"`
	URL     string `json:"url"`
	Box     []int  `json:"box"`     // YOLO proposal in pixels (x1,y1,x2,y2), null if none
	Propose string `json:"propose"` // hue-classifier name proposal: willow/pancake/unknown
	Left    int    `json:"left"`
}

// queueNext: first queue image after `after` (empty = first), with its proposal box.
func queueNext(after string) (string, []int, string, int) {
	names, _ := filepath.Glob(filepath.Join(tolabelDir, "*.jpg"))
	sort.Strings(names)
	for _, n := range names {
		base := filepath.Base(n)
		if after != "" && base <= after {
			continue
		}
		var box []int
		var prop string
		if data, err := os.ReadFile(strings.TrimSuffix(n, ".jpg") + ".txt"); err == nil {
			f := strings.Fields(string(data))
			if len(f) >= 4 {
				var v [4]int
				for i := 0; i < 4; i++ {
					v[i], _ = strconv.Atoi(f[i])
				}
				box = []int{v[0], v[1], v[2], v[3]}
				if len(f) >= 5 {
					prop = f[4]
				}
			}
		}
		return base, box, prop, len(names)
	}
	return "", nil, "", len(names)
}

func handleLabel(w http.ResponseWriter, r *http.Request) {
	serveTpl(w, r, "petcam-label.html")
}

func handleLabelNext(w http.ResponseWriter, r *http.Request) {
	base, box, prop, left := queueNext(r.URL.Query().Get("after"))
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(labelItem{base, "/label/img/" + base, box, prop, left})
}

// handleLabelSave: approve (pre-filled proposal) or draw (submitted box) — same action.
// Form: name=<file> box=<cx,cy,w,h normalized 0..1> cat=pancake|willow (required:
// the frame's cat is always somebody's decision, never a silent default).
func handleLabelSave(w http.ResponseWriter, r *http.Request) {
	name := filepath.Base(r.FormValue("name"))
	p := filepath.Join(tolabelDir, name)
	if _, err := os.Stat(p); err != nil {
		http.Error(w, "not in queue", http.StatusNotFound)
		return
	}
	var cx, cy, bw, bh float64
	fmt.Sscanf(r.FormValue("box"), "%f,%f,%f,%f", &cx, &cy, &bw, &bh)
	if bw <= 0 || bh <= 0 || cx-bw/2 < 0 || cy-bh/2 < 0 || cx+bw/2 > 1 || cy+bh/2 > 1 {
		http.Error(w, "bad box", http.StatusBadRequest)
		return
	}
	cat := r.FormValue("cat")
	if cat != "willow" && cat != "pancake" {
		http.Error(w, "pick pancake or willow", http.StatusBadRequest)
		return
	}
	stem := strings.TrimSuffix(name, ".jpg") + "_" + cat // name travels in the filename (both sides of the pair)
	cid := 0
	if cat == "willow" {
		cid = 1
	}
	data, err := os.ReadFile(p)
	if err != nil {
		http.Error(w, "read failed", http.StatusInternalServerError)
		return
	}
	_ = os.MkdirAll(trainImg, 0o755)
	_ = os.MkdirAll(trainLbl, 0o755)
	_ = os.WriteFile(filepath.Join(trainImg, stem+".jpg"), data, 0o644)
	_ = os.WriteFile(filepath.Join(trainLbl, stem+".txt"),
		[]byte(fmt.Sprintf("%d %.6f %.6f %.6f %.6f\n", cid, cx, cy, bw, bh)), 0o644)
	_ = os.Remove(p)
	_ = os.Remove(strings.TrimSuffix(p, ".jpg") + ".txt")
	http.Redirect(w, r, "/label", http.StatusSeeOther)
}

func handleCapture(w http.ResponseWriter, r *http.Request) {
	// Snapshot the detector's current 1fps still into the label queue, running
	// YOLO so a proposed box + cat name is attached when detection succeeds.
	cmd := exec.Command("python3", detector, "--capture")
	if out, err := cmd.CombinedOutput(); err != nil {
		http.Error(w, "capture failed: "+string(out), http.StatusServiceUnavailable)
		return
	}
	http.Redirect(w, r, "/label", http.StatusSeeOther)
}

func handleLabelDelete(w http.ResponseWriter, r *http.Request) {
	// Full delete: remove from the queue without saving (for corrupt/empty/error frames).
	p := filepath.Join(tolabelDir, filepath.Base(r.FormValue("name")))
	_ = os.Remove(p)
	_ = os.Remove(strings.TrimSuffix(p, ".jpg") + ".txt")
	http.Redirect(w, r, "/label", http.StatusSeeOther)
}

func handleLabelReject(w http.ResponseWriter, r *http.Request) {
	p := filepath.Join(tolabelDir, filepath.Base(r.FormValue("name")))
	// Save the rejected frame as a negative (background) training example:
	// an empty label file tells YOLO "no cat in this image". Rejected near-misses
	// are frames we've decided contain no usable cat, so they become negatives.
	if data, err := os.ReadFile(p); err == nil {
		_ = os.MkdirAll(trainImg, 0o755)
		_ = os.MkdirAll(trainLbl, 0o755)
		stem := strings.TrimSuffix(filepath.Base(p), ".jpg") + "_neg"
		_ = os.WriteFile(filepath.Join(trainImg, stem+".jpg"), data, 0o644)
		_ = os.WriteFile(filepath.Join(trainLbl, stem+".txt"), []byte(""), 0o644)
	}
	_ = os.Remove(p)
	_ = os.Remove(strings.TrimSuffix(p, ".jpg") + ".txt")
	http.Redirect(w, r, "/label", http.StatusSeeOther)
}

// ---- /review: audit of already-labeled training pairs (the corpus /review verifies) ----

type reviewBox struct {
	Index  int     `json:"index"` // line number in the label file
	Rect   [4]int  `json:"rect"`  // pixels x1,y1,x2,y2
	CID    int     `json:"cid"`   // 0 pancake, 1 willow
	Orange float64 `json:"orange"`
	Gray   float64 `json:"gray"`
}

type reviewItem struct {
	Name  string      `json:"name"`
	URL   string      `json:"url"`
	Boxes []reviewBox `json:"boxes"`
	Done  bool        `json:"done"`
	// Flagged: queued for a second look (Jev batch or a hue disagreement);
	// Flag is the reason text, e.g. "jev=none p=pan0.21 wil0.11 non0.68".
	Flagged bool   `json:"flagged"`
	Flag    string `json:"flag,omitempty"`
}

// hueStats mirrors petcam-detect.py's classify() over one box crop: fraction of
// visible pixels that read as orange fur (HSV hue 5-30 on OpenCV's 0-180 wheel,
// sat >= 80) or gray (sat < 80). A review diagnostic only — the python file
// remains the naming source of truth; keep ORANGE_* thresholds in sync.
func hueStats(img image.Image, r [4]int) (orange, gray float64) {
	b := img.Bounds()
	x1, y1, x2, y2 := r[0], r[1], r[2]+1, r[3]+1
	if x1 < b.Min.X {
		x1 = b.Min.X
	}
	if y1 < b.Min.Y {
		y1 = b.Min.Y
	}
	if x2 > b.Max.X {
		x2 = b.Max.X
	}
	if y2 > b.Max.Y {
		y2 = b.Max.Y
	}
	visible, o, g := 0, 0, 0
	for y := y1; y < y2; y++ {
		for x := x1; x < x2; x++ {
			cr, cg, cb, _ := img.At(x, y).RGBA()
			r8, g8, b8 := float64(cr>>8), float64(cg>>8), float64(cb>>8)
			mx := math.Max(r8, math.Max(g8, b8))
			mn := math.Min(r8, math.Min(g8, b8))
			if mx <= 40 { // v > 40 is "visible" in the python classifier
				continue
			}
			s := 0.0
			if mx > 0 {
				s = (mx - mn) / mx * 255
			}
			h := 0.0
			if mx > mn {
				switch mx {
				case r8:
					h = math.Mod(60*(g8-b8)/(mx-mn)+360, 360)
				case g8:
					h = 60*(b8-r8)/(mx-mn) + 120
				default:
					h = 60*(r8-g8)/(mx-mn) + 240
				}
			}
			visible++
			h /= 2 // OpenCV 0-180 hue wheel
			if h >= 5 && h <= 30 && s >= 80 {
				o++
			}
			if s < 80 {
				g++
			}
		}
	}
	n := float64(visible)
	if n < 1 {
		n = 1
	}
	return float64(o) / n, float64(g) / n
}

func loadReviewed() map[string]bool {
	m := map[string]bool{}
	if data, err := os.ReadFile(reviewedFile); err == nil {
		for _, s := range strings.Fields(string(data)) {
			m[s] = true
		}
	}
	return m
}

func writeReviewed(m map[string]bool) {
	names := make([]string, 0, len(m))
	for k := range m {
		names = append(names, k)
	}
	sort.Strings(names)
	_ = os.WriteFile(reviewedFile, []byte(strings.Join(names, "\n")+"\n"), 0o644)
}

// loadFlags: stem -> reason from flags.txt (`stem reason...` per line). The
// petcam-jev.py batch writes it; review actions clear individual entries.
func loadFlags() map[string]string {
	m := map[string]string{}
	if data, err := os.ReadFile(flagsFile); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Fields(line)
			if len(fields) == 0 {
				continue
			}
			m[fields[0]] = strings.Join(fields[1:], " ")
		}
	}
	return m
}

func writeFlags(m map[string]string) {
	lines := make([]string, 0, len(m))
	for k, v := range m {
		if v == "" {
			lines = append(lines, k)
		} else {
			lines = append(lines, k+" "+v)
		}
	}
	sort.Strings(lines)
	_ = os.WriteFile(flagsFile, []byte(strings.Join(lines, "\n")+"\n"), 0o644)
}

// clearFlag drops one stem's flag; a human has now looked at the frame.
func clearFlag(stem string) {
	flags := loadFlags()
	if _, ok := flags[stem]; !ok {
		return
	}
	delete(flags, stem)
	writeFlags(flags)
}

// hueCacheEntry: colour-hint stats for one frame, invalidated when the image
// or label file changes or the box count differs. Without this cache,
// /review/list JPEG-decoded the whole corpus on every load (7.5 s at 418
// frames — and the server's write timeout is not far above that).
type hueCacheEntry struct {
	M int64     `json:"m"` // image mtime
	L int64     `json:"l"` // label mtime
	B int       `json:"b"` // box count
	O []float64 `json:"o"` // orange fraction per box
	G []float64 `json:"g"` // gray fraction per box
}

func loadHueCache() map[string]hueCacheEntry {
	m := map[string]hueCacheEntry{}
	if data, err := os.ReadFile(reviewStatsFile); err == nil {
		_ = json.Unmarshal(data, &m)
	}
	return m
}

func writeHueCache(m map[string]hueCacheEntry) {
	if data, err := json.Marshal(m); err == nil {
		_ = os.WriteFile(reviewStatsFile, data, 0o644)
	}
}

func handleReview(w http.ResponseWriter, r *http.Request) {
	serveTpl(w, r, "petcam-review.html")
}

// handleReviewList: every labeled pair with its boxes, hue stats and reviewed
// flag, ordered suspicious-first (hue disagrees with the label, multi-box
// frames), unreviewed before done. Newest first within each group.
func handleReviewList(w http.ResponseWriter, r *http.Request) {
	reviewed := loadReviewed()
	flags := loadFlags()
	names, _ := filepath.Glob(filepath.Join(trainImg, "*.jpg"))
	sort.Sort(sort.Reverse(sort.StringSlice(names)))
	items := make([]reviewItem, 0, len(names))
	cache := loadHueCache()
	cacheDirty := false
	type binfo struct {
		i    int
		rect [4]int
		cid  int
	}
	for _, n := range names {
		base := filepath.Base(n)
		stem := strings.TrimSuffix(base, ".jpg")
		lbl := filepath.Join(trainLbl, stem+".txt")
		data, err := os.ReadFile(lbl)
		if err != nil {
			continue // orphan image (no label): training drops it
		}
		f, err := os.Open(n)
		if err != nil {
			continue
		}
		cfg, err := jpeg.DecodeConfig(f) // header only; the full decode is cached-work
		f.Close()
		if err != nil {
			continue
		}
		W, H := float64(cfg.Width), float64(cfg.Height)
		var lines []string
		if len(data) > 0 {
			lines = strings.Split(strings.TrimSpace(string(data)), "\n")
		}
		list := make([]binfo, 0, len(lines))
		for i, line := range lines {
			fields := strings.Fields(line)
			if len(fields) < 5 {
				continue
			}
			cid, _ := strconv.Atoi(fields[0])
			var cx, cy, bw, bh float64
			fmt.Sscanf(strings.Join(fields[1:5], " "), "%f %f %f %f", &cx, &cy, &bw, &bh)
			list = append(list, binfo{i, [4]int{
				int((cx - bw/2) * W),
				int((cy - bh/2) * H),
				int((cx + bw/2) * W),
				int((cy + bh/2) * H),
			}, cid})
		}
		// colour stats come from the cache unless the image, the label, or the
		// box count changed since they were computed
		ist, _ := os.Stat(n)
		lst, _ := os.Stat(lbl)
		ent := cache[stem]
		fresh := ist != nil && lst != nil && ent.M == ist.ModTime().UnixNano() &&
			ent.L == lst.ModTime().UnixNano() && ent.B == len(list) && len(ent.O) == len(list)
		if !fresh {
			if f, err := os.Open(n); err == nil {
				if img, err := jpeg.Decode(f); err == nil {
					ent.O = make([]float64, len(list))
					ent.G = make([]float64, len(list))
					for j, bx := range list {
						ent.O[j], ent.G[j] = hueStats(img, bx.rect)
					}
				}
				f.Close()
			}
			if ist != nil && lst != nil {
				ent.M, ent.L, ent.B = ist.ModTime().UnixNano(), lst.ModTime().UnixNano(), len(list)
				cache[stem] = ent
				cacheDirty = true
			}
		}
		boxes := make([]reviewBox, 0, len(list))
		for j, bx := range list {
			o, g := 0.0, 0.0
			if j < len(ent.O) {
				o, g = ent.O[j], ent.G[j]
			}
			boxes = append(boxes, reviewBox{bx.i, bx.rect, bx.cid, o, g})
		}
		items = append(items, reviewItem{base, "/review/img/" + base, boxes, reviewed[stem], flags[stem] != "", flags[stem]})
	}
	if cacheDirty {
		writeHueCache(cache)
	}
	sort.SliceStable(items, func(i, j int) bool {
		score := func(it reviewItem) int {
			s := 0
			if it.Flagged {
				s += 10 // Jev disagrees with the label: the whole point of the flag pass
			}
			if it.Done {
				s -= 100
			}
			if len(it.Boxes) == 0 {
				s-- // negatives are quick to confirm — leave them until the end
			}
			for _, bx := range it.Boxes {
				hueSays := 1 // willow
				if bx.Orange > 0.18 {
					hueSays = 0
				}
				if hueSays != bx.CID {
					s += 2
				}
			}
			if len(it.Boxes) > 1 {
				s++
			}
			return s
		}
		si, sj := score(items[i]), score(items[j])
		if si != sj {
			return si > sj
		}
		return items[i].Name > items[j].Name
	})
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(items)
}

// labelLines reads a label file keeping raw line indices (blank/invalid lines
// are preserved so box indexes stay stable across edits).
func labelLines(stem string) ([]string, string, error) {
	p := filepath.Join(trainLbl, stem+".txt")
	data, err := os.ReadFile(p)
	if err != nil {
		return nil, "", err
	}
	if len(data) == 0 {
		return nil, p, nil
	}
	return strings.Split(strings.TrimSpace(string(data)), "\n"), p, nil
}

func writeLabelLines(p string, lines []string) {
	body := ""
	if len(lines) > 0 {
		body = strings.Join(lines, "\n") + "\n"
	}
	_ = os.WriteFile(p, []byte(body), 0o644)
}

// handleReviewSet: flip one box's class. Form: name=<file> i=<line> cat=pancake|willow
func handleReviewSet(w http.ResponseWriter, r *http.Request) {
	stem := strings.TrimSuffix(filepath.Base(r.FormValue("name")), ".jpg")
	lines, p, err := labelLines(stem)
	if err != nil {
		http.Error(w, "not labeled", http.StatusNotFound)
		return
	}
	i, _ := strconv.Atoi(r.FormValue("i"))
	if i < 0 || i >= len(lines) {
		http.Error(w, "bad box", http.StatusBadRequest)
		return
	}
	fields := strings.Fields(lines[i])
	if len(fields) < 5 {
		http.Error(w, "bad box", http.StatusBadRequest)
		return
	}
	fields[0] = "0"
	if r.FormValue("cat") == "willow" {
		fields[0] = "1"
	}
	lines[i] = strings.Join(fields, " ")
	writeLabelLines(p, lines)
	http.Redirect(w, r, "/review", http.StatusSeeOther)
}

// handleReviewDelBox: drop one box line (the frame keeps its remaining boxes).
func handleReviewDelBox(w http.ResponseWriter, r *http.Request) {
	stem := strings.TrimSuffix(filepath.Base(r.FormValue("name")), ".jpg")
	lines, p, err := labelLines(stem)
	if err != nil {
		http.Error(w, "not labeled", http.StatusNotFound)
		return
	}
	i, _ := strconv.Atoi(r.FormValue("i"))
	if i < 0 || i >= len(lines) {
		http.Error(w, "bad box", http.StatusBadRequest)
		return
	}
	lines = append(lines[:i], lines[i+1:]...)
	writeLabelLines(p, lines)
	http.Redirect(w, r, "/review", http.StatusSeeOther)
}

// handleReviewNegative: the frame has no usable cat — keep it as a YOLO negative.
func handleReviewNegative(w http.ResponseWriter, r *http.Request) {
	stem := strings.TrimSuffix(filepath.Base(r.FormValue("name")), ".jpg")
	if _, err := os.Stat(filepath.Join(trainImg, stem+".jpg")); err != nil {
		http.Error(w, "not in corpus", http.StatusNotFound)
		return
	}
	writeLabelLines(filepath.Join(trainLbl, stem+".txt"), nil)
	clearFlag(stem) // owner says no cat: the label question is settled
	http.Redirect(w, r, "/review", http.StatusSeeOther)
}

// handleReviewDeleteFrame: remove the pair entirely (corrupt/empty/error frames).
func handleReviewDeleteFrame(w http.ResponseWriter, r *http.Request) {
	stem := strings.TrimSuffix(filepath.Base(r.FormValue("name")), ".jpg")
	_ = os.Remove(filepath.Join(trainImg, stem+".jpg"))
	_ = os.Remove(filepath.Join(trainLbl, stem+".txt"))
	reviewed := loadReviewed()
	delete(reviewed, stem)
	writeReviewed(reviewed)
	clearFlag(stem)
	http.Redirect(w, r, "/review", http.StatusSeeOther)
}

// handleReviewRelabel: pull a pair out of the corpus and back into /label's
// queue for a fresh hand label. Form: name=<file>
// The current first box becomes the queue proposal (sidecar `x1 y1 x2 y2
// name`, pixels); negatives queue with no proposal. The pair, its reviewed
// entry and any flag go away — a save or reject at /label writes the
// replacement pair.
func handleReviewRelabel(w http.ResponseWriter, r *http.Request) {
	stem := strings.TrimSuffix(filepath.Base(r.FormValue("name")), ".jpg")
	imgPath := filepath.Join(trainImg, stem+".jpg")
	if _, err := os.Stat(imgPath); err != nil {
		http.Error(w, "not in corpus", http.StatusNotFound)
		return
	}
	if _, err := os.Stat(filepath.Join(tolabelDir, stem+".jpg")); err == nil {
		http.Error(w, "queue already has that name", http.StatusConflict)
		return
	}
	data, err := os.ReadFile(imgPath)
	if err != nil {
		http.Error(w, "read failed", http.StatusInternalServerError)
		return
	}
	proposal := ""
	if lines, _, err := labelLines(stem); err == nil && len(lines) > 0 {
		fields := strings.Fields(lines[0])
		if len(fields) >= 5 {
			var cx, cy, bw, bh float64
			fmt.Sscanf(strings.Join(fields[1:5], " "), "%f %f %f %f", &cx, &cy, &bw, &bh)
			if f, err := os.Open(imgPath); err == nil {
				if cfg, err := jpeg.DecodeConfig(f); err == nil {
					W, H := float64(cfg.Width), float64(cfg.Height)
					x1, y1 := int((cx-bw/2)*W), int((cy-bh/2)*H)
					x2, y2 := int((cx+bw/2)*W), int((cy+bh/2)*H)
					name := "pancake"
					if fields[0] == "1" {
						name = "willow"
					}
					proposal = fmt.Sprintf("%d %d %d %d %s", x1, y1, x2, y2, name)
				}
				f.Close()
			}
		}
	}
	if err := os.WriteFile(filepath.Join(tolabelDir, stem+".jpg"), data, 0o644); err != nil {
		http.Error(w, "queue write failed", http.StatusInternalServerError)
		return
	}
	if proposal != "" {
		_ = os.WriteFile(filepath.Join(tolabelDir, stem+".txt"), []byte(proposal), 0o644)
	}
	_ = os.Remove(imgPath)
	_ = os.Remove(filepath.Join(trainLbl, stem+".txt"))
	reviewed := loadReviewed()
	delete(reviewed, stem)
	writeReviewed(reviewed)
	clearFlag(stem)
	http.Redirect(w, r, "/review", http.StatusSeeOther)
}

// handleReviewDone: toggle the verified flag for a frame. Form: name=<file> done=1|0
func handleReviewDone(w http.ResponseWriter, r *http.Request) {
	stem := strings.TrimSuffix(filepath.Base(r.FormValue("name")), ".jpg")
	reviewed := loadReviewed()
	if r.FormValue("done") == "1" {
		reviewed[stem] = true
		clearFlag(stem) // verified by eye: the second-look queue is done with it
	} else {
		delete(reviewed, stem)
	}
	writeReviewed(reviewed)
	http.Redirect(w, r, "/review", http.StatusSeeOther)
}

func handleLog(w http.ResponseWriter, r *http.Request) {
	// raw text log, newest first (detector keeps a rolling 2-week window)
	data, _ := os.ReadFile(detectionsLog)
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		lines = nil
	}
	for i, j := 0, len(lines)-1; i < j; i, j = i+1, j-1 {
		lines[i], lines[j] = lines[j], lines[i]
	}
	if len(lines) == 0 {
		_ = logTmpl.Execute(w, nil)
		return
	}
	page, _ := strconv.Atoi(r.URL.Query().Get("p"))
	if page < 1 {
		page = 1
	}
	start := (page - 1) * logPageSize
	if start >= len(lines) {
		page, start = 1, 0
	}
	end := start + logPageSize
	if end > len(lines) {
		end = len(lines)
	}
	p := logPage{Text: strings.Join(lines[start:end], "\n"), Page: page}
	if page > 1 {
		p.Prev = page - 1
	}
	if end < len(lines) {
		p.Next = page + 1
	}
	_ = logTmpl.Execute(w, p)
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
	// Single authenticated user (Cloudflare Access); Base() blocks path traversal.
	// Deleting a snapshot means "this was not a cat" (the owner's FP cleanup
	// habit), so the matching training pair becomes a verified negative — the
	// deletions teach the next retrain. Skipped when another snapshot of the
	// same frame survives (the frame does contain a cat).
	name := filepath.Base(r.FormValue("name"))
	if _, err := os.Stat(filepath.Join(shotsDir, name)); err == nil {
		_ = os.Remove(filepath.Join(shotsDir, name))
		stem := strings.TrimSuffix(name, ".jpg")
		for _, tag := range []string{"_pancake", "_willow", "_cat"} {
			stem = strings.TrimSuffix(stem, tag)
		}
		siblings, _ := filepath.Glob(filepath.Join(shotsDir, stem+"_*.jpg"))
		if len(siblings) == 0 {
			if p := filepath.Join(trainLbl, stem+".txt"); stem != "" {
				if _, err := os.Stat(filepath.Join(trainImg, stem+".jpg")); err == nil {
					_ = os.WriteFile(p, []byte(""), 0o644) // negative: no cat in this frame
					reviewed := loadReviewed()
					reviewed[stem] = true
					writeReviewed(reviewed)
				}
			}
		}
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func handleShotsJSON(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(listShots())
}

func PetcamMuxSetup() *http.ServeMux {
	petcam := http.NewServeMux()
	petcam.HandleFunc("/", handleShots)
	petcam.Handle("/live", noStore(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		serveTpl(w, r, "petcam-live.html")
	})))
	petcam.Handle("/shots.json", noStore(http.HandlerFunc(handleShotsJSON)))
	petcam.HandleFunc("POST /delete", handleDelete)
	petcam.HandleFunc("/log", handleLog)
	petcam.Handle("/label", noStore(http.HandlerFunc(handleLabel)))
	petcam.HandleFunc("/capture", handleCapture)
	petcam.HandleFunc("GET /label/next", handleLabelNext)
	petcam.HandleFunc("POST /label/save", handleLabelSave)
	petcam.HandleFunc("POST /label/reject", handleLabelReject)
	petcam.HandleFunc("POST /label/delete", handleLabelDelete)
	petcam.Handle("/label/img/", noStore(http.StripPrefix("/label/img/", http.FileServer(http.Dir(tolabelDir)))))
	petcam.Handle("/review", noStore(http.HandlerFunc(handleReview)))
	petcam.HandleFunc("GET /review/list", handleReviewList)
	petcam.HandleFunc("POST /review/set", handleReviewSet)
	petcam.HandleFunc("POST /review/delbox", handleReviewDelBox)
	petcam.HandleFunc("POST /review/negative", handleReviewNegative)
	petcam.HandleFunc("POST /review/delete", handleReviewDeleteFrame)
	petcam.HandleFunc("POST /review/done", handleReviewDone)
	petcam.HandleFunc("POST /review/relabel", handleReviewRelabel)
	petcam.Handle("/review/img/", noStore(http.StripPrefix("/review/img/", http.FileServer(http.Dir(trainImg)))))
	petcam.Handle("/shots/", noStore(http.StripPrefix("/shots/", http.FileServer(http.Dir(shotsDir)))))
	petcam.Handle("/hls/", noStore(http.StripPrefix("/hls/", http.FileServer(http.Dir(hlsDir)))))

	return petcam
}
