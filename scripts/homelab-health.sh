#!/usr/bin/env bash
# homelab-health.sh — daily health check for Tom, Ralph and the public ingress.
# Read-only: nothing is installed, enabled, restarted or changed on any host.
# Needs only bash, ssh and curl (both hosts are passwordless over the tailnet).
#
# Usage:  scripts/homelab-health.sh [--quiet] [--selftest]
#   (no args)  full PASS/FAIL report, one line per check
#   --quiet    print only WARN/FAIL lines (for cron)
#   --selftest exercise the parsing/threshold logic on canned inputs, no network
#
# Exit: 0 = every check PASS or WARN, 1 = at least one FAIL. WARN never fails
# the run, so `scripts/homelab-health.sh && ...` still works.
# Log:  one summary line per run appended to $HEALTH_LOG
#       (default ~/homelab-health.log); lines older than ~90 days are pruned.

set -uo pipefail

# ┌────────────────────────────────────────────────────────────────────────────┐
# │ THRESHOLDS AND TARGETS — all of them, here, nowhere else.                  │
# └────────────────────────────────────────────────────────────────────────────┘
# Why each value:
#   BOOT_WARN_MAX=3    Tom hard-resets itself when the reboot bug is live
#                      (~1/hour; docs/server/todo/tom-reboots-hang-2026-10-31.md).
#                      A couple of boots a day is normal after an update, more
#                      than 3 in 24h means the bug is flaring.
#   SHOT_STALE_H=24    ~134 detections/day on this camera, so a day with no new
#                      snapshot means the detector is wedged or the cats left.
#                      WARN only: an empty house is not an outage.
#   FRAME_STALE_S=600  capture is 1 fps into /dev/shm/petcam/frames; 10 minutes
#                      with no new frame is a dead pipeline, not a quiet cat.
#   DISK_MIN_PCT=10    under 10% free, btrfs/ext4 and Jellyfin transcodes start
#                      to misbehave. WARN: nothing is lost yet.
#   HTTP_TIMEOUT=10    Cloudflare edge answers fast when healthy; 10s is a
#                      generous ceiling for a cold tunnel hop.
#   LOG_KEEP_DAYS=90   ~quarter of daily lines, small enough to read by hand.
#   AUTH_WARN_MAX=20   failed SSH logins (and nginx 401s on /bt/) per host per
#                      24h. Ralph's sshd is key-only and LAN 22 is firewalled, so
#                      a burst means something is trying; a handful is internet
#                      background noise. WARN: it is a trend, not an outage.
BOOT_WARN_MAX=3
SHOT_STALE_H=24
FRAME_STALE_S=600
DISK_MIN_PCT=10
HTTP_TIMEOUT=10
LOG_KEEP_DAYS=90
AUTH_WARN_MAX=20

TOM_HOST=${TOM_HOST:-tom}
RALPH_HOST=${RALPH_HOST:-ralph}
HEALTH_LOG=${HEALTH_LOG:-$HOME/homelab-health.log}
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8)

# Ingress hostnames that must answer (docs/ralph/cloudflared-config.yaml).
SITES=(andrewahale.com petcam.andrewahale.com jellyfin.andrewahale.com)
# Units that must be active on Ralph (RUNBOOK.md §Ralph / docs/ralph/README.md).
RALPH_UNITS=(nginx cloudflared jellyfin 'qbittorrent-nox@qbittorrent')

PASS_N=0 WARN_N=0 FAIL_N=0
HOST="" HOST_WARN=0 HOST_FAIL=0 HOST_HEADER=0
QUIET=""
TOM_STATUS=skip RALPH_STATUS=skip INGRESS_STATUS=skip
PROBE=""

# ── output ──────────────────────────────────────────────────────────────────
emit() { # LEVEL NAME DETAIL
  local level=$1
  case $level in
    PASS) PASS_N=$((PASS_N + 1)) ;;
    WARN) WARN_N=$((WARN_N + 1)); HOST_WARN=$((HOST_WARN + 1)) ;;
    FAIL) FAIL_N=$((FAIL_N + 1)); HOST_FAIL=$((HOST_FAIL + 1)) ;;
  esac
  [ -n "$QUIET" ] && [ "$level" = PASS ] && return 0
  if [ "$HOST_HEADER" = 0 ]; then
    printf '\n== %s ==\n' "$HOST"
    HOST_HEADER=1
  fi
  printf '%-4s %-20s %s\n' "$level" "$2 " "$3"
}

