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
in case": the current file plus the repo copy on `tom-hang-capture` is the
recovery path. If the deployed guard is broken or missing, copy
`scripts/wifi-guard.sh` from that branch to `/usr/local/bin/` — do not reach for a
`bak-*`. The older copies are for understanding history only.

**Deployment is copy-to-`/usr/local/bin`, and nothing else.** Tom's own checkout
at `/home/tom/projects/tom` is a stale clone sitting on `master` and is **neither
authoritative nor current** — its `scripts/wifi-guard.sh` is an old 55-line
version. Do not diff against it or "fix" a mismatch there; the only comparison
that means anything is repo ↔ `/usr/local/bin/wifi-guard.sh`.

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
`tom-hang-capture` and **installed**: `/usr/local/bin/wifi-guard.sh` and
`scripts/wifi-guard.sh` are both `fd7ff77d…`, tom's crontab still runs it every
2 minutes, and the previous copy is kept at
`/usr/local/bin/wifi-guard.sh.bak-20261031` for rollback.

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

**Reporting precedence once the cable is out: if the guard logs anything at all,
that is the headline of the check — ahead of uptime.** A guard line means it
decided something about a link the owner can no longer reach around, so it
outranks the usual lead fields rather than being appended to them.

Once eth0 drops, "is Tom up" stops being the interesting question; **"did it
survive the change"** is. A reboot within minutes of the unplug is a *different
event* from the silent hourly resets this ticket is about, and must be reported as
such — correlate the boot with the eth0-gone timestamp and say plainly that the
reboot followed the cable removal, rather than reporting a boot count as if it
were the usual unexplained reset. Conflating the two would either manufacture a
regression or hide one.

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

## Deliberately not doing

- **No flap escalation for `wifi-guard`.** The `≥3 reloads in 30 min` condition
  never occurred (max 2 reloads in 2 min), and the trigger it guarded against
  no longer exists. See the closure doc.
- **Not recommending the `cpufreq` governor workaround.** It circulates as a fix
  for Pi 5 RCU stalls, but the split test in Launchpad #2133877 showed
  `performance` did *not* stop the Pi 5 hang — only `tso off sg off` did, and
  that is an ethernet-offload bug that cannot apply here (Tom has no ethernet).
