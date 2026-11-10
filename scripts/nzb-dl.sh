#!/usr/bin/env bash
# nzb-dl — search a free usenet indexer and hand the post to NZBGet on Ralph.
#
#   nzb-dl.sh search "gurren lagann" [--nzbking]
#   nzb-dl.sh add <details-id|details-url> <Movies|Series|Music|Software> [--nzbking] [--force] [--dry-run]
#   nzb-dl.sh status
#   nzb-dl.sh history
#   nzb-dl.sh remove <job-id>
#
# Runs on Jason or Ralph (or any box with curl+python3+ssh) — on Ralph it skips the
# ssh hop; NZBGet itself is loopback-only
# on Ralph, so every jsonrpc call is `ssh ralph curl 127.0.0.1:6789`.
# See docs/media/README.md and the usenet-download skill.
set -euo pipefail

UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36'
RPC='http://127.0.0.1:6789/jsonrpc'
RALPH="${RALPH_HOST:-ralph}"
INDEXER=binsearch
DRY_RUN=0
FORCE=0

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# When this already is Ralph, skip the ssh hop (and its host-key trust).
if [ "$(cat /etc/hostname 2>/dev/null)" = "$RALPH" ]; then
  rpc() { curl -s -m ${2:-120} -d @- $RPC ; }
else
  rpc() { ssh "$RALPH" "curl -s -m ${2:-120} -d @- $RPC" ; }
fi

# jsonrpc answers are pretty-printed; parse one field of the first result item.
rpc_field() { python3 -c 'import json,sys; r=json.load(sys.stdin); print(r.get("result",r.get("error")))'; }

fetch() { # fetch <url> <outfile>
  curl -sSL -m 60 -A "$UA" -o "$2" -w '%{http_code}' "$1"
}

cmd_search() {
  local q="$1" html
  html=$(mktemp)
  case "$INDEXER" in
    binsearch) fetch "https://www.binsearch.info/search?$(python3 -c 'import sys,urllib.parse;print(urllib.parse.urlencode({"q":sys.argv[1]}))' "$q")" "$html" >/dev/null ;;
    nzbking)   fetch "https://nzbking.com/search/?$(python3 -c 'import sys,urllib.parse;print(urllib.parse.urlencode({"q":sys.argv[1]}))' "$q")" "$html" >/dev/null ;;
  esac
  python3 - "$html" "$INDEXER" <<'PY'
import html as htmllib, json, re, sys
html, idx = sys.argv[1], sys.argv[2]
raw = open(html, encoding='utf-8', errors='replace').read()
if idx == 'nzbking':
    rows = []
    for block in raw.split("class='search-result'")[1:]:
        idm = re.search(r"/details:([0-9a-f]+)/", block)
        if not idm: continue
        subj = re.search(r"<div class='search-subject'>(.*?)<br>", block, re.S)
        title = re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', subj.group(1))).strip() if subj else '?'
        size = re.search(r'size:\s*(\S+)', block)
        age  = re.search(r"class='search-age'>(.*?)</div>", block, re.S)
        rows.append((idm.group(1), htmllib.unescape(title), size.group(1) if size else '?',
                     re.sub(r'<[^>]+>', '', age.group(1)).strip() if age else '-'))
else:
    # Next.js flight payload: decode each self.__next_f.push([1,"..."]) string
    # literal, join, then read plain JSON out of it.
    dec, parts, i = json.JSONDecoder(), [], 0
    while True:
        i = raw.find('self.__next_f.push(', i)
        if i < 0: break
        i += len('self.__next_f.push(')
        try: val, _ = dec.raw_decode(raw, i)
        except Exception: continue
        if isinstance(val, list) and len(val) > 1 and isinstance(val[1], str): parts.append(val[1])
    payload = ''.join(parts)
    # One row = one /details link up to the next one; a fixed-size window cuts
    # off the size/age spans for long subjects.
    hits = list(re.finditer(r'"href":"/details/([A-Za-z0-9_-]+)"', payload))
    rows = []
    for n, m in enumerate(hits):
        end = hits[n + 1].start() if n + 1 < len(hits) else len(payload)
        win = payload[m.end():end]
        subj = re.search(r'"children":"((?:[^"\\]|\\.)*)"', win)
        size = re.search(r'"children":"(\d+(?:\.\d+)?[KMGT]B)"', win)
        age  = re.search(r'"children":"(\d+ (?:second|minute|hour|day|week|month|year)s?)"', win)
        rows.append((m.group(1),
                     json.loads('"%s"' % subj.group(1)) if subj else '?',
                     size.group(1) if size else '?',
                     age.group(1) if age else '?'))
if not rows: sys.exit('no results (indexer down, or the query really has nothing)')
for i, subj, size, age in rows:
    print('%-24s %-10s %-9s %s' % (i, size, age, subj))
PY
  rm -f "$html"
}

