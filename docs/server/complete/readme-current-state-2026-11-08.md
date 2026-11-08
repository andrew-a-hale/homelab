# Every README now describes current state (2026-11-08)

**Status:** done. No infrastructure changed — documentation only, plus two broken
symlinks repaired.

## Task

Make each project README the current truth, and push chronology into
`docs/{project}/complete/`, per `AGENTS.md` ("update relevant README.md files"
+ "completed tasks move to complete/{brief}-{date}.md"). The trigger was the
security assessment, which found several READMEs describing a homelab that no
longer existed — e.g. `docs/media/README.md` still had Jellyfin 12.2 on Tom
reading media over NFS from Jason.

## What changed

| File | Was | Now |
|---|---|---|
| `docs/media/README.md` | Jellyfin on Tom, NFS from Jason, 2TB drive "when it arrives" | Jellyfin 12.4 + qBittorrent 5.3.0 on Ralph, `/dev/sda1` 3.6T at `/srv/media`, access URLs, verify commands, ceilings |
| `docs/website/README.md` | cloudflared on Tom, cron `nohup` watchdogs, petcam inside the website binary | Go app + nginx + tunnel all on Ralph, hostname table, deploy, the `WorkingDirectory` and `/static/dht.json` traps |
| `docs/office-temp/README.md` | DHT daemon on the Pi writing into the website repo | USB sensor on Ralph → `/srv/dht/dht.json` → nginx alias; `scripts/dht-writer.sh`, `dht.service`; calibration ceiling |
| `docs/server/README.md` | "Server Migration" narrative + option analysis + `// NOTE: install ubuntu` | Tom's current state (camera appliance), host facts, SSH names, package policy, live fault pointer, rebuild |
| `docs/petcam/README.md` | current state mixed with a 60-line reboot history and a Jev/benchmark chronicle | current state only (what runs where, rebuild, verify, data contract, knobs); history in three lines of pointers |
| `docs/ralph/README.md` | facts + "Tom only captures now / moved here 2026-11-07" history | facts, "what runs here", disk/boot/console, constraints |
| `docs/vpn/README.md` | redesign narrative, "Deleted 2026-10-23", "Bugs found & fixed" | the three jobs and how each works today, verify commands, ceilings |
| `docs/backups/README.md` | a `## History` section and a stale "`/mnt/storage` is jason's disk, the media Pi's NFS source" | current syncs/auth/failure triage; history points at `complete/proton-cli-migration` |
| `docs/security/README.md` | decisions inline | posture + chain only; decisions in `docs/security/complete/baseline-assessment-2026-11-08.md` |

Every README now ends with a **History:** line naming the `complete/` files that
hold the reasoning, so the chronology is still one hop away and never rots in the
front matter again.

New records created:

- `docs/server/complete/readme-current-state-2026-11-08.md` (this file)
- `docs/security/complete/baseline-assessment-2026-11-08.md`
- `docs/media/complete/dlna-rejected-2026-11-08.md` (the VIDAA/DLNA dead end, so
  the media README does not have to carry it)

## Facts corrected while verifying (not just reworded)

- Ralph's IP **is** pinned (DHCP reservation by MAC, 2026-11-08) — the README said
  "not pinned yet".
- qBittorrent is **5.3.0**, Jellyfin **12.4**, qBittorrent's WebUI has
  `LocalHostAuth=false` (nginx basic auth is the only door — `AGENTS.md`'s "strict
  whitelist" wording was wrong).
- `/srv/media` is `/dev/sda1`, ext4, 3.6T, 61.8G used — not "58G on Jason's NFS".
- Jellyfin's libraries are named `Movies`/`Shows` and resolve through the
  `/mnt/storage/media → /srv/media` symlink.
- Tom is Debian 13 (kernel 6.18.50+rpt), no docker, no ollama, no nginx.
- Jason's `~/.local/bin/vpn` and `vpn-soak` were **broken symlinks** into the
  pre-rename `~/projects/tom/scripts/`; re-pointed at
  `~/projects/homelab/scripts/`, and `vpn status` verified working.

## Not done

- `RUNBOOK.md` still tells a rebuild to "join the tailnet" on Tom; that flips with
  `../security/todo/lan-trust-2026-11-08.md` §5.
- `docs/vpn/design.md` stays as a design document on purpose.
- The `petcam.conf.bak-20261108` file on Ralph is a leftover backup, not
  documented anywhere (harmless, delete at will).
