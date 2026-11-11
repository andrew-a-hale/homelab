---
name: homelab-health
description: >
  Run and read the daily homelab health check (Tom, Ralph, public ingress).
  Use when the user asks is the homelab up, check the systems, daily check,
  is Tom alive, is the site down, why is petcam dead, health report, uptime
  history, or wants monitoring/an alert before the next outage. Triggers:
  is the homelab up, check the systems, daily check, is Tom alive, health,
  monitoring, uptime, 502, site down. Covers scripts/homelab-health.sh, its
  log, and the three known failure playbooks.
---

# Homelab health check

`scripts/homelab-health.sh` — one bash script, no dependencies beyond `ssh` and
`curl`, read-only on every host. Run it from any machine on the tailnet:

```bash
cd ~/projects/homelab && scripts/homelab-health.sh          # full report
scripts/homelab-health.sh --quiet                           # only WARN/FAIL
scripts/homelab-health.sh --selftest                        # logic only, no hosts
```

Exit `0` = all PASS/WARN, `1` = at least one FAIL. WARN does not change the exit
code, so `scripts/homelab-health.sh && deploy` is safe. One ssh round-trip per
host (`BatchMode`, 8 s connect timeout) and a 10 s curl, so a dead host costs
seconds, not minutes. Overridable with env vars: `TOM_HOST`, `RALPH_HOST`,
`HEALTH_LOG`. All thresholds sit in the marked block at the top of the script.

## What each check means

| Check | Host | Means |
|---|---|---|
| `boot` | tom, ralph | uptime and boot time. Informational — the boot count is the signal |
| `service:petcam-static` | tom | `systemctl is-active petcam-static` — the tailnet-only file server for `/dev/shm/petcam`. The gallery/live app itself is on ralph |
| `capture` | tom | `rpicam-vid`, `ffmpeg` and the `8081` static server all alive. Any one down = no stream and/or no stills for the detector |
| `power` | tom | `vcgencmd get_throttled` must be `0x0` (any other value latches until a power cycle) plus SoC temp, shown for context only |
| `shots` | tom | age of the newest file in `~/petcam/shots`; detector saves ~134/day, so >24h means the detector is wedged (WARN) |
| `frames` | tom | age of the newest file in `/dev/shm/petcam/frames`; capture is 1 fps, so >10 min means the pipeline is dead even if the processes linger |
| `boots/24h` | tom | boots started in the last 24h, counted from `journalctl --list-boots -o json` (the `--since` flag is ignored by `--list-boots`, hence the JSON). >3 is the reboot bug flaring |
| `auth/24h` | tom, ralph | failed SSH logins in the last 24h (`Failed password|Invalid user`). >20 is a WARN: the internet is trying, or something on the LAN is |
| `bt-401` | ralph | 401s in `/var/log/nginx/access.log` (basic-auth failures on `/bt/`), whole log lifetime. Bots probing the old public `/bt/` path; the guard below now turns those into 404s |
| `bt-guard` | ingress | `https://andrewahale.com/bt/` must be **404**. It sits on nginx's default server, which the tunnel routes to, so 401/200 here means the `CF-Ray` guard is gone and the qBittorrent WebUI is public again |
| `fail2ban` | ralph | banned IPs right now, from `fail2ban-client status` (jails: `sshd`, `nginx-http-auth`, `jellyfin`). Informational |
| `service:{nginx,cloudflared,jellyfin,qbittorrent-nox@qbittorrent}` | ralph | the public entry point and the apps behind it |
| `proton0` | ralph | WireGuard link for qBittorrent leak protection; qBit is bound to it, so no `proton0` = no torrents |
| `disk:/`, `disk:/srv/media` | ralph | percent free; `/srv` is the root fs here, the 3.6T library is `/srv/media` and is reported separately (the probe dedupes by mountpoint) |
| `http:{andrewahale.com,petcam.andrewahale.com,jellyfin.andrewahale.com}` | anywhere | one GET per hostname. Any 1xx–4xx is healthy (302/401 = Cloudflare Access working); 5xx or a timeout (`000`) is a FAIL |

