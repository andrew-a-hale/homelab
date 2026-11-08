# Daily homelab health check (2026-11-08)

**Date:** 2026-11-08
**Status:** built and merged. **Not yet on a timer** — the check runs when a human
or an agent runs it. Scheduling is the one open piece.
**Ticket:** `TODO.md` → "Setup a daily task to check if all the systems are working".

Before this the homelab had no monitoring at all: the only signals were a 14-day
petcam `detections.log` and a `tom-health` cron line in journald. Every outage was
found by accident — that is how a ~12 resets/day reboot problem stayed "unexplained
for a week" while `docs/server/todo/tom-reboots-hang-2026-10-31.md` waited for a
dump nobody read.

## Decision

One bash script, no dependencies beyond `ssh` and `curl`, read-only on every host:
`scripts/homelab-health.sh`. Plus `skills/homelab-health/SKILL.md` so an agent
knows when to run it and what a failure means.

- **Checks Tom** (`ssh tom`): petcam unit + capture/detector processes, throttled
  flags, newest still in `/dev/shm` (stale > 10 min), newest shot in
  `~/petcam/shots` (stale > 24 h), and the **boot count in the last 24 h** — more
  than 3 is a WARN that points straight at the reboot doc.
- **Checks Ralph** (`ssh ralph`): nginx, cloudflared, jellyfin, qbittorrent, the
  `proton0` interface (qBittorrent's leak protection depends on it), disk free on
  `/` and `/srv/media`.
- **Checks the public ingress** with `curl`: andrewahale.com, petcam, jellyfin. Any
  real HTTP response passes (Cloudflare Access answers 302/401 when healthy); a
  5xx or timeout is a FAIL.
- **Appends one line per run** to `~/homelab-health.log` (`$HEALTH_LOG` overrides),
  pruned to 90 days. That log is the uptime history the repo did not have.
- Exit code is non-zero on any FAIL, `--quiet` prints only WARN/FAIL, and
  `--selftest` exercises the threshold logic without touching the network.

Ran for real before merging:

```
tom=warn ralph=ok ingress=ok pass=17 warn=1 fail=0
WARN boots/24h  4 in 24h — see docs/server/todo/tom-reboots-hang-2026-10-31.md
```

That WARN is the point: it caught Tom's resets on the first run, the day the dump
was finally read. First useful signal ever produced about them.

## Deliberate non-goals (so this stays 300 lines, not a platform)

No agent, no metrics store, no JSON, no retries, no alerting service: a line in a
text file and an `&&`-able exit code. Reboot forensics stay in
`docs/server/todo/tom-reboots-hang-2026-10-31.md` — this only says "it happened
again". Thresholds live in one block at the top of the script, each with the reason
it has that value.

## Still open

1. **Schedule it.** The skill documents both a systemd user timer (with
   `loginctl enable-linger`) and a cron line. It has to run from a machine that can
   `ssh` both hosts — `ssh ralph` *from* Ralph fails host-key verification, so
   "just put it on the always-on box" does not work as-is.
2. Extend it if a failure mode is ever missed twice. Not before.
