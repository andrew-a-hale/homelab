# Tom: crash capture turned on, bootloader flashed (2026-10-31)

**Date:** 2026-10-31 ~19:30 AEST (single deliberate reboot)
**Status:** done, verified.
**Ticket:** [`../todo/tom-reboots-hang-2026-10-31.md`](../todo/tom-reboots-hang-2026-10-31.md)

Owner authorised one deliberate reboot to make the next hard hang diagnosable
instead of invisible, and to clear the bootloader item. This is the record of
what changed, how to read it, and how to undo it.

## Why this was needed

Tom freezes and is reset by the systemd hardware watchdog with no shutdown
message, so the journal always ends on whatever cron last wrote and says nothing
about the cause. `/sys/fs/pstore` was empty and could never fill: the kernel has
`CONFIG_PSTORE=y`/`CONFIG_PSTORE_RAM=y`, but the device tree reserved no ramoops
region, so ramoops never probed. There was no capture path at all.

## What changed

1. **ramoops / pstore** — `dtoverlay=ramoops-pi5` added under `[all]` in
   `/boot/firmware/config.txt`. This is the Raspberry Pi-shipped overlay, used
   with its default region (no size overrides) to keep the risk down:
   64 KiB at `0xb000000`, 16 KiB records. Boot confirms it:

   ```
   OF: reserved mem: 0x000000000b000000..0x000000000b00ffff (64 KiB) map non-reusable ramoops@b000000
   pstore: Registered ramoops as persistent store backend
   ramoops: using 0x10000@0xb000000, ecc: 0
   ```

   If 16 KiB records turn out to truncate a stall dump, override the sizes:
   `dtoverlay=ramoops-pi5,total-size=0x100000,record-size=0x40000`.

2. **`panic=15`** in `/boot/firmware/cmdline.txt`.

   **Read this before touching it.** `CONFIG_PANIC_TIMEOUT=0` in this kernel
   means a panic *hangs forever* — no dump, no reboot, and the box just sits
   there until the 1-minute systemd watchdog resets it, losing the panic text.
   `panic=15` is what turns a panic into "write the dump, wait 15 s, reboot".
   It is a behaviour change: a panicking Tom now reboots itself within seconds
   instead of hanging. That is deliberate — it is the whole point of the
   capture.

3. **`kernel.panic_on_rcu_stall = 1`** via
   `/etc/sysctl.d/99-tom-panic.conf`, applied live (no reboot needed).

   **Intentional deviation from the original authorisation, approved after the
   fact by the owner on 2026-10-31.** It was applied during the change rather
   than asked about first because without it the capture cannot fire on the
   failure we actually have.
   The RCU-stall boots are *stalls*, not panics: they freeze, the watchdog
   resets the board, and ramoops never gets a chance to write. With this set,
   a detected stall panics → ramoops records it → `panic=15` reboots. It only
   affects boots that were going to freeze anyway, and it makes them recover
   faster (panic at ~21 s of stall instead of waiting out the watchdog).
   As a side benefit it shortens recovery: a stalled core is declared stuck at
   ~21 s, so the board panics and comes back at roughly 36 s, instead of sitting
   frozen until the 1-minute systemd watchdog fires. Roughly a 21 s
   self-recovery rather than a ~60 s hang-plus-reset.
   Revert with `sudo rm /etc/sysctl.d/99-tom-panic.conf && sudo sysctl -p`.
   It does nothing for the ~8/14 boots that die with no stall message — those
   still need the sampler below.

4. **`scripts/tom-trace.sh`** — a pre-crash activity sampler, `@reboot` in
   root's crontab, writing one line every 15 s to `/var/log/tom-trace.log` and
   self-trimming to ~2000 lines (15 s samples, so ~8 h of history trimmed
   back to ~4 h). It records uptime, load, SD-card
   cumulative read/write counters and I/O ticks, `wlan0` rx/tx bytes, and PSI
   I/O pressure. The last line before a gap is the only look we get at the
   moments before a silent freeze, and it lets us test the two live hypotheses
   (SD-card I/O vs wifi) instead of arguing about them.

   15 s is coarse, and it is not where a freeze leaves its traces. That is what the
   kernel tee below is for.

