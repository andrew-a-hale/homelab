# RUNBOOK.md audit against the live boxes (2026-11-08)

**Date:** 2026-11-08
**Status:** open — findings and gaps recorded, only unambiguous factual errors fixed
**Scope:** `RUNBOOK.md` walked top to bottom and checked against `ssh ralph`,
`ssh tom` and this machine (Jason) with read-only commands. No host was changed.

Ticket context: AGENTS.md claims "if the Raspberry Pi dies it should be very
simple to move to Jason or Rose". Facts taken as given and confirmed here:
Tom runs petcam (plus one leftover, see below), Ralph is the only public
ingress, Tom is wifi-only and resets often
([`tom-reboots-hang-2026-10-31.md`](tom-reboots-hang-2026-10-31.md)).

## Findings: step → status → problem

| Runbook step | Status | Problem |
|---|---|---|
| Ralph §1.1 Arch + LUKS on NVMe | match | True (Arch, LUKS2 `nvme0n1p2`, systemd-boot, btrfs subvols `@ @home @log @pkg @snapshots`, ESP `/boot`, TPM2 token 0) but **none of that layout is written down**. The real install is `scripts/ralph-arch-install.sh` + `scripts/ralph-finish.sh`, which RUNBOOK never mentions. |
| §1.1 "TPM2 auto-unlock is optional (see TODO)" | misleading | It is **enrolled and load bearing** on the live box (`systemd-cryptenroll`, token 0, PCR 7). Without it every Ralph reboot waits for a passphrase at a console that has no keyboard. TODO tracks the Secure-Boot/seal debate, not whether TPM is in use. |
| §1.2 media drive ext4 label `media`, `/srv/media`, `nofail`, symlink | match | `sda1` ext4 `LABEL=media` → `/srv/media`; fstab `defaults,nofail,x-systemd.device-timeout=15`; `/mnt/storage/media -> /srv/media`. 62G used of 3.6T. Gap: ownership (`drwxrwxrwx andy:jellyfin`) and the `jellyfin` group are not stated. |
| §1.3 `pacman -S jellyfin …` | **wrong** | There is no `jellyfin` package: live is `jellyfin-server jellyfin-web jellyfin-ffmpeg` (12.4). `go` is missing from the list although §2.2 builds a Go binary. |
| §1.3 "Guix is an optional layer; nothing needs it" | resolved | At audit time `guix-daemon.service` + `gnu-store.mount` were enabled with only `nss-certs` in the root profile, so the daemon was pure cost. **Removed 2026-11-08** ([why](../ralph/complete/no-guix-2026-11-08.md)); RUNBOOK no longer mentions Guix at all. |
| §2.1 clone repo + `andrewahale.com` | match | `/srv/website/web` is a git clone with `origin git@github.com:andrew-a-hale/andrewahale.com.git`. Needs a GitHub key — the secrets table named Tom only (fixed). |
| §2.2 website binary + unit | match | `andrewhale-web.service` is exactly as described (`User=andy`, `WorkingDirectory=/srv/website/web`, `Restart=always`), listening `127.0.0.1:8080`. Note: that source dir still contains `petcam.go` (pre-split) — left to the website agent. |
| §2.3 nginx: copy `nginx-ralph.conf` + `petcam.conf` | **partial / stale** | Live `/etc/nginx/conf.d/` has three files: `00-upgrade-map.conf`, `ralph.conf`, `petcam.conf`. Repo `docs/ralph/nginx-ralph.conf` embeds the map **and** the petcam server block but has **no `/bt/` location** → following the runbook gives no qBittorrent UI at `:80/bt/`. `docs/ralph/petcam.conf` does not exist in the repo, so "if present" is never true and petcam ingress is lost. |
| §2.3 "Everything is reached through nginx on :80" | **wrong** | `jellyfin.andrewahale.com` is in the cloudflared ingress pointed straight at `127.0.0.1:8096`, bypassing nginx (its BaseUrl already carries `/jf`). |
| §2.4 DHT unit + `scripts/dht-writer.sh` | match | Installed `/usr/local/bin/dht-writer` is byte-identical to the repo script; `dht.service` runs; `/srv/dht/dht.json` is live (`25.2 °C / 28.3 %`). Live unit carries an extra inert `DynamicUser=no` not shown in RUNBOOK. |
| §3 Jellyfin libraries `/srv/media/media/{movies,tv}` | **wrong** | Live library links are `/mnt/storage/media/movies` and `/mnt/storage/media/tv` (no extra `media/` level). `BaseUrl=/jf` confirmed in `/etc/jellyfin/network.xml`. Missing from RUNBOOK: the `jellyfin.service.d/` drop-in `RequiresMountsFor=/srv/media`, and that `/srv/media/music` exists but is **not** a library (only Movies + Shows). |
| §3 qBittorrent "bind the interface to `10.2.0.2`" | **wrong** | Live config binds by interface name: `Session\Interface=proton0`, `Session\InterfaceName=proton0`. `LocalHostAuth=false` and WebUI on `127.0.0.1:8081` confirmed; `ExecStartPre` does wait for `proton0` (60 × 2 s); `/etc/nginx/htpasswd` user is `andy`. |
| §3 Proton VPN: `wg-quick@proton0` enabled + `proton-guard.timer` | **partly inaccurate** | `proton0` is up (10.2.0.2/32, live handshakes, `Table=off`, uidrange 960 rule) and the guard timer fires every 5 min. But `wg-quick@proton0` is enabled **and has no journal entries at all this boot** — it never starts; the interface is raised by `proton-guard.sh` running `wg-quick up` outside systemd. RUNBOOK also never says to install `scripts/proton-guard.sh` (fixed), and `proton-guard.{service,timer}` exist only on the box, not in the repo. |
| §3 Cloudflared unit + config | match | `/etc/cloudflared/config.yaml` is identical to `docs/ralph/cloudflared-config.yaml`; tunnel `5b7e3976…`; credentials + `cert.pem` are `0600 cloudflared`. Service unit matches the repo copy. |
| §3 Tailscale up + disable key expiry + ACL `ssh: accept` | not applied | Tailnet is up (`ralph` 100.108.202.106, `tom` 100.77.132.110), but node keys still expire (ralph 2027-05-06, tom 2027-01-14), so the console steps are an open TODO, not a runbook error. |
| §3 ufw block | match | `ufw status verbose` is the same rule set verbatim: default deny in / allow out, `192.168.1.0/24`, `100.64.0.0/10`, `41641/udp`, active. |
| Tom: "Debian, clone, `cd petcam && make`, unit User=tom" | match | Debian 13 (trixie); repo at `~/projects/homelab`; `petcam.service` is `User=tom`, `BIND=100.77.132.110`, `PORT=8080`, `Restart=always`, 0 restarts, listening on the tailnet address only. |
| Tom: "petcam only … Nothing else belongs on Tom" | **wrong** | `andrewahale-web.service` is enabled and active on Tom: `User=tom`, `WorkingDirectory=/home/tom/projects/andrewahale.com/web`, listening `127.0.0.1:8080` (leftover from before the split). |
| Tom: camera + model dirs | match | `~/petcam/{model,tolabel,training,shots,logs}` all present. |
| Tom: "training data also exists on the laptop under `~/petcam-train`" | **wrong host** | `~/petcam-train` is on **Jason** (desktop, RTX 3070), not on Rose (the laptop). Nothing on Tom. |
| Tom: uptime "~90% is fine" | optimistic | 5 boots today so far (14:22, 14:25, 15:08, …); 87 boots in 7 days per the ticket doc. Only petcam is affected — the claim is about load bearing-ness, which holds. |
| Secrets: cloudflared / VPN / tailnet / Jellyfin / qBit rows | match | `/etc/cloudflared/{config.yaml,cert.pem,<tunnel-id>.json}` present; `wg show` returns a live peer; Jellyfin and qBit state live where the table says. |
| Secrets: "GitHub push key — Tom's `~/.ssh/id_ed25519`" | **incomplete** | Ralph has its own `id_ed25519`, Jason has one too, Tom has one. A rebuild stalls at `git clone` on any host without its own key. (fixed) |
| Secrets table: Tom's qBittorrent paragraph | misformatted | A prose paragraph sat **inside** the table, breaking it. Moved below the table. Tom has no qbit binary/unit (`command -v qbittorrent-nox` empty) — that part is true. |
| Non-goals: DHT / Secure Boot / AMT | match | DHT publishes true readings; Secure Boot off; AMT unimplemented, as documented. |

