#!/bin/bash
# Weekly Proton Drive backup via the official Proton Drive CLI.
# Replaces the rclone protondrive backend (kept dying on stale 2FA tokens).
# Session token lives in a dedicated pass store (see docs/backups/README.md).
set -euo pipefail
export PROTON_DRIVE_CREDENTIALS_STORE=pass
export PASSWORD_STORE_DIR=/home/andy/.password-store-proton
"$HOME/.local/bin/proton-drive" filesystem upload \
  -f create-new-revision -d merge /mnt/storage/backup /my-files
# uploads the `backup` folder itself into /my-files (folder uploads nest as
# subfolders — merging into /my-files/backup directly would make backup/backup)
