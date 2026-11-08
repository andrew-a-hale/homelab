## SSH access to Tom

Jason's SSH client must use `IPQoS none` for `tom` (see `~/.ssh/config`):
default IPQoS marks packets that Jason's UFW/conntrack drops, which made direct
SSH to Tom time out. Do not reintroduce the old `ProxyCommand` bash `/dev/tcp`
wrapper.

Names (2026-10-31): `tom` / `tom.tailad1015.ts.net` (Tailscale MagicDNS,
100.77.132.110) is the primary name everywhere — scripts, docs, ssh — because it
is uplink-agnostic. `tom.local` is a LAN-only convenience pinned in `/etc/hosts`
to **both** LAN addresses: `192.168.1.24` (Wi-Fi, the permanent uplink) and
`192.168.1.23` (the temporary wired cable), so it resolves whichever is present.
`ssh tom-wired` reaches `.23` directly. Do not hard-code a LAN address in a
script or doc: both LAN addresses are only valid while their interface carries
the uplink, which is exactly why the tailnet name is the default.

# Server Migration

// NOTE: I've bought a Dell Optiplex and a 4TB HDD to attach to the Dell. We will install ubuntu on it.

> **Superseded 2026-11-07.** The OptiPlex is `ralph`, it runs **Arch + Guix**
> (not Ubuntu), and it is now the always-on server and public gateway. Jellyfin,
> the media library (58G, on the 4TB USB drive), the website and the Cloudflare
> tunnel all live there. See [`../ralph/`](../ralph/).
>
> **Tom's job now:** petcam only — camera, `petcam.sh`, `petcam-detect.py`, its
> YOLO model, and the second instance of the Go web app that serves
> `petcam.andrewahale.com`. Jellyfin was disabled on Tom 2026-11-07 and `/jf/`
> removed from its nginx. qBittorrent (`/bt/`, LAN only) now lives on Ralph;
> Tom's copy is gone (no binary, no unit).
>
> Tom's DHT sensor reads ~3°C off versus Ralph's in the same room; Ralph's is
> the one now published. The `static/dht.json` committed in the website repo is
> stale by design — the live file is `/srv/dht/dht.json` on Ralph.
>
> The analysis below is kept as the reasoning that led to buying the OptiPlex.

## Current state (2026-10-21)

- Desktop `jason` (Ryzen 5 7600X, 30GB, gaming rig, /mnt/games): runs Jellyfin +
  qBittorrent. Always on, locks often. 60–80W idle ≈ **$190–250/yr** electricity
  at $0.30/kWh.
- Pi `tom` (Pi 5, 8GB, **128-day uptime, load 0.03**): runs website, VPN gateway,
  ad-block DNS, dnsmasq (docker/ollama/NFS removed 2026-10-21 as dead weight).
  ~7W ≈ **$20/yr**. Storage: 29GB SD,
  73% full — its only weakness.

## Decision: Option A — Pi 5 + SSD (recommended)

The Pi 5 **is** the server; buy it the storage it lacks.

- **Buy: 2TB USB3 SSD** (~$180–200 AU, e.g. Samsung T7 class). Media serving is
  sequential IO over LAN — USB3 (~400 MB/s) is 50× more than 4K remux needs.
  Skip NVMe HATs/base: they add cost and set-up for zero benefit at this
  workload.
- Total spend: ~$180 (plus ~$99 Chromecast for the TV item — see docs/media).
- Power: retires the desktop from 24/7 duty → **~$170–230/yr saved**, the SSD
  pays for itself in a year.

Ceilings (known, accepted):
- **Transcode is weak** (4× A76). Fine while clients direct-play — the
  Chromecast direct-plays H.264/HEVC, which covers ~everything. If 4K remux
  transcodes actually appear: only then consider Option B.
- SD card stays small: Jellyfin cache/config goes on the SSD via symlink.

### Option B (rejected for now): N100 mini PC (~$300 AU) + SSD

x86, VA-API transcode, runs everything incl. website/VPN/DNS (retiring the Pi).
Only worth it if transcoding or x86 needs become real. Revisit on the first
real "this Pi can't do it" day.

### Option C (rejected): desktop stays the server

User decision — it's a gaming rig. Also the most expensive option per year.