5. **`scripts/tom-kmsg.sh`** — continuous kernel-log tee, `@reboot` in root's
   crontab, appending `dmesg --time-format iso -w` to `/var/log/tom-kmsg.log`
   with its own microsecond timestamp, capped at ~8 MB with one `.1` rotation.

   Added because the sampler alone cannot answer "what were the kernel's last
   words". The journal is not sufficient either: it flushes only every
   `SyncIntervalSec` (5 s on Tom) and it is the same sink as everything else, so
   on a hard freeze the final seconds are simply absent — and if journald is
   among the stalled things, all of it is. This reads `/dev/kmsg` directly and
   writes to a separate file, so it survives both.

   Rotation is **copytruncate**, deliberately: the file is opened `O_APPEND`, so
   writes resume at the new EOF after truncation. Renaming the inode would leave
   `dmesg` writing to an unlinked file and silently lose the capture.

   The file **appends across boots** (`/var/log` is on the ext4 root, not
   tmpfs), and each start writes a `===== boot <timestamp> =====` header, so
   several boots are retained — 8 MB is ~130 boots at ~60 KB each. Two caveats:
   a header marks a *capture* start, so restarting the capture mid-boot adds a
   second header inside one boot; and `dmesg -w` re-dumps the whole ring buffer
   on start, so a mid-boot restart duplicates what it already wrote (harmless,
   and it does not happen on a normal boot).

   The same header records the reset reason, since nothing else persists it —

   ```
   ===== boot 2026-10-31T20:55:00+10:00 =====
   rsts_dt=00000020 rsts_vc=20 wdt_bootstatus=0
   throttled=throttled=0x0 temp=temp=56.0'C bootloader=2026/09/25 15:59:09
   ```

#### Is the tee actually healthy?

A future reader should not have to rediscover this. Two failure modes have
already happened once each: a dead supervisor leaving `dmesg` orphaned (still
writing, but with no rotation and no restart-on-exit), and — the cause of it —
`pkill -f "tom-kmsg.sh"` while ssh'd in, which matches the ssh command line and
kills your own session mid-restart.

Check by **process tree, never by pattern-matching a kill**:

```bash copy Copy tee health check
ps -eo pid,ppid,args | grep -E "tom-kmsg|dmesg --time-format" | grep -v grep
sudo grep -ac "===== boot" /var/log/tom-kmsg.log      # header present, or it has no reset payload
```

Do **not** judge liveness by the tail advancing. The kernel log here is ~1 line
per 10 minutes, so a healthy tee routinely sits on the same last line for a long
time; the timestamps only move when the kernel actually says something. Judge by
the process tree above, and by the header count.

Healthy looks like exactly three lines: `sudo → bash tom-kmsg.sh → dmesg -w`,
plus one rotator subshell. One `dmesg` only.

**To restart it, kill by PID — and this instruction lives here, in the step that
does the killing, on purpose.** `pkill -f tom-kmsg.sh` (or any pattern naming the
script) also matches the ssh command line you are typing it in, and will kill your
own session mid-restart. That happened **twice** in one night, both times to
someone who had already written the warning down — which is why the rule is now
in the procedure rather than in a caution above it. Read the PID off the process
tree you just printed, and kill that:

```bash copy Copy restart the tee safely
# 1. read the tree, take the PID of the script itself (not dmesg, not your shell)
ps -eo pid,ppid,args | grep -E "tom-kmsg|dmesg --time-format" | grep -v grep
# 2. kill that exact PID
sudo kill <PID_from_above>
# 3. start it again, then re-run the health check and confirm one dmesg
sudo nohup /home/tom/projects/homelab/scripts/tom-kmsg.sh >/dev/null 2>&1 &
```

If the supervisor is already gone, the orphaned `dmesg --time-format iso -w` is
what you are looking for — it keeps writing with no rotation and no restart.

### On the reset reason: it does not answer the question it looks like it answers