host_begin() { HOST=$1; HOST_WARN=0; HOST_FAIL=0; HOST_HEADER=0; }

host_end() { # aggregate this host's one-word status for the log line
  local st=ok
  [ "$HOST_WARN" -gt 0 ] && st=warn
  [ "$HOST_FAIL" -gt 0 ] && st=fail
  case $HOST in
    tom) TOM_STATUS=$st ;;
    ralph) RALPH_STATUS=$st ;;
    ingress) INGRESS_STATUS=$st ;;
  esac
}

# ── parsing helpers (selftested) ────────────────────────────────────────────
get() { printf '%s\n' "$PROBE" | sed -n "s/^$1=//p" | tail -1; }
getall() { printf '%s\n' "$PROBE" | sed -n "s/^$1=//p"; }

human_age() { # seconds -> 12m / 3h / 2d
  [ "$1" -lt 0 ] && { echo "none"; return; }
  if [ "$1" -ge 86400 ]; then echo "$(($1 / 86400))d"
  elif [ "$1" -ge 3600 ]; then echo "$(($1 / 3600))h"
  elif [ "$1" -ge 60 ]; then echo "$(($1 / 60))m"
  else echo "${1}s"; fi
}

# ── classifiers: raw value in, PASS/WARN/FAIL out (selftested) ──────────────
throttle_class() { [ "$1" = "0x0" ] && echo PASS || echo FAIL; }
svc_class() { [ "$1" = active ] && echo PASS || echo FAIL; }
stat_class() { # age_seconds limit_seconds
  [ "$1" -lt 0 ] && { echo WARN; return; }
  [ "$1" -gt "$2" ] && echo WARN || echo PASS
}
boots_class() { # boots in the last 24h
  [ "$1" -lt 0 ] && { echo WARN; return; }
  [ "$1" -gt "$BOOT_WARN_MAX" ] && echo WARN || echo PASS
}
auth_class() { # failed logins in the last 24h
  [ "$1" -lt 0 ] && { echo WARN; return; }
  [ "$1" -gt "$AUTH_WARN_MAX" ] && echo WARN || echo PASS
}
disk_class() { # free percent
  [ "$1" -lt "$DISK_MIN_PCT" ] && echo WARN || echo PASS
}
http_class() { # curl status code; 000 = timeout/refused, any real response is fine
  case $1 in
    1??|2??|3??|4??) echo PASS ;; # 302/401 = Cloudflare Access healthy
    *) echo FAIL ;;
  esac
}

