# Tom: unexplained hard hangs / restarts (2026-10-31)

**Date opened:** 2026-10-31
**Status:** open — cause unidentified, ~1 restart/hour.
**Predecessors:** [`../complete/wifi-scan-wedge-2026-10-31.md`](../complete/wifi-scan-wedge-2026-10-31.md)
(the scan wedge, now fixed), [`../complete/wifi-scan-storm-watchdog-2026-10-27.md`](../complete/wifi-scan-storm-watchdog-2026-10-27.md),
and `../../petcam/complete/camera-i2c-rcu-stall-reboot-2026-10-25.md`.

## What is established

Tom restarts by hard reset, not by a reboot request. Every dead boot's journal
simply stops mid-cron-burst — no `reboot.target`, no `systemd-logind` reboot,
no shutdown messages — and the next boot starts 45–75 s later. systemd runs a
hardware watchdog (`RuntimeWatchdogUSec=1min`, `RebootWatchdogUSec=2min`), so a
frozen kernel gets reset about a minute later. That is the observed recovery
path, and it is why nothing is recorded about the cause.

Measured on 2026-10-31 (see the closure doc for the full table):

- 64 boots in the journal since 2026-10-26 21:25; **19 boots on 2026-10-31
  alone**, gaps from 77 s to ~2.5 h.
- **`SCAN-FAILED` = 0 on every boot from `-31` to `-0` except `-30`, which had 4**
  (all four dated before the migration settled; see the closure doc). `wifi-guard` has
  not fired since 2026-10-28 18:18. The scan storm is genuinely gone.
- **Restarts got more frequent anyway**, so the scan wedge is not the cause.
- **6 of the 14 boots** between 2026-10-31 12:28 and 18:17 show
  `rcu: INFO: rcu_preempt detected stalls`, and in **every one of them the
  stalled core is CPU 3** — never 0, 1 or 2. The stalled CPU never answers the
  NMI backtrace request (`Sending NMI from CPU 1 to CPUs 3:` and no backtrace
  follows). The other boots die with no kernel message at all, including the
  six most recent (`-6`..`-0`), which showed no stall.
- The 2026-10-27 13:42 restart that earlier notes called "unexplained" has the
  **same signature as today's silent resets** (boot `-58` ends 13:42:01 with no
  shutdown and no stall). It was never a one-off; it is this fault, and it
  predates the iwd migration.
- Clean on every channel we can currently measure: `throttled=0x0` on all 1957
  `tom-health` samples since 2026-10-29, `EXT5V` 5.042–5.203 V, peak
  60.9 °C; zero `mmc0`/`mmcblk0` errors and zero EXT4 errors in the whole
  journal; zero OOM kills.
- Camera is **not** in a failure loop right now (22 benign `imx708` probe lines
  per boot, 0–4 `failed to set mode`). The 175k-line
  `imx708_start_streaming failed to set common setting` storm is historical —
  all of it in boot `-63` on 2026-10-26.
- Capture was impossible until 2026-10-31: `/sys/fs/pstore` is empty, the device
  tree reserved no ramoops region, and `CONFIG_PANIC_TIMEOUT=0` meant a panic
  hung instead of rebooting. **Fixed on 2026-10-31** — see
  [`../complete/crash-capture-and-bootloader-2026-10-31.md`](../complete/crash-capture-and-bootloader-2026-10-31.md).
  The next hang should now leave a dump and/or a pre-crash trace; nothing has
  fired yet.

Working hypothesis, **not proven**: a bus-level hang (SDIO / RP1 / SD-card I/O)
wedges one CPU in a way that survives interrupts, RCU notices, the watchdog
resets the board, and the last seconds are lost because nothing is persisted
between the freeze and the reset. The strongest clue is that the wedged core is
**always CPU 3** — that is the same shape as the old SDIO theory, and a
consistent core suggests something pinned or repeatedly scheduled there (check
`/proc/interrupts` affinities and `taskset`/`irqbalance` state next). It is not
evidence of the *trigger*, which is what is missing.

## Open work