`/proc/device-tree/chosen/bootloader/rsts` is the documented firmware view of
`PM_RSTS` (big-endian binary; Raspberry Pi's own `config.txt` docs describe it),
and `vcgencmd get_rsts` reads the same register. Both are **read-only and safe to
poll**. But do not expect them to separate a watchdog reset from a software
reboot:

- Upstream issue `raspberrypi/linux#1586` is titled *"get_rsts=20 regardless of
  reset reason"* — watchdog, `reboot`, kernel panic and pulling the power all
  returned `20`.
- `sudo reboot` resets the SoC **through the watchdog** on Raspberry Pi, so the
  two are the same event at this level by construction.
- The firmware clears and rewrites the register, so it accumulates rather than
  recording cleanly.

What it *can* do: a cold power-on shows `0x1000` (`get_rsts=1000`), so a value of
`0x20`/`0x1020` at least means "reset, not power-on" — which speaks, coarsely, to
the "board power" candidate. Tom currently reads `rsts=0x00000020` and
`bootstatus=0`; the watchdog driver reports `0` either way, matching the upstream
report. So this is captured per boot for cross-boot comparison, **not** treated
as the discriminator. The kernel tee's timestamps remain the primary evidence.

There is **no bootloader log file** that survives a reboot — the firmware log
goes to UART/HDMI and `chosen/log` is empty on this board. The DT node above is
the only machine-readable reset state, and it survives only as long as the boot,
which is why it is copied into the log header.

6. **Bootloader** — `sudo rpi-eeprom-update -a` flashed the SPI EEPROM in place
   (`flashrom … VERIFY: SUCCESS`), activated by the same reboot.
   2025-05-08 → **2026-09-25**. `rpi-eeprom-update` now reports `up to date`.

   **The bootloader carries the RP1 firmware, and it changed:**
   `eb39cfd516f8c90…` → `a2e0ebda04df1820f792a7acd4479f6f5a2130d4`. That was not
   listed as a reason to do this — the Pi 5 southbridge reports show the same
   failures across RP1 firmware versions, so treat it as collateral, not a fix.
   It does, however, mean the RP1 firmware is no longer a variable worth
   suspecting separately: it is now current.

## Verified after the reboot

- Bootloader 2026-09-25, `rpi-eeprom-update`: up to date. New RP1 firmware
  loaded. `panic=15` present in `/proc/cmdline`. ramoops registered.
- `panic_on_rcu_stall` reads 1 after reboot, so the sysctl drop-in is wired.
- Sampler auto-started from `@reboot` and is appending to `/var/log/tom-trace.log`.
- Services: nginx, jellyfin, tailscaled, NetworkManager, iwd all active;
  wlan0 on 192.168.1.24; nginx 200, jellyfin 302 (login redirect, expected).
- Cloudflare tunnel re-registered 4 edge connections; from jason
  `andrewahale.com`, `/blog` and `/static/dht.json` all return 200.
- `/sys/fs/pstore` is empty — no crash has happened yet, as expected.

**Not yet verified:** that a real panic actually writes a dump and reboots on
this board. That needs the next hang to happen; forcing it would have meant a
second deliberate reboot and restarting the clean-stretch clock. ramoops
registering as the persistent backend is the strong signal that it will.

## Runbook: when pstore has something

**Archiving is already automatic — no polling needed.** `systemd-pstore.service`
is enabled and its `Storage=` is at the default (processing on, i.e. *not*
`none`), so on the boot after a panic it copies `/sys/fs/pstore` to
`/var/lib/systemd/pstore/<boot-id>/` and then clears pstore. That happens before
the next panic can overwrite it. Check there first:

```bash copy Copy where the dump lands
sudo ls -laR /var/lib/systemd/pstore/
sudo ls -la /sys/fs/pstore/          # empty unless systemd-pstore has not run yet
sudo cat /var/lib/systemd/pstore/*/dmesg-ramoops-0
```

`crash_kexec_post_notifiers=N` and `always_kmsg_dump=N` are both at their
defaults, which is what we want: dumps are taken on panic/crash only, not on
every clean reboot.

If you want a copy to attach to the ticket:

```bash copy Copy archive the dump
sudo journalctl -k -b -1 > /home/tom/tom-crash-$(date +%F-%H%M)-journal.txt
sudo tar czf /home/tom/tom-crash-$(date +%F-%H%M).tgz /var/lib/systemd/pstore /var/log/tom-trace.log
```

Read it for: the panicking CPU/task (we expect **CPU 3**), whether
`panic_on_rcu_stall` fired or something else did, and the last driver frames —
`brcmf*d`, `mmc*`, `sdhci`, `rp1*` are the ones that matter. Compare the
timestamps against the last line of `/var/log/tom-trace.log`.

## Revert / recovery

- Files backed up before the change: `/boot/firmware/config.txt.bak.20261031`
  and `/boot/firmware/cmdline.txt.bak.20261031`. Copying them back and rebooting
  restores the previous boot behaviour (but not the old bootloader — that is a
  one-way flash unless you re-flash 2025-05-08 from the same package directory).
- If Tom does not come back after a future change of this kind: plug Ethernet
  and `ssh tom-wired` (192.168.1.23), or pull the SD card and edit
  `config.txt`/`cmdline.txt` from another machine. Worst case, Raspberry Pi
  Imager can write a bootloader rescue image.
- Sampler only: `sudo crontab -e` and drop the `tom-trace.sh` line; the running
  copy exits on its own if you kill it.

## Apt: security-only unattended upgrades replaced the hourly blanket cron

**Done 2026-10-31**, after the owner's supply-chain decision. This reverses the
earlier "leave it alone" call in the ticket.

Before: root's crontab ran `3 * * * * apt update -y && apt upgrade -y` — every
hour, every repo, every component, unattended.

After:

- `unattended-upgrades` 2.12 installed; `unattended-upgrades.service`,
  `apt-daily.timer` and `apt-daily-upgrade.timer` are enabled and active.
- `APT::Periodic::Update-Package-Lists "1"` — apt-daily still refreshes package
  lists, so it replaces the `apt update` half of the old cron.
- `APT::Periodic::Unattended-Upgrade "1"` in `/etc/apt/apt.conf.d/20auto-upgrades`.
- The hourly cron line is **removed** (backup: `/tmp/root-cron.pre-apt.bak`,
  which does not survive a reboot — the live crontab is the source of truth).

### The trap in the shipped default

`50unattended-upgrades` ships three active origin patterns, and the first one is
`origin=Debian,codename=${distro_codename},label=Debian` — that matches the
**whole trixie main suite**, i.e. exactly the "silently upgrade everything"
behaviour we were trying to get rid of. Both non-security patterns were
commented out, leaving one:

```
"origin=Debian,codename=${distro_codename}-security,label=Debian-Security"
```

`apt-config dump` confirms only that pattern is live, and the dry run reports
`Allowed origins are: origin=Debian,codename=trixie-security,label=Debian-Security`.
The tuple matches the real security suite exactly — its `InRelease` carries
`Origin: Debian`, `Label: Debian-Security`, `Codename: trixie-security`.

### rpt has no security pocket — this is the caveat that matters

`archive.raspberrypi.com` is a **single** suite: `Origin: Raspberry Pi
Foundation`, `Label: Raspberry Pi Foundation`, `Suite: stable`, `Codename:
trixie`, Components `main beta untested`. There is no `trixie-security` and no
security label, so there is no way to express "rpt security only". Consequence:

**Nothing from Raspberry Pi Foundation upgrades automatically any more** —
including `linux-image-*`, `firmware-brcm80211` and `rpi-eeprom`. That is
arguably right for a box under investigation (we want to control kernel and
firmware changes and know when they land), but it is a real behaviour change and
it means **rpt fixes must be applied by hand**. Same for every third-party repo
(Docker, Jellyfin, Tailscale, nodesource, GitHub CLI, ProtonVPN): excluded, no
longer auto-upgraded.

If rpt ever publishes a security pocket this needs revisiting — add its
origin/label here then.

### No automatic reboots

```
Unattended-Upgrade::Automatic-Reboot "false";
```

Deliberate: a security kernel landing must not reboot Tom on its own and
silently restart the clean-stretch clock. That reboot stays a human decision.

### Verified

- `unattended-upgrade --dry-run --debug` → allowed origin is the security pocket
  only, `No packages found that can be upgraded unattended`.
- The box was fully patched at the time (the old cron had just run), so there
  were **no pending non-security upgrades to demonstrate exclusion against**.
  The scoping is verified statically (origin tuple + the allowed-origins line),
  not yet by watching it skip a real non-security upgrade. The next time rpt or
  Docker publishes, confirm it appears in `apt list --upgradable` and is *not*
  taken.

### Revert

`sudo cp /etc/apt/apt.conf.d/50unattended-upgrades.bak.20261031
/etc/apt/apt.conf.d/50unattended-upgrades`, then re-add the cron line and
`apt-get remove --purge unattended-upgrades`.

## Related: how connected is Tom, in answer to the supply-chain question

> **Read this as the state before the change above.** It was measured on
> 2026-10-31 while auditing the then-current hourly `apt upgrade` cron, which the
> "Apt" section above has since removed and replaced with security-only
> unattended upgrades. In particular the "unattended-upgrades is not installed"
> bullet below is **no longer true**; it is kept because it explains the exposure
> the audit was about.

Not airgapped, and not close to it. Tom is a normally internet-connected host
behind the D-Link router's NAT (`192.168.1.0/24`, default via 192.168.1.1 on
wlan0, or via `proton0` when the ProtonVPN tunnel is up).