## Migration plan (started 2026-10-21 on the Elements drive)

1. ~~SSD → ext4, systemd mount~~ **done differently**: the Elements 1TB (NTFS)
   was fstab-mounted at `/mnt/storage` (PARTUUID) — same path as the desktop, so
   the copied Jellyfin config needed zero edits. **The drive died 2026-10-22**
   ("Unit Not Ready", contents abandoned); `/mnt/storage` is now an NFSv4 mount
   of jason's internal disk (see docs/media/README.md). The 2TB SSD mounts at
   the same path when it arrives — one fstab line swap, zero config edits.
2. ~~rsync library + jellyfin config → Pi, install jellyfin~~ **done**:
   3GB library + config (user, libraries, DLNA plugin) live on the Pi,
   `http://tom/jf` (BaseUrl `/jf`), unit `jellyfin` enabled at boot.
3. ~~qBittorrent-nox on the Pi bound to protonvpn~~ **done, then superseded
   2026-11-08**: qBittorrent and its VPN moved to Ralph (`http://ralph/bt/`);
   Tom has no qBittorrent binary or unit left. Was: unit `qbittorrent-nox@tom`,
   WebUI 127.0.0.1:8081 loopback-only, external address = Proton exit. The
   `grab` scripts now target Ralph's loopback (they are not committed here).
4. (subsumed by 3) WebUI stays loopback + ssh-wrapped calls.
5. ~~Desktop: stop/disable jellyfin + qbittorrent~~ **done** 2026-10-21.
   Desktop's 2TB stays as backup/overflow (docs/backups unchanged).
6. ~~Update AGENTS.md / docs~~ **done** (docs/media, AGENTS.md pointer).
7. Photos/Andrew personal data stays on desktop + weekly Proton sync
   (docs/backups) — not the media SSD's problem.
8. Pet cam (live-only, no retention): `rpicam-vid` (`~/projects/homelab/scripts/petcam.sh` on the Pi,
   capture 720p, stream knobs at the top of that script) → one ffmpeg forks:
   480p/10fps HLS segments in `/dev/shm/petcam` + 1fps stills at
   `/dev/shm/petcam/frames/latest.jpg` → served by the Go web app at
   `petcam.andrewahale.com` (snapshots gallery at `/`, stream at `/live`;
   see docs/website/README.md). Module 3, indoor pets; NoIR stays spare
   for outdoor/night.
   Detection: `~/projects/homelab/scripts/petcam-detect.py` (YOLOv8n ONNX via OpenCV DNN, model in
   `~/petcam/model/`) watches the stills and writes cat snapshots to
   `~/petcam/shots/` — timestamped filename is the gallery contract. Orange
   vs gray label via fur-hue histogram, drawn on the snapshot. Every
   detection updates the latest shot per cat (`KEEP_PER_CAT=1` keeps storage
   to one file per cat; no throttle). Knobs: `MIN_CONF`, hue thresholds.
   ~~Jellyfin "Live TV" M3U channel~~ — dropped 2026-10-21 in favour of the
   Go website (one codebase, one page).