# ── probes: one ssh round-trip per host, raw key=value out ──────────────────
probe_tom() {
  ssh "${SSH_OPTS[@]}" "$TOM_HOST" 'bash -s' <<'REMOTE'
newest_age() { # seconds since the newest file in $1, -1 if none
  local f
  f=$(find "$1" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
  [ -n "$f" ] || { echo -1; return; }
  echo $(( $(date +%s) - ${f%%.*} ))
}
now=$(date +%s)
boots=$(journalctl --list-boots -o json --no-pager 2>/dev/null |
  grep -o '"first_entry":[0-9]*' | awk -F: -v t=$((now - 86400)) '($2/1000000) > t' | wc -l)
[ -n "$boots" ] || boots=-1
printf 'boot=%s\n'      "$(uptime -s)"
printf 'uptime=%s\n'    "$(uptime -p | sed 's/^up //')"
printf 'svc=%s\n'       "$(systemctl is-active petcam-static 2>/dev/null)"
printf 'rpicam=%s\n'    "$(pgrep -x rpicam-vid >/dev/null && echo up || echo down)"
printf 'ffmpeg=%s\n'    "$(pgrep -x ffmpeg >/dev/null && echo up || echo down)"
# Tom is a camera appliance since 2026-11-08: capture + a dumb read-only static
# server for /dev/shm/petcam. The detector and the app live on ralph.
printf 'static=%s\n'    "$(pgrep -f 'http[.]server 8081' >/dev/null && echo up || echo down)"
printf 'throttled=%s\n' "$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)"
printf 'temp=%s\n'      "$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2)"
printf 'shot_age=%s\n'  "$(newest_age "$HOME/petcam/shots")"
printf 'frame_age=%s\n' "$(newest_age /dev/shm/petcam/frames)"
printf 'boots=%s\n'     "$boots"
printf 'authfail=%s\n'  "$(journalctl -u ssh --since '-24h' --no-pager 2>/dev/null | grep -cE 'Failed password|Invalid user')"
REMOTE
}

probe_ralph() {
  ssh "${SSH_OPTS[@]}" "$RALPH_HOST" 'bash -s' <<'REMOTE'
printf 'uptime=%s\n' "$(uptime -p | sed 's/^up //')"
for u in nginx cloudflared jellyfin qbittorrent-nox@qbittorrent; do
  printf 'svc=%s:%s\n' "$u" "$(systemctl is-active "$u" 2>/dev/null)"
done
printf 'proton0=%s\n' "$(ip link show proton0 >/dev/null 2>&1 && echo up || echo down)"
# petcam state is on this box since 2026-11-08 (app :8082 behind nginx, detector).
printf 'detect=%s\n' "$(pgrep -f 'petcam-detect[.]py' >/dev/null && echo up || echo down)"
# Detection sits here: nginx has no log to count 401s in, jellyfin fires
# fail2ban, and both are only reachable from the outside through the tunnel.
printf 'authfail=%s\n' "$(journalctl -u sshd --since '-24h' --no-pager 2>/dev/null | grep -cE 'Failed password|Invalid user')"
printf 'bt401=%s\n'    "$(awk '$9 == 401' /var/log/nginx/access.log 2>/dev/null | wc -l)"
printf 'banned=%s\n'   "$(fail2ban-client status 2>/dev/null | sed -n 's/.*Banned IP list: *//p' | wc -w)"
# /srv is the root fs on this box, /srv/media is the 3.6T USB library; the
# awk dedupes so the root fs is not reported twice.
df -P / /srv /srv/media 2>/dev/null |
  awk 'NR>1 && !seen[$6]++ {gsub("%","",$5); print "disk=" $6 ":" $5}'
REMOTE
}

# ── checks ──────────────────────────────────────────────────────────────────
check_tom() {
  host_begin tom
  if ! PROBE=$(probe_tom 2>/dev/null); then
    emit FAIL ssh "cannot reach $TOM_HOST (tailnet / power / boot)"
    host_end; return
  fi

  emit PASS boot "up $(get uptime), booted $(get boot)"

  local svc; svc=$(get svc)
  emit "$(svc_class "$svc")" service:petcam-static "$svc"

  local r f st
  r=$(get rpicam); f=$(get ffmpeg); st=$(get static)
  if [ "$r" = up ] && [ "$f" = up ] && [ "$st" = up ]; then
    emit PASS capture "rpicam-vid=up ffmpeg=up static=up"
  else
    emit FAIL capture "rpicam-vid=$r ffmpeg=$f static=$st"
  fi

  local th temp
  th=$(get throttled); temp=$(get temp)
  emit "$(throttle_class "$th")" power "throttled=$th temp=$temp"

  local age level
  age=$(get shot_age)
  emit "$(stat_class "$age" $((SHOT_STALE_H * 3600)))" shots "newest $(human_age "$age")"

  age=$(get frame_age)
  emit "$(stat_class "$age" "$FRAME_STALE_S")" frames "newest $(human_age "$age")"

  local b
  b=$(get boots); level=$(boots_class "$b")
  if [ "$level" = PASS ]; then
    emit PASS boots/24h "$b"
  else
    emit WARN boots/24h "$b in 24h — see docs/server/todo/tom-reboots-hang-2026-10-31.md"
  fi

  local af; af=$(get authfail)
  emit "$(auth_class "$af")" auth/24h "$af failed ssh logins"
  host_end
}

check_ralph() {
  host_begin ralph
  if ! PROBE=$(probe_ralph 2>/dev/null); then
    emit FAIL ssh "cannot reach $RALPH_HOST (the public gateway is down)"
    host_end; return
  fi

  emit PASS boot "up $(get uptime)"

  local line unit st
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    unit=${line%%:*}; st=${line#*:}
    emit "$(svc_class "$st")" "service:$unit" "$st"
  done <<< "$(getall svc)"

  local d; d=$(get detect)
  if [ "$d" = up ]; then
    emit PASS detector "petcam-detect.py up (snapshots + training pairs)"
  else
    emit FAIL detector "down — no detections, no new snapshots on the gallery"
  fi

  local p0; p0=$(get proton0)
  if [ "$p0" = up ]; then
    emit PASS proton0 "up (qBittorrent leak protection holds)"
  else
    emit FAIL proton0 "down — qBittorrent is bound to it, Proton VPN is off"
  fi

  local af b401 ban
  af=$(get authfail); b401=$(get bt401); ban=$(get banned)
  emit "$(auth_class "$af")" auth/24h "$af failed ssh logins"
  emit "$(auth_class "$b401")" bt-401 "$b401 rejected /bt/ requests (log lifetime)"
  emit PASS fail2ban "$ban banned right now"

  local mp pct
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    mp=${line%%:*}; pct=${line##*:}
    emit "$(disk_class $((100 - pct)))" "disk:$mp" "${pct}% used, $((100 - pct))% free"
  done <<< "$(getall disk)"
  host_end
}

check_ingress() {
  host_begin ingress
  local site code
  for site in "${SITES[@]}"; do
    code=$(curl -m "$HTTP_TIMEOUT" -s -o /dev/null -w '%{http_code}' "https://$site/" 2>/dev/null)
    emit "$(http_class "$code")" "http:$site" "${code:-timeout}"$([ "$code" = 000 ] && echo " (no response)")
  done
  # qBittorrent's /bt/ lives on nginx's default server, which the tunnel routes to.
  # It must answer 404 to tunnelled traffic (CF-Ray guard); 401 or 200 means the
  # guard is gone and the WebUI is back on the public internet with auth only.
  code=$(curl -m "$HTTP_TIMEOUT" -s -o /dev/null -w '%{http_code}' "https://andrewahale.com/bt/" 2>/dev/null)
  [ "$code" = 404 ] && emit PASS "bt-guard" "404 (not tunnelled)" \
    || emit FAIL "bt-guard" "${code:-timeout} — /bt/ answers through the tunnel"
  host_end
}

# ── summary log ─────────────────────────────────────────────────────────────
summary_line() {
  printf '%s tom=%s ralph=%s ingress=%s pass=%s warn=%s fail=%s\n' \
    "$(date +%Y-%m-%dT%H:%M:%S%z)" \
    "$TOM_STATUS" "$RALPH_STATUS" "$INGRESS_STATUS" "$PASS_N" "$WARN_N" "$FAIL_N"
}

prune_log() { # drop lines older than LOG_KEEP_DAYS (ISO date is the first field)
  local cutoff
  cutoff=$(date -d "-${LOG_KEEP_DAYS} days" +%F 2>/dev/null) ||
    cutoff=$(date -v-"${LOG_KEEP_DAYS}"d +%F 2>/dev/null) || cutoff=""
  [ -n "$cutoff" ] && [ -f "$HEALTH_LOG" ] || return 0
  awk -v c="$cutoff" 'substr($0, 1, 10) >= c' "$HEALTH_LOG" > "$HEALTH_LOG.tmp" &&
    mv "$HEALTH_LOG.tmp" "$HEALTH_LOG"
}

# ── selftest: all logic, no network, no hosts ───────────────────────────────
selftest() {
  local rc=0
  t() { # expected actual label
    if [ "$1" = "$2" ]; then printf 'ok   %s\n' "$3"
    else printf 'FAIL %s (want %s, got %s)\n' "$3" "$1" "$2"; rc=1; fi
  }

  t PASS "$(throttle_class 0x0)" "throttled 0x0"
  t FAIL "$(throttle_class 0x50000)" "throttled 0x50000 (under-voltage latched)"
  t FAIL "$(throttle_class 0x1)" "throttled 0x1"
  t FAIL "$(throttle_class '')" "throttled unreadable"

  t PASS "$(svc_class active)" "unit active"
  t FAIL "$(svc_class failed)" "unit failed"
  t FAIL "$(svc_class inactive)" "unit inactive"

  t PASS "$(stat_class 3600 $((SHOT_STALE_H * 3600)))" "shots 1h old"
  t PASS "$(stat_class 86400 $((SHOT_STALE_H * 3600)))" "shots exactly 24h old"
  t WARN "$(stat_class 90000 $((SHOT_STALE_H * 3600)))" "shots 25h old"
  t WARN "$(stat_class -1 $((SHOT_STALE_H * 3600)))" "shots dir missing"
  t PASS "$(stat_class 60 "$FRAME_STALE_S")" "frames 1m old"
  t WARN "$(stat_class 601 "$FRAME_STALE_S")" "frames 10m1s old"

  t PASS "$(boots_class 1)" "1 boot in 24h"
  t PASS "$(boots_class "$BOOT_WARN_MAX")" "BOOT_WARN_MAX boots is still normal"
  t WARN "$(boots_class $((BOOT_WARN_MAX + 1)))" "one over BOOT_WARN_MAX"
  t WARN "$(boots_class -1)" "boot count unreadable"

  t PASS "$(auth_class 3)" "3 failed logins"
  t PASS "$(auth_class "$AUTH_WARN_MAX")" "failed logins exactly at AUTH_WARN_MAX"
  t WARN "$(auth_class $((AUTH_WARN_MAX + 1)))" "one over AUTH_WARN_MAX"
  t WARN "$(auth_class -1)" "failed logins unreadable"

  t PASS "$(disk_class 50)" "disk 50% free"
  t WARN "$(disk_class $((DISK_MIN_PCT - 1)))" "disk just under DISK_MIN_PCT"
  t PASS "$(disk_class "$DISK_MIN_PCT")" "disk exactly DISK_MIN_PCT"

  t PASS "$(http_class 200)" "http 200"
  t PASS "$(http_class 302)" "http 302 (Cloudflare Access)"
  t PASS "$(http_class 401)" "http 401"
  t FAIL "$(http_class 503)" "http 503"
  t FAIL "$(http_class 000)" "http timeout"
  t FAIL "$(http_class '')" "http empty code"

  t 2h "$(human_age 7200)" "human_age 7200s"
  t 2d "$(human_age 180000)" "human_age 180000s"
  t none "$(human_age -1)" "human_age missing"

  PROBE=$'svc=nginx:active\nsvc=jellyfin:active\ndisk=/srv:4\nboot=x'
  t nginx:active "$(getall svc | head -1)" "getall keeps every value"
  t 2 "$(getall svc | wc -l | tr -d ' ')" "getall counts all svc lines"
  t active "$(printf '%s\n' "$PROBE" | sed -n 's/^svc=//p' | tail -1 | cut -d: -f2)" "svc split: state is the tail"
  t x "$(get boot)" "get returns a single value"

  TOM_STATUS=warn RALPH_STATUS=ok INGRESS_STATUS=ok PASS_N=7 WARN_N=1 FAIL_N=0
  t "tom=warn ralph=ok ingress=ok pass=7 warn=1 fail=0" \
    "$(summary_line | cut -d' ' -f2-)" "summary line shape"

  printf '\nselftest: %s\n' "$([ $rc -eq 0 ] && echo PASS || echo FAIL)"
  return $rc
}

# ── main ────────────────────────────────────────────────────────────────────
usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [ $# -gt 0 ]; do
  case $1 in
    --quiet) QUIET=1 ;;
    --selftest) selftest; exit $? ;;
    -h|--help) usage ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage ;;
  esac
  shift
done

check_tom
check_ralph
check_ingress

summary=$(summary_line)
[ -n "$QUIET" ] || printf '\n%s\n' "$summary"
printf '%s\n' "$summary" >> "$HEALTH_LOG"
prune_log

[ "$FAIL_N" -eq 0 ]