- **Inbound:** no port forwarding. Off-network access is Cloudflare Tunnel
  (`cloudflared` dials *out* to the edge — no inbound port is opened) and
  Tailscale (outbound NAT traversal). LAN-side listeners are nginx :80,
  jellyfin :8096, sshd :22, rpcbind :111, wayvnc :5900 and tailscaled; nftables
  carries only Tailscale's own chains and the input policy is `accept`, so
  nothing but the router protects those from the LAN.
- **Outbound:** unrestricted.
- **What the hourly `apt upgrade` actually pulls**, and over what:
  - `http://deb.debian.org/debian` and `…/debian-security` (trixie) — **plain
    HTTP**, integrity from the GPG-signed `InRelease`, verified against
    `Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp`.
  - `http://archive.raspberrypi.com/debian` — **plain HTTP**, `Signed-By:
    raspberrypi-archive-keyring.pgp`.
  - HTTPS, each with its own explicit keyring: nodesource (`node_22.x`),
    ProtonVPN, Jellyfin, Tailscale, GitHub CLI, Docker.
  So transport is TLS for third-party repos and cleartext for Debian/RPi, but
  **every source is GPG-verified per-repo**, so a network attacker cannot inject
  a package without a signing-key compromise; TLS only hides what is being
  fetched. The real exposure is the upstream trust itself, not the wire.