## Gaps that actually block a from-scratch rebuild

1. **No disk/boot procedure.** Partitioning, LUKS2, the five btrfs subvolumes,
   systemd-boot and the TPM enrolment exist only inside
   `scripts/ralph-arch-install.sh` / `scripts/ralph-finish.sh`, which RUNBOOK
   never references. Anyone reading only RUNBOOK cannot start.
2. **The repo cannot reproduce Ralph's nginx.** `docs/ralph/nginx-ralph.conf`
   lacks the `/bt/` block (no qBittorrent UI after a rebuild), `docs/ralph/petcam.conf`
   does not exist, and the `00-upgrade-map.conf` split is described nowhere.
   Copying the repo file *and* a petcam.conf would also duplicate the petcam
   server block.
3. **VPN bring-up is not reproducible.** `proton-guard.sh` install step was
   missing (fixed); `proton-guard.service` / `proton-guard.timer` are on the box
   only; and the documented mechanism (`wg-quick@proton0` at boot) demonstrably
   never runs, so the guard is the only thing that brings the tunnel up — 2 min
   after boot, while `qbittorrent-nox@qbittorrent` starts waiting immediately.
4. **Ralph's network layer is undocumented.** iwd + systemd-networkd on wifi,
   no ethernet available, `/etc/iwd/main.conf` `EnableNetworkConfiguration=false`.
   Not a word in RUNBOOK.