9. ~~Remote access: add `jellyfin.andrewahale.com` to the existing Cloudflare
   tunnel~~ **done** 2026-10-21: hostname in `~/.cloudflared/config.yaml` on
   the Pi (origin `localhost:8096`), CNAME via `cloudflared tunnel route dns`.
   Phone Jellyfin app uses it from anywhere: pet cam + whole library. No
   recording, nothing on the SSD.
   **Security = Jellyfin's own login, no Cloudflare Access** (decided
   2026-10-21): single account with a strong password, tunnel-only exposure.
   Access's email-OTP challenge doesn't work with the Jellyfin mobile/TV apps
   anyway (they can't complete it). Optionally enable Jellyfin admin →
   "Require login on connect from external networks" so LAN clients skip the
   login prompt.

Remaining: steps 8–9, plus the 2TB SSD swap when it arrives (reformat ext4,
move `/mnt/storage` data, update fstab PARTUUID).

## TV client (the other item) — decision

**Google TV Streamer (~$219 AU)** — the Chromecast with Google TV's
successor: same Google TV platform (official Jellyfin app in the Play Store,
direct-plays H.264/HEVC), plus Ethernet (nice on a WiFi-heavy LAN) and more
power. Chosen over the Chromecast (~$99) for the Ethernet port and longevity;
Fire TV Stick 4K (~$70) rejected — sideloaded APK friction.

Setup when it arrives: HDMI + power → sign in Wi-Fi/Google → install Jellyfin
from Play Store → point at the server → sign in → direct play. (Sourcing note:
Jellyfin Android TV app handles the weak-Pi-transcode ceiling by direct
playing ~everything H.264/HEVC.)

## Known stability issue: random Tom reboots

There are **three distinct reboot causes** in Tom's history; only the third is
still live, so check the journal before assuming which one fired:

1. **Camera (imx708) I2C/CSI stall** — `rpicam-vid` timing out on the CSI/I2C
   bus while the 24/7 petcam pipeline runs, starving RCU until the hardware
   watchdog resets the Pi. Diagnosis:
   `docs/petcam/complete/camera-i2c-rcu-stall-reboot-2026-10-25.md`. The sharp
   signal is `ERROR: *** no cameras available ***` repeating with the supervisor
   restarting every ~65 s — that means the sensor fell off the CSI bus, so
   reseat the ribbon. **Reseated 2026-10-27, clean since** (one clean start per
   boot, no `no cameras available`); watch `~/petcam/logs/rpicam.log` for a flap
   returning before blaming anything else.
2. **Wifi scan engine wedge (brcmfmac)** — 6 reboots on 2026-10-27, more on
   2026-10-28 (every 1–1.5 h). Firmware never completed a scan (`Scanning
   suppressed: status (4)`); NetworkManager/wpa_supplicant's roaming `bgscan`
   fired the trigger ~5 min after every connect, then a stuck SDIO command hung
   a CPU (`rcu_preempt stalls`, `brcmf_proto_bcdc_msg failed w/status -110`).
   **This one is fixed and closed.** Tom's Wi-Fi runs on the iwd backend
   (wpa_supplicant masked) and `SCAN-FAILED` has been **0 on every boot since**
   the 2026-10-29 migration — 64,918 of those lines exist, all dated 10-26..28.
   `scripts/wifi-guard.sh` stays installed but is **inert** (its trigger no
   longer exists) and has not fired since 2026-10-28 18:18. Details + the failed
   first attempt (why `[device]` not `[main]`, why iwd needs a native network
   file): `docs/server/complete/iwd-wifi-backend-migration-2026-10-29.md`,
   `docs/server/complete/iwd-outage-and-wired-ethernet-2026-10-29.md`; closure
   evidence: `docs/server/complete/wifi-scan-wedge-2026-10-31.md`.
3. **RP1 I2C / imx708 camera-path hard hang — identified 2026-11-08, still live.**
   Fixing the scan wedge did **not** stop the restarts; they got more frequent
   (19 boots on 2026-10-31 alone, gaps of 77 s to 2.5 h; **87 boots in 7 days** on
   2026-11-08, ~12/day). The first captured crash dump identifies the trigger:
   the imx708 stops answering I2C writes on its RP1 bus
   (`i2c_designware 1f00088000.i2c: controller timed out`, `Failed to write reg
   0x0342. error = -5`) and **CPU 3 hard-locks** — it never answers the NMI
   backtrace, `SMP: failed to stop secondary CPUs 3`. About a third of boots show
   the stall; the rest die silently, hard-reset by the 1 min hardware watchdog
   with no shutdown message. Power, thermal, SD and EXT4 logs are clean. Since
   2026-10-31 `panic_on_rcu_stall=1` panics and dumps instead of waiting for the
   1 min hardware watchdog.
   SD card, PSU and wifi are **not implicated by that dump** (not proven
   innocent — they are not in it). Fix order: **reseat the CSI ribbon, replace
   the ribbon, replace the camera module**, then fall back to a **USB UVC
   webcam** (removes RP1 I2C from the petcam path). Keep `panic_on_rcu_stall=1`
   armed — it is what produces the dump. The same reboot took the bootloader from
   2025-05-08 to 2026-09-25 (and moved the RP1 firmware with it). Runbook,
   revert path, and the answer to "how connected is Tom?":
   `docs/server/complete/crash-capture-and-bootloader-2026-10-31.md`. Open work:
   `docs/server/todo/tom-reboots-hang-2026-10-31.md`.

Tell them apart fast: `journalctl -b -1 -o cat | grep -c SCAN-FAILED` (wifi —
expect **0** now; a non-zero count means the wedge is back) vs
`journalctl -b -1 -o cat | grep -c 'failed to set mode'` (camera) vs
`journalctl -b -1 -o cat | grep -c 'rcu_preempt detected stalls'` (the live
hang), plus `journalctl -t wifi-guard` and `journalctl -t tom-health` for
power/thermal. Grepping the camera with `imx708|unicam|csi` is misleading: the
~22 `imx708` lines per boot are benign probe messages, and `rp1-cfe` alone
contributes 351k lines of noise to the journal.

Wi-Fi (`wlan0`, `192.168.1.24`) is the intended uplink. The Ethernet cable
plugged in on 2026-10-31 is **temporary** — a recovery path while the Wi-Fi
fault was chased — and `192.168.1.23` disappears with it. Both addresses are in
jason's NFS export and ufw rule so either works.

`scripts/wifi-guard.sh` (installed at `/usr/local/bin/wifi-guard.sh`, cron every
2 minutes) was rewritten on 2026-10-31 for the iwd backend and **no longer looks
at `SCAN-FAILED` at all** — that string only ever came from wpa_supplicant, which
is masked, so the old trigger could not fire whatever the firmware did. It now
declares wifi dead if `wlan0` has no IPv4, or if it holds an address but reaches
**neither** the gateway **nor** an off-LAN literal over `wlan0` (`-I wlan0`, so
neither probe can follow eth0) on two consecutive runs. Both-fail is the only
combination that acts; gateway-up-but-off-LAN-down is treated as an upstream
fault and only logged, and a blocked off-LAN target therefore degrades to
log-only rather than causing churn. Recovery is a `nmcli` profile restart, then a
brcmfmac reload, then a deferred reboot that fires only if wifi is still dead
**and** no other interface has a default route. The reload is skipped entirely
while another uplink is carrying traffic, because stopping NetworkManager would
drop that too.

## Package updates — decision (2026-10-31)

**Security-only unattended upgrades. Nothing else lands on its own.**

`unattended-upgrades` is installed and restricted to the Debian
`trixie-security` pocket, with `Unattended-Upgrade::Automatic-Reboot "false"` so
a kernel update can never reboot Tom by itself. The old hourly
`apt update -y && apt upgrade -y` root cron is gone; `apt-daily.timer`
(`APT::Periodic::Update-Package-Lists "1"`) now refreshes lists instead.

Why: an hourly blanket `apt upgrade` was a supply-chain and debugging liability
on a box whose stability was being measured. Worse, the shipped
`50unattended-upgrades` default includes
`origin=Debian,codename=${distro_codename},label=Debian`, which matches the whole
main suite — the "security only" intent needs that pattern commented out.

**The caveat:** `archive.raspberrypi.com` has no security pocket (single
`trixie` suite, `Origin: Raspberry Pi Foundation`), so there is no way to
express "rpt security only". Consequence: **kernel, `firmware-brcm80211` and
`rpi-eeprom` are no longer upgraded automatically — apply them by hand.** Same
for Docker, Jellyfin, Tailscale, nodesource, GitHub CLI and ProtonVPN.

Deliberately apply the rpt stack when you want it, and remember it costs the
clean-stretch clock. Background, the origin/label analysis and the revert path:
`docs/server/complete/crash-capture-and-bootloader-2026-10-31.md`.

## Monitoring — decision (2026-11-08)

**One script, one log line per run: `scripts/homelab-health.sh`.** Checks Tom,
Ralph and the public ingress from outside, appends a summary to
`~/homelab-health.log` (the uptime history), exits non-zero on any FAIL.
`skills/homelab-health/SKILL.md` says when to run it and what a failure means;
`docs/server/complete/health-check-2026-11-08.md` has the decision.

Not on a timer yet — it runs when a human or an agent runs it. It must run from a
machine that can `ssh` both hosts (`ssh ralph` from Ralph fails host-key
verification), so the timer belongs on the desktop, not the always-on box.
