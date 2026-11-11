#!/usr/bin/env bash
# nzb-tidy — move finished NZBGet episodes into Jellyfin's library layout.
#
# NZBGet unpacks every job into a folder named after the release *inside*
# /srv/media/tv, and Jellyfin reads each of those as its own bogus "Series" —
# one series per episode, matched to the wrong show. Run this after jobs finish:
#
#   nzb-tidy.sh --dry-run               # every series folder in the library
#   nzb-tidy.sh                         # same, for real
#   nzb-tidy.sh "Avatar - The Last Airbender (2005)"   # just one
#
# Every video under /srv/media/tv with an SxxEyy tag in its filename and all the
# words of a series name in its filename is moved to
#   <series>/Season NN/<series> - SxxEyy.<ext>
# and the emptied release folder is removed. Series folders are the ones with a
# year in the name, e.g. "Avatar - The Last Airbender (2005)" — the year matters,
# without it Jellyfin can match the 2024 live-action Avatar instead.
# Works on Jason (hops to Ralph) or on Ralph itself. See docs/media/README.md.
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = --dry-run ] && { DRY_RUN=1; shift; }

RALPH="${RALPH_HOST:-ralph}"
if [ "$(cat /etc/hostname)" = "$RALPH" ]; then
  sudo TARGETS="${1:-}" DRY_RUN="$DRY_RUN" bash -s
else
  # sshed args get re-parsed by the remote shell, so quote the name for it.
  ssh "$RALPH" "sudo TARGETS=$(printf %q "${1:-}") DRY_RUN=$DRY_RUN bash -s"
fi <<'EOF'
set -euo pipefail
lib=/srv/media/tv
cd "$lib"

targets=${TARGETS:-}
if [ -z "$targets" ]; then   # every series folder: has a year, is not a release dir
  targets=$(for d in */; do
    case "${d%/}" in
      *" ("[0-9][0-9][0-9][0-9]")") echo "${d%/}" ;;       # "Show (Year)"
    esac
  done)
else
  [ -d "$targets" ] || { echo "no such series folder: $lib/$targets" >&2; exit 1; }
fi

norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]\+/./g'; }
total=0
while IFS= read -r target; do
  [ -n "$target" ] || continue
  show=${target% (*}                       # "Avatar - The Last Airbender"
  key=${show// - / }                       # words that must appear in the filename
  key=$(norm "$key")
  moved=0
  while IFS= read -r -d '' f; do
    case "$f" in "./$target/"*) continue ;; esac      # already in place
    b=${f##*/}
    lname=$(norm "${b%.*}")
    se=$(printf '%s' "$b" | grep -oE 'S[0-9]{2}E[0-9]{2}' | head -1) || continue
    ok=1
    for w in ${key//./ }; do case "$lname" in *"$w"*) ;; *) ok=0 ;; esac; done
    [ "$ok" = 1 ] || continue
    dest="$target/Season ${se:1:2}/$show - $se.${b##*.}"
    if [ -e "$dest" ]; then echo "keep (exists): $dest"; continue; fi
    echo "${b:0:70}  ->  $dest"
    moved=$((moved + 1))
    [ "$DRY_RUN" = 1 ] && continue
    mkdir -p "${dest%/*}"
    mv -n "$f" "$dest"
    rmdir "${f%/*}" 2>/dev/null || true        # drop the emptied release folder
  done < <(find . -type f \( -name '*.mkv' -o -name '*.mp4' -o -name '*.avi' \) -print0)
  [ "$moved" = 0 ] || echo "  $moved -> $target"
  total=$((total + moved))
  if [ "$moved" -gt 0 ] && [ "$DRY_RUN" = 0 ]; then
    chown -R nzbget:jellyfin "$target"
    chmod -R g+rw "$target"
  fi
done <<< "$targets"

echo "$total file(s) tidied"
if [ "$total" -gt 0 ] && [ "$DRY_RUN" = 0 ]; then
  echo "Jellyfin picks these up on its next scan (~30 min), or: sudo systemctl restart jellyfin"
fi
EOF