5. **Tom has no runnable build story.** No Go toolchain step (Go 1.22.5 is at
   `/usr/local/go`, not in `PATH`), no cron install (capture supervisor +
   detector corrections every 2 min, `@reboot` lines, `tom-health` sampling,
   `wifi-guard`), no `kernel.panic_on_rcu_stall=1` (that is what produces the
   crash dump), and no note that petcam must not start before `tailscale0`.
6. **Key material distribution** — fixed in the secrets row, but a rebuild still
   needs a GitHub key minted per host and the Jellyfin/qBit passwords typed in by
   hand.

## What could not be verified without doing it for real

- Any cold rebuild of Ralph (it wipes `/dev/nvme0n1`) — the install scripts are
  read, not executed.
- Unattended LUKS/TPM boot after a firmware or bootloader change (PCR 7).
- Cloudflare side: whether the tunnel credentials/`cert.pem` still let a fresh
  `cloudflared tunnel run` authenticate, and the Access policy on
  `petcam.andrewahale.com`.
- The `/etc/nginx/htpasswd` password (`andy`/`pancake`): only the username is
  readable (`root:http`, 0640).
- Jellyfin's first-run outcome — BaseUrl and library paths were read from the
  live config, not re-derived from a wizard.
- Tailscale admin-console items (key expiry, ACL `ssh: accept`) — the node keys
  still expire, so they are almost certainly unapplied.
- Tom's full-day reset rate (5 boots so far today).

## Fixed in RUNBOOK.md (outside the petcam and website sections)

TPM2 line, `pacman` package list, nginx "everything through :80" claim, Jellyfin
library paths + mount drop-in, qBittorrent interface binding, `proton-guard.sh`
install step, GitHub-key secrets row, and the paragraph that had been left
inside the secrets table. Left for other agents: the Tom/petcam section (stale
"petcam only" and laptop claim) and everything in the website flow.
