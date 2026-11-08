# Backups

Two syncs, both from **Jason** to **Proton Drive**, both through the official
Proton Drive CLI.

## What syncs

| Local | Remote | Schedule |
|---|---|---|
| `/mnt/storage/backup/` (Andrew/, Photos/, callum-backup/ — 389M) | `proton:/backup` → `/my-files/backup` | weekly, Mon 00:00 (`protondrive-backup.timer`) |
| `/home/andy/Documents/` (95 files, 12M) | `proton:/documents` → `/my-files/Documents` | always-on (`protondrive-documents.service`) |

Neither is a full-system backup. `RUNBOOK.md` says it plainly: nothing is backed
up by design, secrets are regenerated from their providers, and the media library
**is** the one thing with no second copy.

## How it runs

| Piece | Where |
|---|---|
| CLI | `~/.local/bin/proton-drive` (linux-x64, from proton.me/download/drive/cli) |
| Units + scripts | `/home/andy/services/`: `protondrive-backup.timer` + `.service` → `protondrive-weekly.sh`; `protondrive-documents.service` (`Restart=always`, 5-min poll) → `protondrive-documents.sh` |
| Logs | `journalctl -u protondrive-backup.service`, `-u protondrive-documents.service` |

Command shape, both: `filesystem upload -f create-new-revision -d merge
<local-folder> /my-files`. Notes that matter:

- Uploading a folder *into* its own parent nests it (`/my-files/backup` would make
  `backup/backup`) — the target is `/my-files`, and the folder name merges.
- **Never deletes remote.** Deleted local files stay on Drive. Changed files keep
  old revisions (Proton-side history).
- Remote paths are virtual: user content lives under `/my-files`, not `/`.
- The documents sync keeps a `~/last-sync` + `fd --newer` guard so an idle 5-min
  tick costs no API call (guard path runs in ~9 ms).

Verify a run: `proton-drive filesystem size /my-files/backup` against
`du -sh /mnt/storage/backup` — they should roughly match.

## Auth

Browser login, once per session lifetime:
`proton-drive auth login` (password + 2FA never touch the command line).

The session token sits in a **dedicated pass store** —
`PROTON_DRIVE_CREDENTIALS_STORE=pass`, `PASSWORD_STORE_DIR=~/.password-store-proton`
— guarded by its own passphrase-less GPG key (`proton-drive-backup (session token
only)`). That is deliberate: the weekly timer fires headless, libsecret needs an
unlocked GUI session, and the main key is passphrase-protected. It guards one
Drive session token on a LUKS-encrypted disk.

**Both env vars are required** when re-authenticating, or the new session lands in
the wrong store:

```bash
PROTON_DRIVE_CREDENTIALS_STORE=pass PASSWORD_STORE_DIR=/home/andy/.password-store-proton proton-drive auth login
```

## When it breaks

1. **Auth.** `proton-drive filesystem list /my-files/backup` with the two env vars.
   If it asks you to log in, re-auth above. A Proton-side expiry shows in the
   journal as an auth error.
2. **Disk.** The source is Jason's internal disk (`/mnt/storage/backup`). The
   media library is *not* involved — it lives on Ralph's USB drive.
3. **GPG.** The dedicated key must import without pinentry. If a `~/.gnupg`
   restore ever re-adds a passphrase, headless runs break.

Leftovers: `rclone.service` / `rclone.timer` are **masked** — the old rclone
machinery, kept masked rather than deleted.

History: [`complete/proton-cli-migration-2026-10-22.md`](complete/proton-cli-migration-2026-10-22.md)
— the rclone era, the nine months of silent 2FA failures, and why the official
CLI replaced it.
