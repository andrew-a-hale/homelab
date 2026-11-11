#!/bin/bash
# Documents -> Proton Drive via the official CLI (was rclone, see
# docs/backups/README.md). The ~/last-sync marker + fd guard just avoids
# talking to the API when nothing changed; the CLI itself skips unchanged
# files by content. Never deletes remote (rclone sync used to mirror).
set -euo pipefail
export PROTON_DRIVE_CREDENTIALS_STORE=pass
export PASSWORD_STORE_DIR=/home/andy/.password-store-proton
l=$(date "+%F %T")
if [[ -f /home/andy/last-sync ]] \
   && [[ -z $(fd --newer "$(cat /home/andy/last-sync)" . /home/andy/Documents) ]]; then
  echo "$l" > /home/andy/last-sync
  exit 0
fi
"$HOME/.local/bin/proton-drive" filesystem upload \
  -f create-new-revision -d merge /home/andy/Documents /my-files
echo "$l" > /home/andy/last-sync
