#!/usr/bin/env bash
# List explicitly installed packages whose binaries have not been read in N days.
# atime is the closest thing Arch has to "did I ever run this" (relatime updates
# it on first execution). Packages with no /usr/bin files are skipped: libraries
# and fonts are cleaned by `pacman -Rns` once their parent goes.
# Usage: pacman-atime-audit.sh [days]   (default 14)
set -euo pipefail
days=${1:-14}
ref=$(( $(date +%s) - days * 86400 ))
found=()
while read -r p; do
  read -r -a bins <<< "$(pacman -Ql "$p" | awk '$2 ~ /^\/usr\/bin\/[^/]+$/ {print $2}')"
  [[ ${#bins[@]} -gt 0 ]] || continue
  newest=$(stat -c %X "${bins[@]}" 2>/dev/null | sort -n | tail -1)
  [[ ${newest:-0} -lt $ref ]] && found+=("$p")
done < <(pacman -Qeq | sort)
if [[ ${#found[@]} -eq 0 ]]; then echo "nothing unused in $days days"; exit 0; fi
printf '%s\n' "${found[@]}" | sort
if command -v expac >/dev/null; then
  printf -- '--- %d packages, %s GiB\n' "${#found[@]}" \
    "$(expac -Q '%m' "${found[@]}" | awk '{s+=$1} END{printf "%.1f", s/1073741824}')" >&2
fi