## The health log

Every run appends exactly one line (also when `--quiet`):

```
2026-11-08T15:33:17+1000 tom=warn ralph=ok ingress=ok pass=17 warn=1 fail=0
```

`~/homelab-health.log` by default (`$HEALTH_LOG` to move it), pruned to ~90 days
on each run. That line is the uptime history the repo otherwise lacks.

```bash
tail -n 30 ~/homelab-health.log            # recent runs
grep -c 'fail=[1-9]' ~/homelab-health.log  # how many runs failed
grep -v 'tom=ok' ~/homelab-health.log      # every run Tom was unhealthy
```

## Known-failure playbooks

1. **`boots/24h` WARN on Tom, `boot` uptime minutes** — Tom is hard-resetting
   itself again. Read `docs/server/todo/tom-reboots-hang-2026-10-31.md`: cause is
   still open (~1 reset/hour when live), capture instrumentation is what is left:
   `scripts/tom-kmsg.sh` on Tom plus ramoops (`tom-trace.sh` and the outside-in
   watcher were deleted 2026-11-11 as not required). Remaining fix is physical
   (camera ribbon reseat / PSU). Do not "fix" it by disabling the
   hardware watchdog — that turns a reboot into a hang.
2. **`frames` WARN or `capture` FAIL** — the petcam stream is dead. Follow
   `docs/petcam/README.md` §Verify: `ssh ralph 'curl -s http://127.0.0.1:8082/shots.json'`,
   `ssh tom 'ls /dev/shm/petcam/index.m3u8'`, `ssh tom 'tail -50 ~/petcam/logs/rpicam.log'`.
   Cron relaunches `petcam.sh` and systemd restarts `petcam-detect` on ralph, so a
   persistent FAIL means it is dying on start, not missing. Restart with the
   bracketed pattern (`pkill -f "petcam-detect[.]py"`) — an unbracketed pattern
   self-matches the command that runs it.
3. **`http:*` FAIL or intermittent 502** — the public path is
   Cloudflare → `cloudflared` → nginx on Ralph (:80) → app. Check in that order:
   ralph reachable (`ssh ralph uptime`), `service:cloudflared`, `service:nginx`,
   then the app. `docs/ralph/` has the ingress shape
   (`nginx-ralph.conf`, `cloudflared-config.yaml`) and the known ceiling: every
   public request crosses one wifi link (Tom→Ralph measured 0.74 MB/s), so
   slow ≠ down. A 302 on petcam is success, not a redirect bug.

## The daily run — installed on jason

Live as systemd **user** units on jason (daily 08:00, linger on), not Ralph: the
script `ssh`es both hosts and `ssh ralph` *from* Ralph fails host-key verification.
Same recipe for any other always-on tailnet machine; adjust `%h` if the checkout is
not `~/projects/homelab`.

```ini
# ~/.config/systemd/user/homelab-health.service
[Unit]
Description=Homelab daily health check

[Service]
Type=oneshot
ExecStart=%h/projects/homelab/scripts/homelab-health.sh --quiet
```

```ini
# ~/.config/systemd/user/homelab-health.timer
[Unit]
Description=Run the homelab health check daily

[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now homelab-health.timer
systemctl --user list-timers homelab-health.timer
systemctl --user status homelab-health.service   # a FAIL shows as a failed unit
loginctl enable-linger "$USER"                   # if the box may be logged out
```

Same thing in cron, with output mailed only when something is wrong (`--quiet`
is silent when everything passes):

```cron
MAILTO=andy
17 8 * * * ~/projects/homelab/scripts/homelab-health.sh --quiet
```

A failed `--selftest` before committing a change to the script means the
threshold logic, not the homelab, is broken.

## Deliberate non-goals

No agent, no metrics store, no JSON, no retries: a daily line in a text file and
`&&`-able exit code. `docs/server/todo/tom-reboots-hang-2026-10-31.md` stays the
place for reboot forensics; this only says "it happened again".