1. ~~Capture the next hang before theorising further.~~ **Done 2026-10-31** in
   one deliberate reboot — `dtoverlay=ramoops-pi5`, `panic=15`,
   `kernel.panic_on_rcu_stall=1`, `scripts/tom-trace.sh` sampling SD/wlan0
   counters every 15 s to `/var/log/tom-trace.log`, and `scripts/tom-kmsg.sh`
   teeing `dmesg -w` to `/var/log/tom-kmsg.log` so a silent death keeps the
   kernel's own last seconds (journald only flushes every 5 s). The log appends
   across boots and its per-boot header records `rsts`/`bootstatus`/`throttled`.

   [`../complete/crash-capture-and-bootloader-2026-10-31.md`](../complete/crash-capture-and-bootloader-2026-10-31.md)
   has the runbook (where pstore lands, the tee health check, the revert path).

   **Reset reason: answered, not solved — do not revisit.** `PM_RSTS` cannot
   separate a watchdog reset from a software reboot, because `reboot` resets the
   SoC *through* the watchdog (`raspberrypi/linux#1586` is titled "get_rsts=20
   regardless of reset reason"), and the firmware clears/rewrites the register.
   It distinguishes only cold power-on (`0x1000`) from a reset (`0x20`), so it
   speaks to the "board power" candidate coarsely at best — a PMIC brownout that
   still resets the SoC is indistinguishable from a watchdog reset. Tom reads
   `rsts=0x20`, `get_rsts=20`, `bootstatus=0`. It is captured per boot because
   that is free, **not** as a discriminator. Also closed: **no firmware reset
   reason survives a reboot** — the firmware log goes to UART/HDMI, `chosen/log`
   is empty on this board, and the DT node dies with the boot. The kmsg
   timestamps are the primary evidence for the three open candidates.

   **Next action is to wait for a hang and read the dump**, not to change
   anything. Still worth doing separately: `boot-reason-log.service` only
   logged 16 of 19 boots on 2026-10-31 (it runs `After=multi-user.target` and
   dies in the crash loop), so it under-reports the reboot count.
2. **PSU verification** (carried over). Official 5 V/5 A supply and no
   thin/cheap USB-C cable. `tom-health` shows `throttled=0x0` and `EXT5V`
   ≈ 5.04–5.20 V, but those flags clear on power cycle so they cannot prove the
   PSU. Still worth physically confirming the supply and cable.
3. ~~`sudo rpi-eeprom-update -a`~~ **Done 2026-10-31**: 2025-05-08 →
   2026-09-25, now `up to date`. It also moved the RP1 firmware
   (`eb39cfd5…` → `a2e0ebda…`), so RP1 firmware is no longer a separate
   variable to suspect. Hygiene, not a likely fix — the Pi 5 southbridge
   reports show the same failures across RP1 firmware versions.
4. ~~Unattended upgrades~~ **Changed 2026-10-31**: `unattended-upgrades` is
   installed and restricted to the Debian `trixie-security` pocket, with
   `Automatic-Reboot "false"`, and the hourly `apt update -y && apt upgrade -y`
   root cron line is gone. **Caveat that matters:** the rpt archive has no
   security pocket (`Origin: Raspberry Pi Foundation`, single `trixie` suite),
   so kernel, `firmware-brcm80211` and `rpi-eeprom` are **no longer upgraded
   automatically** and must be applied by hand — same for every third-party
   repo. See
   [`../complete/crash-capture-and-bootloader-2026-10-31.md`](../complete/crash-capture-and-bootloader-2026-10-31.md#apt-security-only-unattended-upgrades-replaced-the-hourly-blanket-cron).
5. **Track upstream.** Kernel `6.18.50+rpt-rpi-2712` is still the newest Pi 5
   image in the rpt archive, so there is nothing to upgrade to. The
   `firmware-brcm80211` blob for the 43455 has not changed since 2024. No
   brcmfmac scan/`-110` fix has landed. Re-check when a new rpt kernel appears.
6. **SD card is the cheapest hardware test.** Rootfs is `/dev/mmcblk0p2` on an
   unbranded 29.5 GiB SDR104 card (`manfid 0x0000ad`, OEM `0x4c53`, dated
   03/2025, `quirks 0x40000000`). It logs no errors, but a card that stalls
   without logging is a classic cause of exactly this freeze-then-watchdog
   signature. `/var/log/tom-trace.log` now records SD I/O counters every 15 s,
   so read the last line before the next crash gap first: if `mmc_busy` was
   non-zero or `mmc_io_ms` was climbing, I/O is implicated and swapping the card
   is the right next move. Physical steps (owner has to do these — card swap,
   PSU and cable cannot be done remotely):
   [`../complete/crash-capture-and-bootloader-2026-10-31.md`](../complete/crash-capture-and-bootloader-2026-10-31.md#if-the-sd-card-is-the-next-test-what-it-needs-physically).

## Capture integrity — which boots are clean evidence

A boot is only clean evidence if the tee ran untouched from boot to death. If the
tee was started or restarted mid-boot, that boot's kernel log starts late or has
a duplicated ring-buffer dump, and **must not be reasoned about as if it were
clean**. Record every such boot here.

| boot (start) | status | note |
| --- | --- | --- |
| 2026-10-31 19:30:54 | **partial — treat as weak** | Tee first started 20:51:41, then restarted 20:55:00 after a botched `pkill` (see runbook). Kernel log covers **20:51 onward only**; the first 80 minutes of this boot have no kmsg coverage. The 15 s trace sampler *does* cover the whole boot from 19:30, so it is the only continuous record for 19:30–20:51. Two headers in `/var/log/tom-kmsg.log` for one boot, and the ring-buffer dump is duplicated. |
| 2026-11-01 07:08:00 | **clean — verified** | First boot with the automatic tee. Header `===== boot 2026-11-01T07:08:02` against boot start `07:08:00`: **one header, +2 s**. `@reboot` works; this is trustworthy last-words evidence. |
| every later boot | clean (expected) | `@reboot` starts the tee at boot, so coverage begins with the boot. Verify with: one `===== boot` header per boot in `/var/log/tom-kmsg.log`. |

Rule of thumb: if the crash you are reading has more than one header for its
boot, its last-words evidence is weaker than it looks — prefer the trace log and
pstore for that one, and say so rather than presenting it as a clean capture.

### The next boot must be checked, not assumed

The `@reboot` line for the tee was added at 20:52 on 2026-10-31, **after** that
boot started, so it has never actually fired. Two headers in this boot came from
a manual restart, not from `@reboot`, so the automatic path is still unproven.

What has been proven without a reboot: the same script run in a stripped
cron-like environment (`env -i PATH=/usr/bin:/bin`) emits **exactly one**
`===== boot` header, every header field resolves (no `?` placeholders), and it
captured 645 lines. All binaries it calls (`dmesg`, `vcgencmd`, `xxd`, `flock`,
`stat`, `date`, …) live in `/usr/bin`, which cron's path includes. So the
mechanism is sound, but "sound by simulation" is not "observed".

**The write path itself is verified, separately from it starting.** At 21:49 the
log had not grown for 54 minutes, which is indistinguishable from a dead pipe, so
one marker was written to `/dev/kmsg`: the file went 1288 → 1289 lines and the
marker landed as `2026-10-31T21:49:53,352506+10:00 liveness-marker-2150`. So
`dmesg -w` → file delivery works, and the silence was the kernel genuinely
logging nothing (**~1 line per 10 min** on this host). Do not re-litigate
whether the tee records: it does. What remains unproven is only whether
`@reboot` starts it, which the header check above settles.

**Run this first at every scheduled check, before anything else.** It is stated
here because the recurring check prompt itself does not ask for it, so the
integrity step is the one that silently falls off — and a check that skips it
will report uptime and counts from a boot whose evidence it never verified.

At the first boot after 2026-10-31 20:58, check this **before trusting that
boot**:

```bash copy Copy verify one header per boot
sudo grep -an "===== boot" /var/log/tom-kmsg.log | tail -3
```

The newest header's timestamp must be within about a minute of that boot's start
(`journalctl --list-boots | tail -1`), and there must be exactly one header for
it. If the header is missing, the tee never started and that boot has **no**
kernel-log evidence; if there are two, something restarted it and it is weak
evidence. Either way, record it in the table above rather than reasoning about
it as clean.

## State change 2026-10-31 22:34: Ethernet plugged in

An Ethernet cable was connected to Tom at **22:34:05** (NetworkManager
`device (eth0): carrier: link connected`, `macb … Link is Up - 1Gbps/Full`,
DHCP lease 192.168.1.23). Tom is now **dual-homed**: `eth0 192.168.1.23/24`
default route metric 100, `wlan0 192.168.1.24/24` metric 600.

What this does and does not change:

- **The 22:15:40 threshold was passed on wifi alone.** Boot 19:30:54 → cable
  22:34:05 is **3 h 03 m 11 s of wifi-only uptime**, against a previous best of
  2 h 44 m 46 s. So beating the record is not explained by the cable.
- **Everything after 22:34 is dual-homed** and is therefore weaker evidence for
  a wifi-triggered fault: a hang that the wired path survives would still let the
  board serve traffic. Any future uptime claim must say which path was in use.
  Re-plugging the cable also gives us a control that did not exist before.
- The old "no ethernet, wifi is the only uplink" ceiling is **stale** — that
  assumption should not be carried into new analysis.
- Per `docs/server/README.md`, `.23` is already in jason's NFS export and the ufw
  rule, so the wired path is fully usable.

### How to read the uptime record

**Segments, because a reboot ends one.** Recorded rather than blurred:

| segment | from | to | duration |
| --- | --- | --- | --- |
| pre-cable baseline | boot 19:30:54 | cable in 22:34:05 | 3 h 03 m 11 s |
| **wifi-only, boot `c2fe5d10`** | cable out 01:13:08 | hard reset 07:07:42 | **5 h 54 m 34 s** |
| wifi-only, boot `b63e886a` | 07:08:00 | running | see latest check |

**The number that counts is 3 h 03 m 11 s, wifi-only** (boot 19:30:54 → cable
22:34:05). That is the figure to compare against the old best of 2 h 44 m 46 s,
and it is the only one that is evidence about a wifi-triggered fault.

**Everything after 22:34:05 must be labelled dual-homed.** A hang that the wired
path survives would still let the board serve traffic and would not show as a
crash the same way, so a dual-homed "record" is weaker evidence, not a better one.
Future uptime claims in this ticket should read like "X h wifi-only, then Y h
dual-homed", never a single blurred number. The wired window also gives us a
control we did not have before: same board, one path removed.

### The 94-second wlan0 drop is a separate event, not a stability regression

`wlan0` dropped at **22:48:17** (`state change: activated -> failed (reason
'supplicant-disconnect')`) and re-associated at 22:49:51 — **94 seconds**, while
the board stayed up and serving. No reboot, no RCU stall, no pstore record,
`SCAN-FAILED` still 0. Do **not** count it against the stability record or treat
it as the fault recurring; it is a link-level event. It is also why an `ssh` to
`.24` returned "no route to host" mid-check while `ping` and HTTPS kept working
(those took `.23`). Retrying rather than concluding "crash" is the correct
response to that symptom while Tom is dual-homed.

### Retiring wifi properly (owner's call — not done)

The README's earlier "wlan0 is down and `.24` is retired" wording was **not true**
of the live system and has since been corrected in the working tree to say Wi-Fi
is the intended uplink and the cable is temporary, which matches what was
measured. Verified against reality before accepting it: both `.23` and `.24` are
in jason's `/etc/exports` and its ufw `2049/tcp` rules, and `scripts/wifi-guard.sh`
on jason was byte-identical (md5 `4ffbc9ec…`, the *previous* version) to the
deployed `/usr/local/bin/wifi-guard.sh` on Tom, including its dead-wifi reconnect
path. That was before the iwd rewrite; the current pair is `fd7ff77d…` on both
sides (see the install section above). Do not compare against `4ffbc9ec` now.

#### Evidence: the probe really does test the wifi path

A review claimed `ping -I wlan0` binds only the *source address* and would follow
the default route, which would have meant the probe measured eth0 while the cable
was in — reopening the whole design. Measured on Tom instead of argued:
20 pings with `-I wlan0` moved **wlan0 `tx_packets` by exactly 20** while eth0
moved only by the ssh session's replies, and the ping header read
`from 192.168.1.24 wlan0`. Interface-name `-I` binds the device; the claim was
wrong. Recorded so it is not re-litigated from the diff.

### The three backups on Tom, and what each one is

These are the only record of what the guard looked like before the rewrite. To
roll back, copy one over the live path; nothing else is needed.

| backup on Tom | lines | md5 | what it is |
| --- | --- | --- | --- |
| `wifi-guard.sh.bak-20261031` | 82 | `4ffbc9ec…` | the pre-rewrite version, taken 2026-10-31 23:53. Has **both** the old `SCAN-FAILED` trigger and the added dead-wifi reconnect branch. This is the "their version" the rewrite was built on. |
| `wifi-guard.sh.bak-20261031-2251` | 55 | `ce35b9f5…` | the original wpa_supplicant-era guard from 2026-10-27 19:33 — `SCAN-FAILED` only, no dead-wifi branch. Identical to Tom's stale clone copy. |
| `wifi-guard.sh.bak-mine-20261101-0105` | 370 | `40bea585…` | **redundant, not a historical state** — byte-identical to the currently deployed file, a no-op backup taken at 01:05. Safe to delete whenever space is wanted; it restores nothing you do not already have. |

**There is no rollback path to a working guard.** The first two depend on
`SCAN-FAILED`, which only wpa_supplicant ever wrote; restoring either one gives a
guard that **cannot detect anything** on the current iwd stack and would sit
silent while wifi was dead. The third is the live file, so it restores nothing.

So recovery is **fix-forward**, and the premise is different from "keep a backup
in case": the current file plus the repo copy on `master` is the recovery path. If
the deployed guard is broken or missing, copy `scripts/wifi-guard.sh` from master
(`/home/andy/projects/tom` on jason) to `/usr/local/bin/` — do not reach for a
`bak-*`. The older copies are for understanding history only.

> **Historical note:** this text used to say "the repo copy on `tom-hang-capture`".
> That branch was deleted on 2026-11-01: it was an ancestor of `master` with zero
> unique commits and no remote counterpart, so the work had always been on
> `master`. Any older note referring to `tom-hang-capture` should be read as
> "`master`".

**Deployment is by copying files, and it lands in two places — not one.** Verified
against the crontabs rather than assumed:

| runs on Tom | path | started by |
| --- | --- | --- |
| `wifi-guard.sh` | `/usr/local/bin/wifi-guard.sh` | tom's cron, `*/2`, via sudo |
| `petcam.sh`, `petcam-detect.py` | `/home/tom/projects/tom/scripts/` | tom's cron, `*/2` and `@reboot` |
| `tom-trace.sh`, `tom-kmsg.sh` | `/home/tom/projects/tom/scripts/` | root's cron, `@reboot` |
| `train-model.sh`, `tom-watch-remote.sh` | **not Tom** — they run on jason | manual |

**The trap, stated correctly:** Tom's checkout at `/home/tom/projects/tom` is on
`master` at an old commit and is **git-stale**, but it is **the live deploy path
for four of the five scripts that run on Tom**. So "it is a stale clone, ignore
it" is exactly the wrong conclusion — overwriting or pruning that directory takes
out the petcam pipeline and both crash samplers. Its stale `wifi-guard.sh` (an old
55-line copy) is simply unused, because cron runs the `/usr/local/bin` one.

**Compare per file, never by git state:** `md5sum
/home/tom/projects/tom/scripts/<file>` against the repo. Git age on that clone
tells you nothing about what is running.

**They match by hand, not by deployment.** `scripts/wifi-guard.sh` in the repo and
`/usr/local/bin/wifi-guard.sh` on Tom are copied across manually — there is no
install step, symlink or packaging that keeps them in step. Byte-identical today
(md5 `fd7ff77d…`, see above) therefore guarantees nothing tomorrow: an edit to one side
silently diverges, and the deployed guard is what actually runs from cron every
2 minutes. Before trusting any behaviour described for the guard, **check both**
and compare `md5sum`; if they differ, the deployed copy is the truth.

If wifi is ever to be retired deliberately, `disconnect` is not enough:
the NetworkManager profile `Dlink-9C045E` has **`autoconnect: yes`** and the iwd
profile has `AutoConnect=true`, so it re-associates itself within ~90 s — which is
exactly what the 22:48 event looks like. It needs `nmcli connection modify
Dlink-9C045E connection.autoconnect no` **and** `AutoConnect=false` in
`/var/lib/iwd/Dlink-9C045E.psk`. No network config was changed: read-only check.

## wifi-guard rewritten for iwd (2026-10-31) — committed and installed

`scripts/wifi-guard.sh` is rewritten for the NetworkManager+iwd stack so the
Ethernet cable can come out and wifi can be the sole uplink again. It is on
`master` (never on a feature branch — see the note below) and **installed**:
`/usr/local/bin/wifi-guard.sh` and
`scripts/wifi-guard.sh` are both `fd7ff77d…`, tom's crontab still runs it every
2 minutes, and the previous copy is kept at
`/usr/local/bin/wifi-guard.sh.bak-20261031` for rollback.

### No review boundary: the guard went from working tree to Tom

Worth stating plainly rather than leaving implied. This work landed **directly on
`master`** — there was never a feature branch with the guard rewrite on it (the
`tom-hang-capture` branch was an ancestor of `master` with zero unique commits and
was deleted on 2026-11-01). Since the guard is **deployed by copying the working
tree** to `/usr/local/bin/wifi-guard.sh`, the sequence was:

```text
edit working tree → copy to /usr/local/bin → Tom now runs it → later, a commit
```

There was **no review, no test gate and no diff step between the rewrite and the
running copy** on the machine whose only recovery path it is. That is not something
to undo now — the guard is working and has recovered the box unattended three
times — but it is the reason "the deployed copy must match the repo" is a standing
check rather than an assumption, and the reason the `bak-*` inventory exists. If
this guard is ever rewritten again, the diff should be reviewed **before** the
copy, not after Tom is already depending on it.

### Tombstone: the SCAN-FAILED path is gone, do not resurrect it

The old trigger counted `SCAN-FAILED`, which is **wpa_supplicant's own log
string**. Tom moved to iwd on 2026-10-29 and wpa_supplicant was masked and
stopped, so nothing ever writes that string again: the branch became unreachable
by construction and could not fire whatever the firmware did. "0 SCAN-FAILED
since the migration" therefore never proved the wifi path was healthy — only that
the process which complains was not running. The tombstone is written into the
script header so the reasoning travels with the code.

Replaced by a probe that works under any supplicant: `ping -c 3 -W 2 -I wlan0
<gateway>`, bound to the interface so it tests the wifi path even when another
interface owns the default route. `-I wlan0` matters: without it the probe
follows the default route and would report eth0's health, not wifi's.

### What it does

- **Dead if** wlan0 has no IPv4, **or** it holds an address but reaches
  **neither** of two targets over wlan0 on **two consecutive runs**
  (`/run/wifi-guard.pingfail` holds the count; a success clears it). Two runs
  keeps a single flaky moment from acting: one `ping -I wlan0 192.168.1.1`
  returned 100% loss while the link was otherwise fine, although a 20-sample
  re-test gave 20/20.

### Failure taxonomy — which combination acts, and which only logs

Two targets: the gateway, and **1.1.1.1** as an off-LAN literal (anycast, so no
single host to depend on; answers ICMP; verified reachable over wlan0 from Tom
before hard-coding it). Never a DNS name, so a resolver failure cannot look like
a dead link. Both probes use `-I wlan0`, so neither can silently follow eth0.

| gateway over wlan0 | off-LAN over wlan0 | meaning | action |
| --- | --- | --- | --- |
| up | up | healthy | clear counters, exit |
| up | down | wifi is fine, the far side is not | **log only, never acts** |
| down | up | wifi demonstrably works, gateway just ignores us | **log only, never acts** |
| down | down | wifi or the whole path is dead | **acts**: recovery, then deferred reboot decision |

Only the last row can lead to a reboot. The useful property: a blocked,
decommissioned or unreachable off-LAN target degrades to *log only* — it can
never by itself cause recovery churn or a reboot. It fails safe.

**Watched but not solved — "possible probe blindness".** One configuration
inverts the guarantee: gateway blocking ICMP *and* the off-LAN target filtered
means a healthy link reads as dead, and the guard would act — a reboot every few
minutes. Provider-redundant probes are not worth building for that. Instead the
guard now announces it: if both targets fail while wlan0 still has **carrier up,
a live association, and advancing `rx_packets` since the last run**, it logs
`possible probe blindness: … the probes may be filtered rather than the link being
dead`. Verified both ways: rx advancing → the line appears; rx flat (the shape a
genuinely dead link has) → it does not. It still acts afterwards, deliberately —
the announcement exists so the loop is visible rather than looking like a fault.

That line lands in `journalctl -t wifi-guard`, and the pinned check already
reports **any** guard log line, so it surfaces in the hourly report rather than
sitting unread on Tom. Nothing further is needed to route it.

**What this does not fix:** a router or AP reboot takes out **both** targets at
once (and usually drops the association, so wlan0 has no IPv4), so it still
escalates and can still reboot Tom after ~200 s. The taxonomy removes the
"far side down but LAN healthy" false positive, not the "whole LAN is down" one.
That remains the known false-positive class and the reason to watch the first
wired-free night.
- **Recovery tier 1 — profile restart** via `nmcli connection down/up`. Chosen
  first because it is the mechanism actually observed working on this box under
  iwd (2026-10-31 22:52) and it does not touch the kernel.
- **There is no way to disable recovery.** A `WIFI_GUARD_RECOVERY` knob once
  allowed `none`, which sent a genuinely dead link straight to the deferred
  reboot, skipping both tiers. On a wifi-only box that is a reboot Tom may not
  survive, so the knob was **removed** rather than documented. Both tiers always
  run; only the module reload can be skipped, and only because another uplink is
  carrying traffic.
- **Recovery tier 2 — brcmfmac reload**: a firmware wedge survives an L2
  reassociation, and a driver reload is the only thing known to clear it. Under
  iwd this stops NetworkManager **and iwd**, unloads `brcmfmac_cyw`+`brcmfmac`,
  reloads, then starts iwd before NM. No `wpa_supplicant` anywhere — it is masked
  and starting it would fail.
  **Refused unload is no longer a reboot**: it retries once after 5 s, and if
  still busy it logs and leaves it to the next 2-minute run
  (`/run/wifi-guard.modrefuse` counts attempts) rather than rebooting on a module
  that is probably still tearing down. Only after refusals on **two consecutive
  runs** does it hand off to the deferred reboot decision.
- **Recovery is judged by "can wifi reach anything"**, not by "both targets
  healthy". Otherwise a good recovery would look like a failure whenever the far
  side happened to be down — and that false negative is what escalates.
- **Reboot only from the deferred `check`** (150 s after both tiers fail), and
  only if wifi is *still* dead **and** no other interface carries a default
  route. The old version's check mode rebooted regardless of another uplink;
  that latent bug is fixed in code we now own. `check` also tests the probe, not
  just IPv4, so "address held, traffic dead" cannot pass it.

### Proven by running it, not by reading it

| test | what actually happened |
| --- | --- |
| healthy, dry run | silent, exit 0 |
| `WIFI_GUARD_FAKE=no-ipv4`, dry run | reported dead (no-ipv4) and printed the full plan |
| `WIFI_GUARD_GW=192.0.2.1` (unroutable), dry run | probe genuinely failed → 1/2, waiting for confirmation |
| state=1 + unroutable gateway | reached 2/2 → recovering |
| `check` + forced dead + eth0 up | "another uplink is up; not rebooting" |
| **real disconnect** | `nmcli device disconnect wlan0` at 23:17:23 left wlan0 up with **no IPv4**; the new guard ran at 23:17:25, logged the profile restart, and at 23:17:48 wlan0 was back on 192.168.1.24 with `ping -I wlan0` OK |
| tier-2 skip (forced dead, eth0 up) | logged "skipping the disruptive brcmfmac reload"; NetworkManager and iwd stayed **active** and wlan0 was untouched. (Run while the `WIFI_GUARD_RECOVERY` knob still existed — that knob is now gone, so this is history, not a usable invocation.) |
| dry run writes nothing | forced-fault dry run: 6 lines to stdout, journal delta **0**; real run with the same fault: journal delta **3** |
| deferred check | fired 23:21:50: "check: wifi is working again; not rebooting"; `boot_id` unchanged |
| **taxonomy: gateway up, off-LAN unroutable** | logged "treating as an upstream fault, not acting"; no recovery, no plan |
| **taxonomy: gateway unroutable, off-LAN up** | logged "wifi works, not acting" |
| **taxonomy: both unroutable** | reached 2/2 → dead → acted (plan, and a real run deferred the reboot decision) |
| `check` with both dead + eth0 up | "another uplink is up; not rebooting" |
| **real disconnect, installed copy** | `nmcli device disconnect wlan0` at 23:55:10; installed guard ran 23:55:12 and logged "recovered by restarting the wifi profile" at 23:55:37; wlan0 back on .24, both probes OK |

Not tested: tier 2 actually running, and therefore the modprobe-refusal retry.
Unloading brcmfmac on the live box is disruptive and was not appropriate to force;
both paths are reviewed but unexercised.

### Commit provenance, so it is not a surprise later

`f7ae105` corrects the README's guard paragraph, and committing that file also
carried **another agent's in-flight README edits** (the uplink/names rewording and
the jason NFS/ufw notes) into the same commit. That was authorised — the
alternative was leaving a false claim about the guard in the tree — but if those
edits were wanted as their own commit, split them out of `f7ae105` rather than
assuming they appeared by accident.

### Standing check: name the branch and its relation to origin, every check

Added 2026-11-01 after this drifted silently. For hours the work was described as
living on `tom-hang-capture`, while the checkout was actually on `master` and that
branch was an ancestor with zero unique commits — believed by everyone, verified by
nobody. A branch name that is assumed rather than printed is the same failure class
as a check that reads clean.

So every report states both, not just the md5:

```bash copy Copy branch identity
cd /home/andy/projects/tom
git branch --show-current
git rev-list --count origin/master..HEAD   # ahead
git rev-list --count HEAD..origin/master   # behind
git status --porcelain                     # uncommitted work
```

If "ahead" is non-zero, local work exists that is neither pushed nor visible to
anyone else. If `git status` is not clean, the deployed copy may already differ
from what was reviewed. Say either explicitly rather than leaving it implied.

### Standing check: the installed copy must match the repo

Since Tom's recovery now depends on `/usr/local/bin/wifi-guard.sh`, and the two
copies are **hand-synced** (no install step, symlink or packaging), every
scheduled check must confirm `md5sum` of
`/usr/local/bin/wifi-guard.sh` equals `scripts/wifi-guard.sh`, and report any
guard cron run that is **not silent**. A healthy run prints nothing; a line in
`journalctl -t wifi-guard` means the guard decided something, which is news worth
reporting rather than filing.

**Report the window and the classification, not just a count.** A bare number is
how the false clean happened: "0 lines since 23:57" was true of a command that
filtered from the future. Every guard-log statement should name the window it was
read over (relative or explicitly dated) and say what the lines were — cron
silence, a real event, or labelled test output. If a window contains test noise,
say so rather than reporting the total.

**Post-event windows start *after* the last known event, not at it.** At the
09:49 check, `--since "2026-11-01 07:10"` returned 4 lines and read like fresh
activity, when all four were the 07:10 recovery it had already explained
(`07:10:01` no-IPv4, `07:10:01` wifi dead, `07:10:01` restarting profile,
`07:10:26` recovered). A window that begins *at* an event re-reports that event
forever. Ask "anything since the last one finished" — here `--since
"2026-11-01 07:11"` → 0 — and say which boundary you used, or the recovery reads
as an incident every single hour.

Read the guard log like this — **never with a bare time**:

```bash copy Copy guard log window
journalctl -t wifi-guard --since "-1 hour" --no-pager
```

Stated here because the recurring check prompt does not ask for either, and a
silent divergence is exactly the failure the hand-sync warning describes: the repo
and the running guard would drift with nothing to flag it.

#### When this check reported a false clean, and why

At the 2026-11-01 00:49 check the guard was reported as **"0 lines since 23:57"**.
It was false: there were **100** wifi-guard lines in that boot. The command used a
bare time, `--since "23:57"`, which journalctl resolves against **today** — by
then 1 November — so it filtered from a moment in the future and matched nothing.
Measured on the same log:

| command | lines |
| --- | --- |
| `--since "23:57"` | **0** (false clean) |
| `--since "2026-10-31 23:57"` | 25 |
| `--since "-1 hour"` | 55 |

A check that reads clean across midnight is the worst failure mode available: it
does not fail, it reports success. Hence the rule above — a relative window or an
explicitly dated timestamp, never a bare clock time. This is the **second** silent
check bug in this ticket, and it belongs next to the header check for the same
reason: both were wrong in the direction of "everything is fine".

#### Silent-failure class 4: a check whose label does not match when it ran

The 2026-11-01 "03:49" check actually ran at **08:51** — both Tom and jason
agreed, NTP-synced on both. Nothing was wrong with either clock; the label on the
check was stale. The effect is that "since the last check" silently covered ~6
hours instead of one, and the report would have looked complete either way.

Rule: **put the real wall time in every report, and never derive a window from
the schedule's intention.** Compare the schedule's stated time against `date` on
the host being read, and if they differ, say so before using either. This is the
fourth class in this ticket, after checks that read clean (the bare `--since`),
instructions that were never carried ([time-triggered actions need the schedule
prompt](#)), and rollback advice that restores a blind watchdog.

#### The 100 test lines at 00:21 and 00:27 are not events

Almost every line in that boot is from guard development, not from Tom. Tagged
`wifi-guard` because `say()` used to `logger` in dry-run mode too. Full
classification of the boot:

| window | what it was |
| --- | --- |
| 22:52:01 / 22:52:22 | **genuinely spontaneous** — the *old deployed* guard reconnecting a dropped wlan0, before the rewrite |
| 23:17, 23:19, 23:21 | deliberate tests I ran: disconnect recovery, module-skip, deferred check |
| 23:53 | deliberate real-mode taxonomy tests (`RECOVERY=none` then went to the defer path) |
| 23:55:12 / 23:55:37 / 23:56:42 | deliberate installed-copy disconnect test and its deferred check |
| 00:21, 00:27 | **dry runs** — should not have been journalled at all |
| 00:54:08 | the real-mode test proving the `say()` fix still logs |
| everything else | the 2-minute cron, which is silent while healthy |

**Do not read any of these as a fault**, and in particular do not read `00:21` or
`00:27` as an event. They are not scrubbed (rewriting history for cosmetics is
worse than labelling it); they are labelled here instead. The ambiguity is fixed
at the source: `say()` now logs only when `DRY=0`, so a dry run writes nothing.

**One line in the pre-unplug batch is now misleading on its own:**
`skipping the disruptive brcmfmac reload: another uplink is carrying traffic`
(00:54:28) referred to **eth0**, which was up at the time and has not existed
since 01:13:08. Read in a post-unplug window it would suggest the guard believed
it had a second uplink when it did not. It is a pre-unplug test line; after the
cable, `have_other_uplink` is false by definition and that branch cannot fire.

**Telling them apart if you are reading an old batch:** a dry run always emits at
least one `PLAN:` line and never a final outcome; a real run emits an outcome
(`recovered by …`, `check: …`, `rebooting`) and never `PLAN:`. That holds for the
historical noise above. The time window cannot separate them — at 00:49 the test
lines were inside the last hour — so the discriminator is content, not time.

**First thing it found, within an hour of being pinned:** the two `@reboot`
samplers had genuinely diverged — `tom-kmsg.sh` and `tom-trace.sh` were fixed in
the repo but Tom was still running the pre-fix copies. Nothing else was watching
that. Both are now synced by atomic replace (so the running processes keep their
old inode and pick up the change on restart).

**Two bugs the tests caught, both of which would have caused spurious reboots.**
First, replacing the single probe left a stale `link_ok() { has_ipv4 &&
probe_ok; }` later in the file which overrode the new function, so every
successful recovery reported "did not restore the link" — the first installed
disconnect test recovered the link and was still judged a failure. Second,
recovery success was being judged by "both targets healthy", so an upstream
outage would have made a good recovery look broken. Both are fixed and both were
only visible by running the thing.

### What it must NOT do once the cable is out — read before unplugging

1. **A router/AP reboot still looks like wifi death.** The two-target taxonomy
   removes the "far side down but LAN healthy" case, but a router reboot takes out
   *both* targets and usually drops the association, so it escalates and can
   reboot Tom after ~200 s. This is the remaining known false positive; watch for
   it on the first wired-free night. Softening it would mean requiring several
   consecutive no-IPv4 runs too (that branch currently acts on the first run) —
   a deliberate latency-vs-spurious-reboot trade the owner should choose.
2. **The other-uplink suppression disappears with the cable**, by definition.
   Once wifi-only, *every* unresolved fault ends in a reboot. Grace before that
   is roughly 20 s (tier 1) + 30 s (tier 2) + 150 s (deferred) ≈ 200 s.
3. **A slow DHCP could be mistaken for death.** If re-association takes longer
   than ~200 s, the guard reboots a box that would have recovered.
4. **`modprobe -r` being refused** falls through to the deferred check and then a
   reboot, rather than retrying.
5. It will **not** reboot while wifi is working — proven twice above.

## Cable removal plan (owner: within 24 h, monitoring continues ~1 further day)

### The uptime record resets at the unplug

**Keep 3 h 03 m 11 s as the pre-cable baseline** (boot 19:30:54 → cable 22:34:05).
It stays the number the wifi path is judged against. From the moment eth0 drops, a
**new counter starts** at that timestamp, and from then on **every second is
evidence about the wifi path again** — the "dual-homed and therefore weaker"
caveat ends. That cuts both ways: a new record is finally meaningful, and a router
reboot is now a real risk rather than a footnote (see the router/AP caveat above).

Record the exact unplug time when it is observable, from the first of:
`journalctl -o short-precise | grep -i "eth0.*carrier: link disconnected"`, or the
last moment `eth0` held an address, or `ip route show default` no longer listing
`dev eth0`. Write that timestamp here when it happens.

### Reachability audit — what actually depends on `.23`

Checked before the cable goes. **Nothing needs changing for the unplug to work:**

| dependency | state | verdict |
| --- | --- | --- |
| jason `/etc/hosts` | `tom.local` mapped to **both** `.24` and `.23`, `.24` first | fine; `.24` wins, `.23` just fails fast afterwards |
| jason `~/.ssh/config` `Host tom` | `HostName tom.tailad1015.ts.net` (tailnet) | uplink-agnostic, fine |
| jason `Host tom-wired` | hard-coded `.23` | **will stop working** — by design, it is the wired alias |
| jason `/etc/exports` | `.24` **and** `.23` | fine; the `.23` entry simply goes unused |
| jason ufw `2049/tcp` | `.24` **and** `.23` | fine, same |
| jason cron / systemd timers | nothing references Tom | fine |
| Tom listeners bound to `.23` | none (all wildcard) | fine |

Optional tidy-up after the cable is out: drop the `.23` line from jason's
`/etc/hosts` and the `.23` entries from exports/ufw. Not required, and not done —
they are harmless and someone may plug the cable back in.

### Found while auditing: ssh to `.24` failed for a reason that was not Tom

Three times, `ssh tom@192.168.1.24` timed out **while `ping` to `.24` was 0% loss
at ~3.4 ms**. It is not Tom. jason's `~/.ssh/config` documents it — default SSH
`IPQoS` marks packets that jason's UFW/conntrack drops, so connects time out —
and the **`Host tom` / `Host tom-wired` blocks carry `IPQoS none`**, but an ad-hoc
`ssh tom@<ip>` matches no block and does not get it. Measured: with
`-o IPQoS=none`, 3/3 succeeded; without, 3/3 timed out.

Compounding it, Tom was dual-homed: `ip route get 192.168.1.181` returns
`dev eth0 src 192.168.1.23`, so a connection *arriving* on `.24` is answered from
`.23` — an asymmetric flow that jason's conntrack does not like. **The unplug
should remove that half of the problem**, since with no eth0 there is no
alternative source.

Rule for checks from now on: always `-o IPQoS=none`, try `.24` first, then the
tailnet name, and treat `.23` as available only while the cable is in. **Never
conclude a crash from an ssh timeout** — that distinction already cost a wrong
call once tonight.

### The first check after the unplug asks a different question

**Reporting shape once the cable is out: lead with the wifi-only counter and any
guard line, then uptime.** The counter is now the only thing measuring anything —
uptime on a wired-free box is the same number with more words. The counter starts
at the eth0-gone timestamp, not at boot.

**Reporting precedence: if the guard logs anything at all, that is the headline of
the check — ahead of both.** A guard line means it
decided something about a link the owner can no longer reach around, so it
outranks the usual lead fields rather than being appended to them.

Once eth0 drops, "is Tom up" stops being the interesting question; **"did it
survive the change"** is. A reboot within minutes of the unplug is a *different
event* from the silent hourly resets this ticket is about, and must be reported as
such — correlate the boot with the eth0-gone timestamp and say plainly that the
reboot followed the cable removal, rather than reporting a boot count as if it
were the usual unexplained reset. Conflating the two would either manufacture a
regression or hide one.

### Standby item: the deliberate disconnect test (item 4), still not run

Authorised 02:49, **not executed**. By the time it was started (08:50) Tom had
rebooted and the guard had already recovered organically, so running a synthetic
disconnect on top of an unexplained reset would have mixed two things.

**What it would still test:** tier 1 is now proven on a real fault (25 s,
unattended, see above). Untested are **tier 2 (brcmfmac reload)** and the
**deferred reboot path** — neither has ever executed.

**How it gets scheduled:** it is carried by the recurring check prompt from here,
not by "idle until HH:MM". That phrasing means "wait until someone messages me",
which is how it silently failed to happen the first time (silent-failure class 3).

### Watching from outside: `scripts/tom-watch-remote.sh`

Runs on **jason**, not Tom, and logs UP/DOWN transitions to `/tmp/tom-watch.log`.
Tom's own loggers cannot report how long it was unreachable — they stop
mid-sentence when the board dies — so an outside observer is the only thing that
turns "Tom rebooted" into "unreachable for N seconds at HH:MM:SS".

Started as `nohup ./scripts/tom-watch-remote.sh >/dev/null 2>&1 &`, with the PID
recorded in `/tmp/tom-watch.pid`. **Stop it by that PID**, never by pattern — the
same trap that killed two shells in one night. If the pidfile is missing, read the
PID from `ps -eo pid,ppid,args | grep tom-watch | grep -v "bash -c"`.

### First read after the next reset — in this order

Written down now so nobody has to work it out while Tom is down and the clock is
running.

**0. Read this correction first — the tee is incomplete at the moment of death.**
Proven on 2026-11-01: boot `b63e886a` panicked at 10:30:49, and its section of the
tee ends at 07:10:14 followed by **NUL bytes**. The final burst — 45 kernel lines
including the stall dump and the panic — never reached disk, because `panic=15`
reboots without syncing and ext4's delayed allocation hands back zeros.
`journalctl -b -1` held all of it. So: **journald is the source for the last 60
seconds; the tee is the source for everything before it.** Never conclude "silent
death" from the tee alone. A NUL tail is the tell that a burst was lost.

**Updated 2026-11-01 14:13 — that is only true for slow panics.** For an *instant*
panic (sysrq at 14:13:01 → reboot 15 s later) journald lost it too: `-b -1` had
**zero** panic lines and the tee had none, while pstore had the whole stack. So the
real rule is: **pstore first, then journald, then the tee** — a fast panic is only
ever in pstore, a slow one (tens of seconds of stall) is in journald as well, and
the tee's tail is lossy either way.

**1. `/var/log/tom-kmsg.log` — primary evidence for the run-up.** Microsecond
timestamps, and the per-boot header tells you which section is the dying boot:

```bash copy Copy first read after a reset
sudo grep -an "===== boot" /var/log/tom-kmsg.log | tail -3      # which section is the dead boot
sudo sed -n '/===== boot <THAT TIMESTAMP>/,$p' /var/log/tom-kmsg.log | tail -60
```

Search inside the dying section, in this order, and say what you find or that you
found nothing:

| pattern | what it would mean |
| --- | --- |
| `rcu_preempt`, `rcu_sched`, `stall` | a CPU wedged — the known hang shape; note which core |
| `mmc`, `sdhci`, `I/O error` | SD or SDIO stop — storage showing up before the reset |
| `nfs`, `macb`, `eth0` | the network/NFS path; the 07:07:42 correlation lives here |
| `sched`, `DL replenish` | scheduler starvation preceding a freeze |
| `brcmf`, `-110` | wifi firmware wedge returning |
| `thermal`, `under-voltage`, `throttled` | power or heat |

**2. `/sys/fs/pstore` — and archive before anything else touches it.** If a dump
exists, `sudo tar czf` it out first, then read it; a panic wipes the next one.

**But an empty pstore needs interpreting, not just reporting — say which of two
things it means, every time.** The plumbing is proven: the 2026-11-01 14:13 sysrq
test produced a 27248-byte `dmesg-ramoops-0`. So after the next *organic stall*:

- **No record, and there was a panic** → that is **evidence for the lock-contention
  hypothesis**: the dump runs on a CPU that has to take locks, and our fault is a
  CPU wedged holding them, so the write never completes. Report it as support for
  that hypothesis, not as "pstore produced nothing" and not as a null result. It is
  also the only way the hypothesis gets tested, so write down which it was.
- **No record, and no panic either** (a silent death with nothing in journald or the
  tee) → that is the genuine null case; say so plainly and move on.

Also check `/var/lib/systemd/pstore/` as well as `/sys/fs/pstore/`: `systemd-pstore`
runs at boot and **moves** any record out of `/sys/fs/pstore` before you can look.
This is not theoretical — at 14:13 the first location was empty and the record was
in the second, and checking only `/sys/fs/pstore` would have produced a confident,
wrong "no record".

**Three outcomes, and the report must name which one occurred.** This is now our
only measurement of the lock-contention hypothesis, so an unlabelled "pstore empty"
throws the measurement away:

| observed after a reset | what it means |
| --- | --- |
| **record present, stall panic** | **the hypothesis is falsified** — a wedged CPU did reach the dump path. Worth more than the other two combined; say so and re-open the mechanism question |
| **no record, panic happened** | support for lock contention: the dump needed locks the wedged CPU held |
| **no record, no panic** | a genuinely silent death — the null case; say so plainly, it is not evidence either way |

**3. `scripts/tom-watch-remote.sh` log (`/tmp/tom-watch.log`) — the outside view.**
This is the only source that says **how long** Tom was unreachable, because Tom's
own loggers stop when it dies. Gives the exact down window.

**3b. Was the NFS mount up at the moment of death?** NFS is a closed negative
(above), and it must stay *measured* rather than assumed, so answer this explicitly
on every reset instead of implying it from a post-boot `findmnt`.

There are two different questions and it is easy to answer the wrong one:

| question | how to answer | what it does **not** tell you |
| --- | --- | --- |
| Is the mount up **now**? | `mountpoint -q /mnt/storage && echo up` (or `findmnt -no SOURCE /mnt/storage`) | nothing about the moment of death — the boot remounted it |
| Was it up **at death**? | the dying boot's own journal, and jason's side | that it stayed up during the outage |

At-death evidence, in order:

1. **Dying boot journal:** `journalctl -b -1 | grep -iE "nfs|mnt-storage|server not responding"`. A clean tail with no NFS messages means the mount was quiet to the end; `server not responding` or a `mnt-storage.mount` event in the last seconds means it moved before the death.
2. **jason's side** (the exporter, `192.168.1.181`): `systemctl is-active nfs-server`, `exportfs -v`, `nfsstat -s` counters, and `journalctl -u nfs-server --since <death-10min>` on jason — it keeps logging after Tom dies, which is the whole point.
3. **The preserved `/tmp/cablewatch.log` on jason** — 6-second samples of an actual read, but **it ends at 14:06 on 2026-11-01**, when that poller was killed.

**The gap this exposes:** closing NFS as a suspect used that poller's 8827 samples,
and killing it removed the instrument. From 2026-11-01 14:07 there is **no
continuous NFS read record on this box**. So the next reset cannot repeat the
measurement that closed the hypothesis — it can only be checked against journald and
jason's server side. If the negative needs re-measuring, a minimal probe has to be
re-added deliberately (owner's call, and it must not be a 6-second `ls` on the
subsystem under investigation — that is a confounder, which is why the original was
retired).

**4. `/var/log/tom-trace.log` — corroboration only.** 15 s resolution, so it
cannot see the final seconds; use it for the run-up (was I/O or wifi moving
before), not for the moment of death. That is exactly the limit that made the NFS
question unanswerable from it.

**How to read the fields — `mmc_io_ms` is cumulative, not per-sample:**

| field | source | kind |
| --- | --- | --- |
| `mmc_rd`, `mmc_wr` | `/sys/block/mmcblk0/stat` fields 1, 5 | cumulative counts |
| `mmc_io_ms` | field 10, `io_ticks` | **cumulative ms**, monotonic within a boot, reset at boot |
| `mmc_busy` | field 9, in-flight I/Os | instantaneous gauge, the only one of these that can fall |

Verified on boot `76a0c076`:

```text
10:35:01  up=125    mmc_rd=16140  mmc_wr=2838   mmc_io_ms=13388
10:50:01  up=1026   mmc_rd=25736  mmc_wr=22031  mmc_io_ms=44336
11:30:03  up=3427   mmc_rd=42381  mmc_wr=80503  mmc_io_ms=109876
12:22:04  up=6548   mmc_rd=42822  mmc_wr=156800 mmc_io_ms=171764
12:50:05  up=8229   mmc_rd=42999  mmc_wr=200432 mmc_io_ms=207300
```

**The correct reading:** compare **deltas between matched uptime points inside one
boot**, never absolute values across boots — a fresh boot starts every counter at
0, so the same workload looks like a dramatic improvement. And a *decrease* within
a boot is not less I/O; it means the counter reset, i.e. a new boot or the device
re-enumerated, which is itself a finding worth chasing.

**The trap this note exists to prevent.** During the 12:49 check I reported
`mmc_io_ms` as "non-monotonic, an interval measure" on the strength of
`172720 → 20666`. That was false: the second number was my own `cut -c1-96`
truncating the field mid-value. The counter was 172720 → 207300, perfectly
monotonic.

**Reporting rules for numbers — this is a rule, not a formatting preference:**

1. **Quote the field whole, and name its index and source in the same breath.**
   `207300` says nothing on its own, and `mmc_io_ms` alone does not say what it
   measures. Write "`mmc_io_ms` 207300 — field 10 of `/sys/block/mmcblk0/stat`,
   cumulative since boot". The next reader, or the next session, cannot
   reconstruct the meaning from a bare number, and a truncated one is
   indistinguishable from a real reading.
2. **When a reading looks anomalous, re-read it raw before reporting it.** One
   command — `cat /sys/block/mmcblk0/stat`, or the untruncated log line —
   separates a finding from an artefact. `cut` is the usual culprit; shell
   pipelines that format for display are where truth gets lost.

The cost of skipping rule 2 is not a typo: this one reached a report before it
was caught, and would have entered this ticket as a fact.

**5. Then `journalctl -b -1`,** for service-level context around the same second.

### Watcher health — check it every time, headline if dead

The watcher is our only continuous outside view; a dead watcher is the same class
of failure as a stale label, because the report would look complete while the
instrument was gone. It now writes a `HEARTBEAT` line every 10 minutes precisely
so recency means something — with transitions only, a healthy watcher could sit
silent for hours and a recency check would cry wolf.

```bash copy Copy watcher health
P=$(cat /tmp/tom-watch.pid)
ps -o pid,etime,args -p "$P" || echo "WATCHER DEAD"
tail -1 /tmp/tom-watch.log
```

Healthy: the PID answers `ps`, and the last line is under ~20 minutes old. If
either fails, **say so as the headline** — the report is not complete without it.
Restart with `nohup ./scripts/tom-watch-remote.sh >/dev/null 2>&1 &` and rewrite
`/tmp/tom-watch.pid` from `ps`, never from a pattern match.

### The 07:07:42 reset, and what the trace log says about the NFS idea

Boot `c2fe5d10` ended at **07:07:42** after **11 h 36 m 48 s** — far longer than
anything before it — with the same silent signature: no shutdown messages, 0 rcu
stalls, 0 panics, pstore empty, systemd-pstore archive empty. Nothing captured the
cause.

The last two journal entries are Tailscale SSH sessions from jason at 07:07:36 and
07:07:42; the second's command was `ls /mnt/storage`, an NFS read. That is a
correlation, and here is the measurement behind it rather than a hunch — trace
samples for the 75 s before death:

| time | load1 | Δ mmc_io_ms / 15 s | mmc_busy | Δ wlan tx bytes / 15 s |
| --- | --- | --- | --- | --- |
| 07:06:17 | 0.11 | +448 | 0 | +45,813 |
| 07:06:32 | 0.61 | +268 | 0 | +62,084 |
| 07:06:47 | 0.48 | +364 | 0 | +43,287 |
| 07:07:02 | 0.37 | +280 | 0 | +48,154 |
| 07:07:17 | 0.29 | +324 | 0 | +61,521 |

**This argues against an NFS-triggered stall inside the observed window**, and it
is worth being precise about why: no outstanding I/O at any sample (`mmc_busy=0`),
SD I/O time *declining* rather than climbing, wlan throughput steady in its normal
band with no retransmit spike, and load falling after a single bump. The last
sample looks structurally identical to the minutes before it.

**What it cannot rule out:** death came **25 s after the last sample** (sampler
interval 15 s), and that gap is unobserved. So this neither confirms nor excludes
something starting in the final seconds. It weakens "NFS read stalled the box" as
a description of the visible run-up; it does not close the question.

Next time, the way to settle it is the tee rather than the sampler: `dmesg -w` has
microsecond resolution and will hold the last seconds if the console path survives
— check `/var/log/tom-kmsg.log` for the dying boot for `nfs`, `macb`, `mmc` and
`sched` lines in its final second.

### False-positive classes — read before interpreting a failed check

Two ways a check can fail for reasons that are **not** Tom being unhealthy. Both
have already produced misleading signals in this investigation; anyone reading
the record later should count neither against the box.

**1. An ssh timeout is not a crash.** Three ssh timeouts sat in tonight's record
looking like evidence about Tom's stability, and they were evidence about jason's
conntrack. Default SSH `IPQoS` marks packets that jason's UFW/conntrack drops, so
connects time out while the host is perfectly reachable — `ping` to `.24` was 0%
loss at ~3.4 ms throughout. jason's `~/.ssh/config` documents the fault and puts
`IPQoS none` on the `Host tom` and `Host tom-wired` blocks, but an ad-hoc
`ssh tom@192.168.1.24` matches no block and does not get it. Measured both ways:
**3/3 succeeded with `-o IPQoS=none`, 3/3 timed out without it.**

Compounding half, which the unplug removes: while dual-homed, `ip route get
192.168.1.181` on Tom returns `dev eth0 src 192.168.1.23`, so a connection
*arriving* on `.24` was answered from `.23` — an asymmetric flow conntrack
dislikes. With no eth0 there is no alternative source, so this half disappears
when the cable does.

Rule: always `-o IPQoS=none`; a timeout means "retry another way", never "Tom
crashed".

**2. `.23` disappearing is expected, not an incident.** Once the cable is out,
`.23` is gone by design and anything aimed at it will fail. The first wired-free
check must say "address gone because the cable is gone" and not read like an
outage. Only `.24` (and the tailnet name) are meaningful after the unplug.

### One hour after the unplug — verification to report

1. `wlan0` is the **default route** (`ip route show default` lists `dev wlan0`
   and no `dev eth0`).
2. The guard's two probes both pass over wlan0: gateway and `1.1.1.1`, via
   `ping -I wlan0`.
3. Cron is still running it every 2 minutes and the runs are **silent** (any
   `wifi-guard` line is news), and the installed md5 still matches the repo.
4. **A deliberate `nmcli device disconnect wlan0` recovers on its own with no
   eth0 present.** This is the only test that proves the wired-free path actually
   works before it is needed — and with no cable a failure here means no remote
   recovery.

   **Owner decision: held deliberately, not on a timer.** Sequence: wait one hour
   after the cable is out, confirm items 1–3, then ask the owner again with the
   current uptime, the eth0-gone timestamp, and whether anything has already gone
   wrong. The owner calls it at that point. Rationale on record: the first hour
   without the cable is the cheapest time to discover a problem while the box is
   still up, and the disconnect test happens with the owner at a terminal rather
   than firing unattended.

## Authorised after the fact

- `kernel.panic_on_rcu_stall=1` was applied as part of the 2026-10-31 capture
  change without being in the original three-item authorisation, and the owner
  approved it afterwards ("a capture that can't fire on the actual failure mode
  isn't a capture"). It gives roughly a 21 s self-recovery on stall boots
  instead of waiting out the 1-minute watchdog.

## 2026-11-01 10:30–10:34 — two resets 97 s apart, and the first captured stall payload

Measured 2026-11-01 10:49–10:52 AEST, cable still out, `eth0` `DOWN`.

| boot | started | ended | length |
| --- | --- | --- | --- |
| `b63e886a` | 07:08:00 | **10:30:49** | 3 h 22 m 49 s |
| `204f8e94` | 10:31:02 | **10:32:26** | **84 s** |
| `76a0c076` | 10:32:58 | running | — |

The watcher's outside view: `DOWN 10:30:42 → UP 10:32:05` (1 m 23 s) and
`DOWN 10:32:36 → UP 10:34:04` (1 m 28 s) — **2 m 51 s unreachable in total**.
Both resets are new since the 07:07:42 one; the 84-second boot is a shape not seen
before.

The guard fired on both boots, tier 1, unattended, in ~25 s each: `10:32:01.714 →
10:32:26.407` and `10:34:01.749 → 10:34:26.384`, both "wlan0 has no IPv4" →
profile restart. **Post-reset, wlan0 consistently comes up without an IPv4 lease
until the guard restarts the profile** — that is now the normal recovery step, not
a fault on top of one.

### The stall payload — what `panic_on_rcu_stall` bought us

Boot `b63e886a`, from `journalctl -b -2`:

```text
rcu: INFO: rcu_preempt detected stalls on CPUs/tasks:
rcu:     3-...0: (4 ticks this GP) idle=daac/1/0x4000000000000000 softirq=344573/344574 fqs=1036
rcu:     (detected by 2, t=5256 jiffies, g=791465, q=2608 ncpus=4)
Sending NMI from CPU 2 to CPUs 3:
i2c_designware 1f00088000.i2c: controller timed out
imx708 10-001a: imx708_stop_streaming failed to set stream
rcu: rcu_preempt kthread timer wakeup didn't happen for 2504 jiffies! ... Possible timer handling issue on cpu=2
Kernel panic - not syncing: RCU Stall
```

**CPU 3 wedged and did not answer the NMI from CPU 2** — the same core as the
earlier stalls. Panic at `10:30:49.585`, next boot `10:31:02` = 13 s, i.e. the
`panic=15` path, not the 1-minute hardware watchdog. pstore was empty afterwards —
see "pstore: registered, correctly sized, and still silent" below for why that is a
separate problem rather than an explanation.

### The camera/i2c pairing — counted across every boot in the journal, and it is a symptom

**71 boots are retained. 23 logged an RCU stall. 8 logged an i2c controller
timeout. 8 logged `imx708_stop_streaming failed`. Exactly 1 logged a panic.**

The two camera-bus messages are not merely correlated, they are the **same eight
boots**, in both directions — there is no boot with one and not the other:

| boot | RCU stall lines | i2c timeout | `stop_streaming` failed |
| --- | --- | --- | --- |
| `-62` | 30 | yes | 1 |
| `-53` | 2 | yes | 2 |
| `-39` | 1 | yes | 1 |
| `-25` | 2 | yes | 2 |
| `-23` | 4 | yes | 1 |
| `-16` | 2 | yes | 1 |
| `-5` | 1 | yes | 1 |
| `-2` (panicked) | 1 | yes | 1 |
| the other 63 boots | 0 in 48 of them, 1–3 in the rest | 0 | 0 |

So, plainly:

- **8 of 8 i2c-timeout boots also stalled. 8 of 8 `stop_streaming` boots are the
  same boots.** Neither message has ever appeared without a stall.
- **But only 8 of the 23 stall boots mention either.** 15 stalls happened with no
  camera-bus message at all.
- `imx708` line *counts* are not a discriminator (baseline 22–23 per boot; only
  `-62`, `-53`, `-25`, `-23`, `-16` rise above it).

**The ordering kills the causal reading.** In `-25`, `-23` and `-16` the i2c
timeout and the camera failure appear **after** `Sending NMI from CPU … to CPUs 3`,
by microseconds to seconds:

```text
-25  05:16:25.021980  rcu: INFO: rcu_preempt detected stalls
     05:16:29.343331  Sending NMI from CPU 0 to CPUs 3
     05:16:29.343369  i2c_designware 1f00088000.i2c: controller timed out
     05:16:29.343627  imx708 10-001a: imx708_stop_streaming failed to set stream
```

That is the frozen bus reporting, not a fault that preceded the wedge. And the
ratio says the same thing: if the camera were the trigger, most stalls would show
it; instead only a third do, i.e. the camera has to be *mid-transaction* when the
CPU wedges for the message to appear. Symptom, not cause — and the messages are
useful as a fingerprint of *which* core and path was busy at the wedge, not as the
reason for it.

**What this means for the proposed six-hour petcam test:** still informative, but
its prior is now *lower*, not higher. If stalls stop with petcam stopped the
camera path is genuinely involved; if they continue it is not. Nobody should
expect the camera to be the cause on this evidence — the strongest single fact
remains that a stalled CPU 3 does not answer an NMI, which is a layer below any
driver.

### `panic_on_rcu_stall=1` — the trade, and when to turn it off

Kept. It is what produced the first real stack trace of the investigation, and
without it `b63e886a` would have been another silent death.

The cost, stated honestly: **an RCU stall is survivable.** `f697b023` stalled at
`19:08:40` — with no `panic_on_rcu_stall` set yet — and kept running another 22
minutes to a deliberate shutdown. So the sysctl converts a fault that *might*
self-heal into a guaranteed reboot. That is worth paying while the cause is
unknown, because the alternative is a board that reboots silently and tells us
nothing.

Turn it off when any one of these becomes true:

- the stall has a known cause and a fix, so the trace is no longer needed;
- stalls are frequent enough that the reboots cost more than the diagnosis is
  worth (rough guide: more than ~3 per day);
- the stall turns out to be a *consequence* of the real fault rather than the
  fault, and the panic is destroying evidence of the earlier stage — in that case
  reverting costs nothing and keeps the box up.

Also keep in mind: the stall is detected *after* the wedge (up to ~52 s, the
`t=5256 jiffies` in `b63e886a`), so the panic timestamp is not when things went
wrong.

### The tee lost its own ending — journald is the source for the last 60 s

The tee's section for `b63e886a` ends at **07:10:14**, and the bytes after it are
**NUL**. The kernel was genuinely quiet between 07:11 and 10:30:30 (journald: 0
kernel messages), so the file is honest about the quiet — but the final 45 kernel
lines, including the whole stall dump and the panic, never reached disk.
`panic=15` reboots without syncing, and ext4's delayed allocation returns zeros.
`journalctl -b -2` had all of it. Read order corrected at "First read after the
next reset".

### The 84-second boot (`204f8e94`) — what killed it

The three sources, in time order:

| time | source | what |
| --- | --- | --- |
| 10:31:02 | `journalctl --list-boots` | boot starts |
| 10:31:09.617 | kernel (journald **and** tee agree) | last kernel message: `tun: Universal TUN/TAP device driver` |
| 10:32:01.749 | wifi-guard | fires, tier 1, `wlan0 has no IPv4` |
| 10:32:26.407 | wifi-guard | "recovered by restarting the wifi profile" |
| 10:32:26.846 | tailscaled | ssh session from jason starts a python heredoc |
| 10:32:26.885 | journald | **last line of the boot**: `Started session-c6.scope` |
| 10:32:58 | `--list-boots` | next boot starts — **31 s later** |

What this establishes:

- **The guard did not kill it.** The recovery message is at `10:32:26.407` and the
  board kept logging for another 0.48 s. A profile restart that killed the board
  would not leave it running and starting new logind sessions afterwards.
- **It was a hard reset, not the panic path.** The next boot came 31 s after
  death; the `b63e886a` panic-to-boot gap was 12.4 s (`panic=15`). Different
  reset type.
- **It was silent at kernel level**, like `c2fe5d10` at 07:07:42 and unlike
  `b63e886a` at 10:30:49. No stall, no panic, nothing in the tee, nothing in
  pstore.
- The only thing that distinguishes it from every other silent death is that it
  came **97 s after a panic-driven reboot**, 84 s into a boot that never settled.
  Hypothesis, not finding: a warm reset (`reboot=w` is firmware-injected, it is
  not in `cmdline.txt`) leaves the board in a state where a second reset follows.
  Testable cheaply — if a future panic reboot is followed by a short-lived boot
  again, that is the pattern; if not, this was a one-off.

### Provenance of the tailscale sessions — answered

Eight sessions bracketed the two resets (`10:30:22`, `10:30:28`, `10:30:29`,
`10:30:36`, then `10:32:09`–`10:32:26`). They were **not** from this thread and
not from Tom itself. The command line answers it:

```text
--remote-user=andrew.hale003@gmail.com --remote-ip=100.95.54.82 --cmd=echo TOM-UP; u...
```

`100.95.54.82` is **jason**. The commands are read-only health probes (`echo
TOM-UP`, `ip -br addr`). No script in this repo, no crontab entry, and no running
process on jason produces them, and this thread's own ssh uses plain sshd from
`192.168.1.181` (visible in `who`) rather than Tailscale SSH. So the likely source
is another agent session on jason, not a scheduled job. Recorded as provenance
because a box that resets while someone is logged into it has a confounder; the
commands themselves are innocuous.

### pstore: registered, correctly sized, and still silent

> **Resolved later, 2026-11-01 14:13.** A deliberate sysrq panic produced a
> 27248-byte record, so the plumbing works — see "The `sysrq` pstore test".
> The question left open here narrowed rather than closed: the *stall* panic still
> wrote nothing, which is now evidence for lock contention rather than a mystery.

This is the one open question that got worse, not better. The `b63e886a` panic was
exactly the case ramoops exists for, and it produced nothing.

What is *not* wrong:

- The region is reserved: `reserved mem: 0x0b000000..0x0b00ffff (64 KiB) map non-reusable ramoops@b000000`.
- Zones are configured: `record-size = 0x4000` (16 KiB × 4), `console-size = 0` — enough for the ~6 KB stall dump.
- `max_reason = 2`, so `KMSG_DUMP_PANIC` (1) is at or below the threshold.
- `systemd-pstore` is **not** eating it: the unit skipped with `ConditionDirectoryNotEmpty=/sys/fs/pstore` unmet, and `/var/lib/systemd/pstore/` is empty.
- Compression is on (`deflate`), `ecc: 0`, and the region is excluded from the allocator.

So the capture path is configured correctly and produces nothing. Two candidates
remain, and they need different fixes:

1. **The write never happens** — the panic path on a wedged CPU does not reach
   `kmsg_dump()`, or deadlocks on its lock.
2. **The write happens and is lost** — the Pi 5 firmware/`reboot=w` path clears or
   re-trains the reserved region before the next kernel reads it.

They are separable by one test that reboots Tom: `echo c > /proc/sysrq-trigger`
with `panic=15`, then check `/sys/fs/pstore` before anything else runs. A record
there means the panic path works and our real panics differ (candidate 1 is about
the *wedged* panic specifically); no record with a clean panic means the region
does not survive (candidate 2). **Not run — it reboots the board, so it is the
owner's call.** Until one of them is ruled out, "pstore empty" is not evidence of
a silent death, and must stop being read as one.

## Why `ssh tom` goes over Tailscale — measured 2026-11-01 11:08–11:13

Asked directly, so measured rather than reasoned.

**Resolution and route:**

| command | resolves to | route |
| --- | --- | --- |
| `ssh tom` | `tom.tailad1015.ts.net` → `100.77.132.110` | `dev tailscale0 table 52 src 100.95.54.82` |
| `ssh tom@192.168.1.24` | as typed | `dev wlp13s0 src 192.168.1.181` |

Both hosts are on the same LAN (jason on wifi `wlp13s0` at `.181`, Tom on wifi at
`.24`).

**Latency — the tailnet path is not slower, because it is not relayed:**

```text
ping 192.168.1.24       rtt min/avg/max/mdev = 1.306/3.477/4.579/1.284 ms
ping 100.77.132.110     rtt min/avg/max/mdev = 1.790/3.829/5.117/1.246 ms
```

`tailscale status` shows `tom ... active; direct 192.168.1.24:41641` — the
WireGuard tunnel is **direct over the LAN**, and `relay=syd` is configured but
unused. So the tailnet adds a WireGuard header, not a hop.

**Handshake — the tailnet path is actually faster:**

```text
ssh tom              73 ms, 73 ms, 82 ms
ssh tom@192.168.1.24 129 ms, 150 ms, 131 ms   (with -o IPQoS=none, so not the conntrack trap)
```

`ssh -v tom` explains it: `remote software version Tailscale`, `Authenticated to
tom.tailad1015.ts.net ... using "none"`. This is **Tailscale SSH, not sshd** —
identity-based, so there is no key exchange and no publickey auth round trip. The
`.24` path is full sshd over wifi.

**When and why it changed:** `~/.ssh/config` was edited at **2026-10-31 22:42**
(the backup `~/.ssh/config.bak-20261031-2242` is the pre-change copy), which is
while the cable was still in and before the 01:13 unplug:

```diff
-Host 192.168.1.24 raspberrypi tom
-    HostName 192.168.1.24
+Host tom raspberrypi
+    HostName tom.tailad1015.ts.net
```

The reason is recorded in the reachability audit above: default SSH `IPQoS`
marking that jason's UFW/conntrack dropped (3/3 timeouts without `IPQoS none`,
3/3 success with it), compounded by Tom being dual-homed and answering a
connection that arrived on `.24` from `.23` — an asymmetric flow. Pointing `Host
tom` at the tailnet name removed both problems at once.

**So the current state is not wrong, and the premise "LAN is faster" does not hold
here.** Same RTT, faster handshake, works off-LAN, survives a DHCP change. What we
pay is a dependency, not milliseconds.

**The tradeoff, stated as a tradeoff:**

| | tailnet alias | LAN address |
| --- | --- | --- |
| latency | same (direct path, ~3.8 ms) | ~3.5 ms |
| handshake | faster (Tailscale SSH, ~78 ms) | sshd, ~137 ms |
| survives IP change / off-LAN | yes | no |
| depends on | tailscaled on both ends **and** the Tailscale control plane | jason's UFW/conntrack behaving, DHCP reservation, Tom's wifi |
| forensics | sessions appear as `tailscaled` / `ssh-session(...)`, almost no PAM trail | normal sshd, `who`, `last` |
| failure we have already hit | — | `IPQoS`/conntrack, dual-homed asymmetric replies |

**Recommendation: keep `Host tom` on the tailnet name** for an hourly-monitored
box. It is the path that already survived the unplug unattended, it does not
depend on a DHCP lease or on Tom's wifi coming back with the *expected* address,
and it is measurably faster to connect. The cost is one dependency — the control
plane — and that is acceptable because the tunnel is direct when both ends are on
the same LAN, so a control-plane outage does not break an established path.

Two things to keep, though:

- **The outside view must not use it.** `scripts/tom-watch-remote.sh` pings
  `192.168.1.24` over the LAN, which is correct: if Tom is down, so is its
  tailscaled, so a tailnet ping tells you nothing extra and adds a second thing
  that can be the fault.
- **Keep a LAN alias as the fallback.** `Host tom-wired` currently points at
  `192.168.1.23`, which is dead now the cable is out; a `tom-lan` →
  `192.168.1.24` alias with `IPQoS none` is the useful second door.

**Forensic cost worth knowing:** because `ssh tom` is Tailscale SSH, its sessions
appear in Tom's journal as `tailscaled` / `ssh-session(sess-...)`, not as sshd
sessions with a source IP in `who`. That is exactly why the eight sessions
bracketing the 10:30 resets took a `--remote-ip=` extraction to attribute.

## The `sysrq` pstore test — RUN 2026-11-01 14:13, and the dump path works

Run after the gate opened at 14:12:55 (0 sessions in 5 min, having stopped the
orphaned watcher at 14:07). Pre-flight passed on all four: `panic=15` in
`cmdline.txt`, `kernel.panic=15`, `panic_on_rcu_stall=1`, `ramoops: using
0x10000@0xb000000`.

| step | time | result |
| --- | --- | --- |
| trigger `sysrq c` | 14:13:01 | ssh died with exit 255 — success, as expected |
| old boot `76a0c076` ended | 14:12:55 | 3 h 39 m 57 s, no faults before it |
| new boot `67e59294` | 14:13:27 | panic→boot gap ~26 s (15 s panic + cold boot) |
| guard fired | 14:14:01.716 | `wlan0 has no IPv4` — the predicted post-reset behaviour |
| guard recovered | 14:14:26.368 | 24.7 s, unattended |
| new boot header | 14:13:29 | **exactly one**, +2 to +5 s of boot start — post-panic capture clean |

**The record exists**, at `/var/lib/systemd/pstore/dmesg-ramoops-0`, 27248 bytes:

```text
Panic#1 Part1
...
[13205.522089]  sysrq_handle_crash+0x24/0x38
[13205.526109]  __handle_sysrq+0x98/0x1a0
[13205.529866]  write_sysrq_trigger+0xc8/0xe0
[13205.571188] SMP: stopping secondary CPUs
```

**`/sys/fs/pstore` was empty and `/var/lib/systemd/pstore` had it** — exactly the
trap this ticket warned about, caught in the act. Checking only the first location
would have produced a confident, wrong "no record".

Archived before clearing: 8465-byte gzip at `/tmp/pstore-capture-1413.tgz` on Tom
and `.amp/in/artifacts/pstore-capture-1413.tgz` on jason
(md5 `63c078e2d6fb4a38365e1d0b90b7701f`). The live record was then cleared so a
future "is pstore non-empty" check means something.

### The discriminator, answered — and the inversion it exposed

**The dump path works end to end on this board.** ramoops registers, the panic
writes, the record survives the reset, and systemd-pstore archives it. pstore is
*not* dead weight, and `dtoverlay=ramoops-pi5` stays.

But this test inverted the read order we established this morning:

| panic | journald | kmsg tee | pstore |
| --- | --- | --- | --- |
| RCU stall, 10:30:49 (slow, ~50 s) | **had it** | lost the tail (NULs) | nothing |
| sysrq, 14:13:01 (instant) | **nothing** (`-b -1`: 0 panic lines) | nothing | **had it** |

So it is not "pstore is unreliable" — it is **which panic**. A panic that takes
tens of seconds gives journald time to flush; a panic that goes from sysrq to
reboot in 15 s does not, and only the RAM-resident recorder catches it.

**The caveat that still matters:** the stall panic at 10:30:49 wrote nothing to
pstore, and this test does not explain that. The most likely reason is
mechanical — the dump runs on a CPU that has to take locks, and our fault is a CPU
wedged holding them, so the write may not complete. That is a hypothesis, not a
finding, and it means **pstore's usefulness for the real failure is still
unproven even though its plumbing is now proved.** Do not assume the next stall
panic will leave a record.

**Revised read order after a reset:** pstore first (it is the only source that has
ever captured a panic nothing else got), then `journalctl -b -1` (best for slow
panics), then the tee (run-up only), then the watcher (how long it was down).

**Why this order can never be simplified back to one source.** Which sink catches a
panic depends on **how long the panic takes to reach the reboot**:

- A **fast** panic (sysrq, or any panic that goes to reboot in ~15 s) gives
  journald no time to flush its buffer. Measured 14:13:01: journald had **zero**
  panic lines, the tee had none, pstore had the whole stack.
- A **slow** panic (an RCU stall that runs tens of seconds) gives journald time to
  write, and may leave pstore nothing — either because the dump could not complete
  against a wedged CPU, or for reasons not yet known.

So each source is blind to the other's case. Anyone who "tidies" this to a single
path stops seeing one whole class of death, and will not notice, because the
report still looks complete — it just quietly has nothing in it. That is the same
failure shape as the guard log read clean across midnight.

Pre-test state captured at 11:07 so the test can run the moment it goes quiet:

```text
boot_id           76a0c0764f7743c5b40d3f5ae105074f
uptime            30 min, since 10:32:55
wifi-only from   2026-11-01 10:32:58   (eth0 DOWN)
guard deployed   40bea58576824c49f898dfe25ad84d73
cmdline.txt      console=serial0,115200 console=tty1 root=PARTUUID=4c26bfdf-02
                 rootfstype=ext4 fsck.repair=yes rootwait
                 cfg80211.ieee80211_regdom=AU ds=nocloud;... panic=15
kernel.panic     15          kernel.panic_on_rcu_stall  1
ramoops          using 0x10000@0xb000000, ecc: 0 (config.txt has ramoops-pi5)
pstore           /sys/fs/pstore empty, /var/lib/systemd/pstore empty
```

`panic=15` and `dtoverlay=ramoops-pi5` are both confirmed still in place, so a
result will be meaningful.

**After the crash: read `/sys/fs/pstore` *and* `/var/lib/systemd/pstore`
immediately.** `systemd-pstore` runs early in boot and moves any record out of
`/sys/fs/pstore`, so by the time an ssh session exists the file may already have
moved — checking only `/sys/fs/pstore` would produce a false "no record".

### The run, as one sequence — do not improvise it

Written out because the two things that go wrong under time pressure are already
known: reading only `/sys/fs/pstore`, and treating the dropped ssh as a failure.

**0. Prove the test is meaningful before triggering it.** Abort if any line is
missing:

```bash copy Copy 0. pre-flight (abort on anything missing)
ssh tom 'grep -o "panic=[0-9]*" /boot/firmware/cmdline.txt; \
         cat /proc/sys/kernel/panic; cat /proc/sys/kernel/panic_on_rcu_stall; \
         sudo dmesg | grep "ramoops:"'
```

Expect `panic=15`, `15`, `1`, `ramoops: using 0x10000@0xb000000, ecc: 0`.

**0b. The quiet gate — check it immediately before triggering, and every time.**
This is a gate, not a note. The test is authorised and queued; it runs only when
nobody and nothing else is working on the box. **The same gate applies to any test
that perturbs Tom** — a reboot, a restart of the wifi or camera path, anything that
resets counters — because a second observer or an orphaned poller corrupts the
measurement whether or not it is a person.

There are **three states, not two**, and the third one outranks the test entirely.

```bash copy Copy 0b. quiet gate — run this immediately before step 3
c=$(ssh -o IPQoS=none tom-lan 'journalctl --since "-5 min" --no-pager | grep -c "remote-ip=100.95.54.82"')
u=$(ssh -o IPQoS=none tom-lan 'journalctl --since "-5 min" --no-pager -o cat \
     | grep "starting non-pty command" | grep -o "remote-ip=[0-9.]*" | sort -u \
     | grep -v "remote-ip=100.95.54.82" | tr "\n" " "')
[ -n "$u" ] && { echo "PROVENANCE: unknown tailnet peer(s) in last 5 min:$u"; exit 0; }
[ "$c" -gt 0 ] && { echo "held: other agent active ($c sessions in 5 min)"; exit 0; }
echo "gate open: clear to run"
```

Three outcomes, three different responses:

| outcome | what it means | what to do |
| --- | --- | --- |
| `gate open` | nobody else on the box | run the sequence |
| `held: other agent active` | jason, the known peer, is probing — a scheduling conflict | one line in the report, retry next check, do not ask permission again |
| `PROVENANCE:` | a peer that is **not** `100.95.54.82` | **stop and treat it as a finding, not a delay.** Identify it (`tailscale status`), read what it ran (`--cmd=`), and report it before anything else |

**The fourth check: is the traffic even a person?** Sessions alone do not tell you
whether something worth protecting is running. Before any perturbing test, also
run the orphan check from "How to spot an orphan":

```bash copy Copy 0b-ii. orphan check — is anything still polling Tom?
ps -eo pid,ppid,etime,args | grep -E "watch|poll|probe|capture" | grep -v grep
ls -l /tmp/*.sh 2>/dev/null | tail -5
```

An orphan under `systemd --user` with a growing `/tmp` log produces exactly the
same journal signature as a person, and will hold the gate forever — that cost 15
hours on 2026-11-01. If the count is non-zero, find the source before concluding
"someone is working on it".

The third state exists because an unquiet box that is *not* us is a different kind
of event: an unknown peer on Tom while we are about to reboot it is a security
question, and reporting it as "held: other agent active" would quietly attribute a
stranger's traffic to our own tooling.

**Limitation, stated so it is not mistaken for coverage:** this gate watches
Tailscale SSH only. It is the primary route in, but an sshd login would not appear
in it — if a reset ever correlates with unexplained activity, check `last -n 5` as
well as the journal.

**1. Open a second session you are not using**, so a failed panic still leaves a
way in: `ssh tom 'sleep 900'` in the background. Be honest about its limit — it
travels the same wlan0 the panic may disturb, so it protects against a wedged
panic, not against wifi failing to return.

**2. Note the boot id you are leaving.** `ssh tom 'cat /proc/sys/kernel/random/boot_id'`

**3. Trigger.**

```bash copy Copy 3. trigger the panic
ssh tom 'sudo sh -c "echo 1 > /proc/sys/kernel/sysrq; echo c > /proc/sysrq-trigger"'
```

The ssh session **will** drop (`Broken pipe`, exit 255). **That is success, not
failure** — the box is panicking.

**4. Wait for the new boot.** It is not instant: `panic=15` waits 15 s, then a cold
boot lands in ~30 s, and wlan0 may come up **without an IPv4 lease** — in which
case `wifi-guard` fixes it ~2 min in. Allow 4 minutes before calling it stuck.

```bash copy Copy 4. wait for the new boot id
for i in $(seq 1 48); do sleep 5; \
  id=$(ssh -o ConnectTimeout=4 -o IPQoS=none tom-lan 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null) \
  && [ "$id" != "<OLD_ID>" ] && { echo "new boot: $id"; break; }; done
```

**5. Read pstore before anything else, both locations.** This is the step that
gets forgotten, and the one that decides the answer:

```bash copy Copy 5. the actual measurement
ssh tom 'sudo ls -la /sys/fs/pstore/ /var/lib/systemd/pstore/; \
         sudo cat /sys/fs/pstore/* 2>/dev/null | head -40; \
         sudo cat /var/lib/systemd/pstore/*/* 2>/dev/null | head -40'
```

**6. Archive immediately if anything exists** — the next panic wipes the record,
and `systemd-pstore` may clear it. **Copy it off Tom first: `/tmp` on the box does
not survive a reboot**, and the 2 Nov capture was lost from Tom that way (the jason
copy is the only one left).

```bash copy Copy 6. archive the record
ssh tom 'sudo tar czf /tmp/pstore-$(date +%H%M).tgz /sys/fs/pstore /var/lib/systemd/pstore'
scp -o IPQoS=none tom:/tmp/pstore-*.tgz .amp/in/artifacts/
```

**7. Read the panic in the previous boot's journal**, confirming it was our sysrq
and not a spontaneous reset:

```bash copy Copy 7. the panic itself
ssh tom 'journalctl -b -1 --no-pager | tail -30'
```

**8. Clear the record** so the next boot's "is pstore non-empty" check means
something, and say in the report that you cleared it.

### The discriminator

- **A record present** → the panic path works end to end. **Observed 2026-11-01
  14:13: record present, 27248 bytes.** Plumbing proved.
- **No record with a clean panic** → the region does not survive on this board, and
  pstore is dead weight that should be removed from the monitoring story.

The remaining question is narrower than it was, and worth stating precisely: the
plumbing works, but the *stall* panic at 10:30:49 still produced nothing, so
pstore's usefulness for the actual fault is unproven. Do not treat "pstore empty"
as evidence either way until a stall panic leaves a record or is explained.

## Standing consequence: Tailscale SSH leaves almost no session trail

Not a footnote — it has already cost time. Because `Host tom` is Tailscale SSH
rather than sshd, sessions appear in Tom's journal as `tailscaled` /
`ssh-session(sess-...)` and **do not appear in `who`, `last`, or `auth.log`** with
their source. Attributing the eight sessions that bracketed the 10:30 resets took
extracting `--remote-ip=` and `--remote-user=` from the `starting non-pty command`
lines.

**Where to look:** `journalctl -b <n> | grep "starting non-pty command"` and read
`--remote-ip=` (the peer's tailnet IP — map it with `tailscale status`) and
`--cmd=` (what it actually ran). `who` will show only real sshd sessions, so an
empty `who` does **not** mean nobody was on the box.

### Correction 2026-11-01 14:05: the "second agent" was an orphaned watcher

The sessions attributed above to "another agent on jason" are, on the evidence,
a **leftover monitoring loop**, not a live investigation:

```text
PID 2527375, parent systemd --user (2269) — no agent session above it
started 23:05:07 on 2026-10-31, ran 15 hours, one ssh every ~6 s
script  /tmp/cablewatch.sh   log /tmp/cablewatch.log (8827 lines, 573 KB, still growing)
```

Its sibling `/tmp/remount-on-cable-pull.sh` did the cable-pull remount and
**exited at 01:15:49** ("remount verified on Wi-Fi"). Only the watcher was left
behind, and it is what the crash-test quiet gate has been reading as "other agent
active". So the gate has been holding against a process nobody is reading —
a false positive that would have held the pstore test indefinitely.

**What the watcher recorded, because it turns out to be useful** — an independent
6-second record of the NFS read path in `/mnt/storage/media`, which the trace
sampler could not give us:

| time | last sample before the reset |
| --- | --- |
| 07:07:41 (reset 07:07:42) | `read=OK:9ms` — **1 s before the reset, the NFS read was healthy** |
| 10:30:28 then 10:30:35 (reset 10:30:49) | `read=OK:43ms` (a 4× blip), then `OK:11ms` |
| 10:32:06–10:32:27 (reset 10:32:26) | `read=STALL` four times, ~20 s before that boot died |
| 01:13:02–01:13:42 (the unplug) | `read=STALL` five times — expected, that is the remount window |

Across 8827 samples there are **30 STALLs and 142 `ssh_failed`**, and all of them
cluster at the unplug, the resets, and the 84-second boot's run-up. Between them,
read latency is 4–12 ms for 15 hours straight.

**The NFS hypothesis is now a closed negative, not a weakened one.** For the
07:07:42 reset the last read before death was `read=OK:9ms` at 07:07:41 — the NFS
path was working one second before the box died. Across 15 hours the read path sat
at 4–12 ms with only 30 STALLs in 8827 samples, and every one of them clusters at
the unplug, the resets, or the 84-second boot's run-up. The 10:32:06–10:32:27
STALLs come *after* that boot was already degraded, which makes them a symptom —
the same shape as the camera/i2c messages. **NFS is not the trigger. Do not
reopen this without a sample showing a stalled read *preceding* a death.**

**Attribution, corrected and then closed.** The earlier finding in this ticket said
"eight tailscale ssh sessions bracketed both resets, not from this thread", and
implied an unknown observer. Two separate sources have now been identified, and
neither is an unknown actor:

1. **The orphaned watcher** (`/tmp/cablewatch.sh`, PID 2527375) — 8690 of the
   recorded commands across all boots, one every ~6 s. That is the entire
   49-sessions-per-5-minutes figure. Not a person.
2. **A petcam session from jason** — the `python3 - <<'EOF'` heredoc, 7 occurrences
   at `10:28:32`, `10:29:10`, `10:29:21`, `10:32:26`, `11:18:08`, `12:25:54`,
   `12:27:52`. All `--remote-ip=100.95.54.82` (jason), `--remote-user=andrew.hale003@gmail.com`,
   uid 1000. Contents are petcam work, captured in the journal:
   `cp ~/petcam/model/yolov8n.onnx.bak /tmp/bak.onnx && python3 - <<'EOF'` (model
   comparison), `curl -H "Host: petcam.andrewahale.com" .../review/list >
   /tmp/revlist.json; python3 - <<EOF` (review queue), and the "bak 2-class
   opinion" label audit. Matching rsync of `~/petcam/training/` in the same hours.
   **Nothing since 12:27:52 — zero in any recent hour.**

So the provenance section must not be read as "an unidentified observer was on the
box". Both sources are accounted for, both are on jason, both are ours in origin,
and the petcam one is the retrain workflow rather than anything sinister. The
10:32:26 heredoc began 39 ms before that boot died, but the boot's NFS reads had
been stalling since 10:32:06 — it was a bystander in a boot already failing.

**How to spot an orphan like this, before attributing traffic to a person:**

1. `ps -eo pid,ppid,etime,args | grep -E "cablewatch|watch|poll"` — look for the script name, not just the protocol.
2. **Check the parent.** `PPID 2269 = systemd --user` means nothing started it this session; there is no agent or shell above it. A live investigation has a live parent.
3. **Look in `/tmp`.** Ad-hoc scripts written by an agent land there and outlive the session that wrote them.
4. **Check whether the log is still growing:** `ls -l <log>` twice, 10 s apart. If it grows and nobody is reading it, it is an orphan.
5. **Check for a finished sibling.** `remount-on-cable-pull.sh` had already exited at 01:15:49 — when one script of a pair is done, the other is usually leftover.

An orphaned 6-second NFS poller is not a neutral observer: it puts a read on the
exact subsystem under investigation every 6 seconds. Check for one before blaming
a person for traffic, and before running any timing-sensitive test.

**The rule that follows, which is the point:** *any audit of Tom starts from the
journal, not from login records.* `who`, `last`, and `auth.log` are not evidence
of absence on this box — they are evidence about sshd only, and the primary route
in bypasses sshd entirely. So "nobody was logged in when it reset" is not a
finding anyone can make from `who`; it is a conclusion that has to come from the
journal, or not be drawn at all.

Any future "who was on Tom when it reset" question starts there.

## Every reset takes Jellyfin down (2026-11-01, found when the owner noticed)

Not a separate bug — a consequence of a hard reset, and it took roughly four hours
to be noticed because nothing alerts on it.

**Mechanism**, verified at both boots since the resets:

```text
boot → wlan0 has no IPv4 yet (the guard has not recovered it)
     → mount.nfs /mnt/storage fails: "Network is unreachable for 192.168.1.181"
     → jellyfin.service has RequiresMountsFor=/mnt/storage
     → start job fails as a *dependency* failure, so jellyfin never runs
     → the mount succeeds a minute later once wifi has an address
     → nothing retries jellyfin: it stays down until someone starts it
```

Evidence:

| boot | mount attempted | result | jellyfin |
| --- | --- | --- | --- |
| `b63e886a`-successor (10:32:58) | 10:34:01 | failed | `Dependency failed`, never started — down from 10:34 |
| `67e59294` (14:13:27) | 14:14:01.783 | `Network is unreachable` | `Dependency failed` at 14:14:01 |

On the 14:13 boot the mount attempt at `14:14:01.783` came 25 ms after the guard's
`nmcli` profile restart at `14:14:01.758` — but the restart was not the cause: wlan0
had no IPv4 before it, which is why the guard fired at all.

**The dependency is deliberate**, from
`/etc/systemd/system/jellyfin.service.d/10-wait-for-storage.conf`:

```ini
[Unit]
# Do not start Jellyfin until /mnt/storage (NFS from jason) is mounted,
# otherwise the library scans to empty.
RequiresMountsFor=/mnt/storage
After=mnt-storage.mount
```

and `/etc/fstab` already has `nofail,_netdev`. So the ordering is right but the
**retry** is missing: `nofail` stops the boot failing, it does not make anything
come back afterwards.

**Recovery used on 2026-11-01:** `sudo systemctl start jellyfin` once the mount was
up. Confirmed listening on `:8096`, and reachable through the tunnel —
`https://jellyfin.andrewahale.com` → `HTTP 302` → `location: jf/web/`. The tunnel
itself was never down; its log was full of "Unable to reach the origin service",
which was Jellyfin, not Cloudflare.

**Fix applied 2026-11-01 14:36 — option 1, a cron retry.** Added to tom's crontab,
with the previous crontab kept at `/home/tom/crontab.backup.20261101-143540`:

```cron
# Jellyfin comes back after a reset. The NFS mount can fail at boot while wlan0 has
# no IPv4 yet, which makes jellyfin's RequiresMountsFor a dependency failure that
# nothing retries. Retry for 6 min, and only start it once the mount is really there.
@reboot for i in $(seq 1 12); do sleep 30; findmnt -n /mnt/storage >/dev/null 2>&1 && ! systemctl is-active --quiet jellyfin && sudo -n systemctl start jellyfin; systemctl is-active --quiet jellyfin && break; done
```

Design notes, so a later reader does not "simplify" it wrongly:

- **The `findmnt` guard is load-bearing.** Starting Jellyfin before the mount exists
  is the exact failure the `RequiresMountsFor` drop-in was written to prevent — it
  would scan the library to empty. So the retry waits for the mount, not for a
  timer.
- **Twelve 30-second attempts**, not one shot at 120 s, because the guard's wifi
  recovery is not on a fixed schedule: it fires on its own 2-minute cron and takes
  ~25 s once it does. A single attempt would miss whenever recovery ran late.
- **It is idempotent** — `! systemctl is-active` means a healthy boot does nothing
  but sleep once and exit.

Verified rather than assumed: the crontab diff against the backup is exactly the
four added lines (`15a16,19`), the exact installed line was run with `sleep 30`
substituted for `sleep 1` after `systemctl stop jellyfin` — Jellyfin went
`inactive → active`, listening on `:8096`, `/health` `HTTP 302`, and the public URL
`https://jellyfin.andrewahale.com` returned `HTTP 302` in 0.32 s.

**Still open:** this retries after a *boot*. A reset that does not reboot — a
guard recovery on a running box — is not covered, and neither is the case where the
mount drops mid-run. Whether the guard should also start Jellyfin after it recovers
wifi is an open question for the owner.

The point to keep: **a reset now costs Jellyfin as well as uptime**, and before
this fix that was invisible unless someone tried to watch something.

## 2026-11-02 — three resets, and pstore caught the stall

Found when the owner asked "any restarts?" three times; the hourly thread had been
idle. **The lesson is the same one as everything else today: nothing alerts, so a
quiet report reads as a quiet box.**

| boot | ran | length | how it ended |
| --- | --- | --- | --- |
| `67e59294` | 1 Nov 14:13:27 → 2 Nov 10:23 | **20 h 10 m** | **RCU stall → panic, record captured** |
| `70dbf530` | 2 Nov 10:24:00 → 14:00:05 | 3 h 36 m | silent; died 4 s into a `wifi-guard` run |
| `2b4cc8de` | 2 Nov 14:00:47 → 14:02:26 | **99 s** | silent; died **2 ms after** the guard logged "recovered" |
| `5c1062e4` | 2 Nov 14:02:46 → now | running | — |

### The three-way outcome: record + stall panic

`/var/lib/systemd/pstore/dmesg-ramoops-0`, **27261 bytes**, `Panic#1 Part1`:

```text
[72601.011663] rcu: INFO: rcu_preempt detected stalls on CPUs/tasks:
[72601.011681] Sending NMI from CPU 2 to CPUs 3:
[72611.012142] Sending NMI from CPU 2 to CPUs 0:
[72611.013147] Kernel panic - not syncing: RCU Stall
[72612.181901] SMP: failed to stop secondary CPUs 3
```

**This is the falsifying case: a stall panic, on a wedged CPU 3 that could not even
be stopped, and the dump completed anyway.** So the lock-contention hypothesis — "a
stall panic cannot write pstore because the wedged CPU holds what the dump needs" —
**is falsified**. Note also that the stalled CPU moved: the earlier stalls were all
CPU 3, and this one has NMIs to CPU 3 *and* CPU 0.

Archived before anything else: `/tmp/pstore-capture-1102-1023.tgz` on Tom and
`.amp/in/artifacts/pstore-capture-1102-1023.tgz` on jason
(md5 `d4a3eaddffd7e12479938b1a3ec4c6c2`).

**Then what happened on 1 Nov at 10:30:49, where the same class of panic wrote
nothing?** Unknown, but there is an obvious candidate: **the sysrq test at 14:13 on
1 Nov may have been the priming write.** Every panic before it produced nothing;
every panic after it has produced a record. pstore zones initialise on first use, so
a freshly enabled `dtoverlay=ramoops-pi5` may simply not write until one successful
dump has initialised them. **Hypothesis, not finding** — the way to test it is to
disable and re-enable ramoops on a spare board, which we do not have.

### New lead: the wifi profile restart on a *young* boot

Two of these deaths land on a `wifi-guard` recovery, and both were boots younger
than 110 s:

| recovery | boot age at the time | outcome |
| --- | --- | --- |
| 1 Nov 10:32:26.407 | 84 s | **died same second** |
| 2 Nov 14:02:26.469 | 99 s | **died 2 ms later** |
| 1 Nov 10:34:26.384 | ~2 min 26 s | survived |
| 1 Nov 14:14:26.368 | ~2 min | survived |
| 2 Nov 14:04:27.136 | ~1 min 41 s | survived |

And the 14:00:05 death is a third shape: the guard *started* at 14:00:01.863 and the
box died 4 s later, before it logged anything — i.e. during the probe phase, not at
the restart.

So the correlation is sharper than "the profile restart is a suspect": **a recovery
that runs within roughly the first two minutes of a boot coincides with death
(2 of 2), while the same recovery on an older boot survives (3 of 3).** That points
at a freshly-booted wifi stack — driver or firmware not yet settled — rather than at
`nmcli` itself. Still a correlation across 5 events; do not treat it as causal.

**What this means for the guard:** do not "fix" it by making the restart softer yet.
The next step is to record, on every guard firing, the boot age, so the 2-of-2
becomes a real number rather than a small table in a ticket.

## 2026-11-03 — another silent reset, and the solution question

Boot `5c1062e4` ran 2 Nov 14:02:46 → **3 Nov 14:29:02** (24 h 26 m) and died
silently: no stall, no panic, **no pstore record** (the 27261-byte file left in
`/var/lib/systemd/pstore` is still the 2 Nov 10:23 one — see the note below).

> **Process failure worth keeping:** that 2 Nov record was archived but never
> cleared, so a later check cannot tell a stale record from a new one. The ticket
> already said clear it after archiving; it was not done. Clear it, every time.

**No `wifi-guard` activity in the 55 minutes before the 2 Nov 10:23 stall**, which
weakens the "guard reload causes the wedge" idea for the big one — the young-boot
correlation stays a lead, not a cause.

### Is there a solution? Honest answer: not a fix, but a decision

**The fault is in the Broadcom BCM43455 SDIO path, and it is not ours to fix in
userspace.** Upstream reports match Tom's signature closely:

- `raspberrypi/linux#7528` — Pi 5 client-mode wifi failures on kernel 6.18.39, same firmware family.
- `openwrt/openwrt#23069` — BCM43455 on Pi 5 enters an unrecoverable state after repeated wifi reloads; **only a power cycle recovers**.
- `raspberrypi/linux#6270` — `brcmf_proto_bcdc_query_dcmd ... -110` followed by `rcu_preempt detected stalls`, which is Tom's original scan-wedge shape.
- Ubuntu `#2133877` — Pi 5 network hang with RCU stalls; the governor workaround is already rejected in this ticket.

**There is no update to take.** Installed kernel `6.18.50-1+rpt1` *equals* the
candidate; `firmware-brcm80211` is `1:20260519`. "Patch and hope" is not available.

So the levers are:

| lever | state | value |
| --- | --- | --- |
| `panic_on_rcu_stall=1` | on | turns stall deaths into ~20 s reboots **with a trace**; roughly half the deaths still bypass it |
| `pstore`/ramoops | working since 1 Nov | the only sink that catches a fast or wedged panic |
| services self-heal | Jellyfin cron added 1 Nov, proved 2 Nov | a reset now costs ~3 min of Jellyfin, not hours |
| wifi power save | already `disable` | not a lever |
| guard reload avoidance | young-boot lead only | do not change the guard on this evidence |
| `brcmfmac feature_disable=0x82000` | **not tried** | documented workaround for brcmfmac problems, cheap, reversible, needs a reboot |
| **put the ethernet cable back** | **not done** | removes the whole wifi driver path from the equation — the highest-information single action |

**Recommendation.** The resets are ~1–3 per day and survive every software
mitigation we can apply, so the question is no longer "how do we fix the driver" but
"do we keep running the box on a wifi stack that wedges". Reconnecting ethernet is
the one action that both reduces exposure and tests the hypothesis: if resets stop,
the fault is wifi-side and the box is stable on wire; if they continue, it is the
board or its power, and that becomes a hardware decision (PSU swap, then RMA) rather
than more software.

Caveat to state honestly: resets also occurred on 31 Oct while the cable was in, so
wired is not proven to be immune — but that evening was full of deliberate reboots
during deployment, and the only genuinely quiet window (31 Oct 19:30 → 1 Nov 07:07)
was an 11 h 36 m run on wire that ended in a reset anyway. So the wire test is
informative but not guaranteed.

## Deliberately not doing

- **No flap escalation for `wifi-guard`.** The `≥3 reloads in 30 min` condition
  never occurred (max 2 reloads in 2 min), and the trigger it guarded against
  no longer exists. See the closure doc.
- **Not recommending the `cpufreq` governor workaround.** It circulates as a fix
  for Pi 5 RCU stalls, but the split test in Launchpad #2133877 showed
  `performance` did *not* stop the Pi 5 hang — only `tso off sg off` did, and
  that is an ethernet-offload bug that cannot apply here (Tom has no ethernet).