- **Pinning:** only `nodejs`/`nsolid` (origin pins, priority 600, from
  nodesource) in `/etc/apt/preferences.d/`. No `apt-mark hold` anywhere.
- **`unattended-upgrades` is not installed** (0 packages), so
  `apt-daily-upgrade.timer` runs `/usr/lib/apt/apt.systemd.daily install` as a
  practical no-op. Every upgrade that lands comes from root's hourly cron.

Options if that cadence is too much (none applied — owner's call):

1. Leave it (current state).
2. Drop to daily at a quiet hour — same trust model, far less churn, much easier
   to correlate a bad update with a new symptom.
3. Change the cron to `apt-get update` only, and apply upgrades deliberately
   after reading `apt list --upgradable`. Best for a box under investigation.
4. Install `unattended-upgrades` scoped to `trixie-security` only and delete the
   blanket cron — the standard Debian posture: security patches automatic,
   everything else deliberate.
5. Move the two cleartext repos to HTTPS (both support it) for confidentiality.
6. Run `apt-cacher-ng` on Jason and point Tom at it — one audit point, and you
   can freeze what is offered to Tom.

## If the SD card is the next test: what it needs physically

Only worth doing after reading `/var/log/tom-trace.log` across the next crash
gap — if `mmc_busy` was non-zero or `mmc_io_ms` was climbing right before the
freeze, I/O is implicated and this test is the right next move.

1. Power Tom down cleanly (`sudo shutdown -h now`), then **pull mains** — a Pi 5
   can stay partly powered over the USB-C supply otherwise.
2. Image a **known-good, branded** SD card (SanDisk/Samsung A1/A2, 32 GB+) with
   a fresh Raspberry Pi OS Lite 64-bit, rather than cloning the current card —
   cloning would copy any filesystem weirdness across.
3. Boot it, `ssh-copy-id` the same key, install the packages the services need,
   and start with the camera and petcam pipeline **off** so the only variable is
   storage. Leave it 24 h.
4. Then turn the petcam pipeline back on and leave it another 24 h.
5. Keep the current card untouched so it can go back in — it holds the only copy
   of the journal history and `~petcam` data.

What I cannot do from here: swap cards, check the PSU/cable, or verify the card's
physical labels. If restarts stop on the known-good card and resume on the old
one, that is the answer and the fix is simply a new card.