cmd_add() {
  local ref="$1" cat="${2:-}" id nzb tmp rc
  id=$(printf '%s' "$ref" | sed -e 's#.*/details[/:]\([A-Za-z0-9_-]*\).*#\1#' -e 's#.*/details/##')
  [ -n "$id" ] || usage
  # Empty category silently parks the job in /srv/media/downloads/complete,
  # where Jellyfin never looks — Cowboy Bebop sat there for a night. Refuse it.
  case "$cat" in Movies|Series|Music|Software) ;; *) echo "category required: Movies|Series|Music|Software (got '$cat')" >&2; exit 2 ;; esac
  tmp=$(mktemp --suffix=.nzb)
  case "$INDEXER" in
    binsearch) rc=$(fetch "https://www.binsearch.info/nzb?id=$id" "$tmp") ;;
    nzbking)   rc=$(fetch "https://nzbking.com/nzb:$id/" "$tmp") ;;
  esac
  # A details id gives the whole post; the /nzb endpoint may still hand back an
  # HTML page when the post needs per-file selection, so check for real XML.
  if ! grep -q '<nzb' "$tmp"; then
    echo "no NZB from indexer (http $rc, $(stat -c%s "$tmp") bytes): the id is per-file or the post is gone." >&2
    echo "open the details page and copy the collection id from the form's hidden 'id' input." >&2
    exit 1
  fi
  echo "fetched $(grep -c '<file ' "$tmp") files, $(du -h "$tmp" | cut -f1) of index" >&2
  if [ "$DRY_RUN" = 1 ]; then echo "dry run, not queueing" >&2; rm -f "$tmp"; return 0; fi

  python3 - "$tmp" "$cat" "$FORCE" <<'PY' > /tmp/nzb-dl-append.$$.json
import base64, html, json, re, sys
path, cat, force = sys.argv[1:4]
blob = open(path, 'rb').read()
# The job name becomes the folder in /srv/media/{tv,movies}, so take it from the
# post's own subject instead of an opaque id.
subj = re.search(rb'<file [^>]*subject="([^"]*)"', blob)
name = 'nzb-dl.nzb'
if subj:
    name = html.unescape(subj.group(1).decode('utf-8', 'replace'))
    name = re.sub(r'^\s*\[\d+/\d+\]\s*-?\s*', '', name)   # [01/39] -
    name = re.sub(r'"?\s*yEnc\s*$', '', name)              # yEnc tail
    name = re.sub(r'\.(part\d+|vol\d+\+\d+|rar|par2)$', '', name)  # first-file suffix
    name = re.sub(r'[\x00-\x1f/]', '-', name).strip(' "')[:120]
print(json.dumps({"method": "append", "params": [
    name + '.nzb', base64.b64encode(blob).decode(),
    cat, 0, False, False, "", 0, "force" if force == "1" else "score", []]}))
PY
  local resp
  resp=$(rpc < /tmp/nzb-dl-append.$$.json | tee /tmp/nzb-dl-resp.$$.json)
  rm -f /tmp/nzb-dl-append.$$.json
  echo "$resp"
  python3 - /tmp/nzb-dl-resp.$$.json <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
if 'error' in r: sys.exit('NZBGet error: %s' % r['error'].get('message'))
if r['result'] < 0:
    sys.exit('NZBGet refused the job (-1) — almost always a dupe, a bad category, '
             'or post-processing disabled. Read: ssh ralph sudo journalctl -u nzbget -n 30\n'
             'Retry with --force (DupeMode=force) if the log says "dupe".')
print('queued as job %s' % r['result'])
PY
  rm -f /tmp/nzb-dl-resp.$$.json "$tmp"
}

cmd_status() {
  rpc 10 <<< '{"method":"status"}' | python3 -c '
import json,sys; r=json.load(sys.stdin)["result"]
print("rate %.1f MB/s | remaining %d MB | %s" % (r["DownloadRate"]/1e6, r["RemainingSizeMB"],
      "PAUSED" if r["DownloadPaused"] else "active"))'
  rpc 10 <<< '{"method":"listgroups"}' | python3 -c '
import json,sys
for g in json.load(sys.stdin)["result"]:
    print("%-60s %-8s %-11s health %-4s left %6d MB" % (g["NZBName"][:60], g["Category"],
          g["Status"], g.get("Health"), g["RemainingSizeMB"]))'
}

cmd_history() {
  rpc 10 <<< '{"method":"history"}' | python3 -c '
import json,sys
for g in json.load(sys.stdin)["result"]:
    print("%-60s %-8s %-9s %s" % (g["Name"][:60], g["Category"], g["Status"], g.get("Health")))'
}

cmd_remove() {
  # GroupDelete takes (Command, Offset, Text, IDs) — Text must be a string.
  printf '{"method":"editqueue","params":["GroupDelete",0,"",[%s]]}' "$1" | rpc 10 -
}

[ $# -ge 1 ] || usage
cmd=$1; shift
args=()
for a in "$@"; do
  case "$a" in
    --nzbking) INDEXER=nzbking ;;
    --force)   FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) args+=("$a") ;;
  esac
done
case "$cmd" in
  search)  [ ${#args[@]} -ge 1 ] || usage; cmd_search "${args[0]}" ;;
  add)     [ ${#args[@]} -ge 1 ] || usage; cmd_add "${args[0]}" "${args[1]:-}" ;;
  status)  cmd_status ;;
  history) cmd_history ;;
  remove)  [ ${#args[@]} -ge 1 ] || usage; cmd_remove "${args[0]}" ;;
  *) usage ;;
esac
