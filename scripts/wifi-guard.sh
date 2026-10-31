#!/bin/bash
# wifi-guard: keep Tom reachable over wifi, under the NetworkManager+iwd stack.
#
# WHY THIS EXISTS
# ---------------
# Tom's brcmfmac firmware can stop passing traffic while the interface still
# looks associated and still holds its address. When that happened before, the
# visible symptom was wpa_supplicant spamming scan failures for hours and then a
# stuck SDIO command taking out a CPU, so the board rebooted itself. There is no
# ethernet in normal service, so wifi is the only path back in.
#
# TOMBSTONE — the old SCAN-FAILED path (removed 2026-10-31, do not resurrect):
#   The original guard counted wpa_supplicant's own log line, "SCAN-FAILED":
#       fails=$(journalctl -b --since "-2 min" -o cat | grep -c "SCAN-FAILED")
#       [ "$fails" -lt 30 ] && exit 0
#   Tom moved to the iwd backend on 2026-10-29 and wpa_supplicant was masked and
#   stopped. Nothing else ever writes that string, so that branch became
#   unreachable by construction: it could not fire whatever the firmware did.
#   "0 SCAN-FAILED since the migration" therefore never proved the wifi path was
#   healthy, only that the process which complains was not running. It is
#   replaced below by a probe that does not depend on which supplicant is in use.
#
# WHAT IT DOES NOW
# ----------------
# Called every 2 minutes from root's crontab. It decides wifi is dead if either
#   (a) wlan0 holds no IPv4 address, or
#   (b) wlan0 holds an address but reaches *neither* the gateway *nor* an
#       off-LAN address, over wlan0, for two consecutive runs. (b) is the case
#       that matters and the one a supplicant-specific check could never see:
#       link up, address held, traffic dead.
#   Both probes are bound to the interface (-I wlan0) so they test the wifi path
#   even when another interface owns the default route.
#
#   Two targets, because one cannot tell "my wifi is broken" from "the far side
#   is broken", and only one of those justifies touching wifi:
#       gateway up   + off-LAN up   -> healthy
#       gateway up   + off-LAN down -> wifi is fine, upstream is not: LOG ONLY
#       gateway down + off-LAN up   -> wifi works, gateway just ignores us: LOG ONLY
#       gateway down + off-LAN down -> wifi or the whole path is dead: ACT
#   Only the last combination escalates, and only that one can end in a reboot.
#   A blocked or decommissioned off-LAN target degrades to "log only" -- it can
#   never by itself cause a recovery or a reboot. The target is a literal address
#   (1.1.1.1, anycast), never a DNS name, so a resolver failure cannot masquerade
#   as a dead link.
#
# On death it recovers in two tiers, then defers a reboot decision:
#   1. Restart the wifi profile through nmcli. This is the mechanism actually
#      observed working on this box under iwd (2026-10-31 22:52, reconnect
#      succeeded), it costs a few seconds, and it does not touch the kernel.
#   2. Reload brcmfmac. A firmware wedge survives an L2 reassociation, and a
#      driver reload is the only thing known to clear it. Under iwd this means
#      stopping NetworkManager *and* iwd first (no wpa_supplicant anywhere),
#      unloading brcmfmac_cyw+brcmfmac, reloading, then starting iwd and NM.
#   3. If the link is still not working, hand off to `check` after 150 s. `check`
#      reboots ONLY if wifi is still dead *and* nothing else is carrying a
#      default route. That suppression is the fix for a latent bug in the old
#      version, whose check mode rebooted even when a wired uplink was fine.
#
# TESTING (no wedge required)
# ---------------------------
#   ./wifi-guard.sh --dry-run              print what it would do, change nothing
#   WIFI_GUARD_FAKE=no-ipv4  ... --dry-run exercise branch (a)
#   WIFI_GUARD_FAKE=ping-fail ... --dry-run exercise branch (b)
#   WIFI_GUARD_GW=192.0.2.1  ... --dry-run point the gateway probe at an unroutable host
#   WIFI_GUARD_OFF=192.0.2.1 ... --dry-run point only the off-LAN probe at one
#                                          (gateway healthy + off-LAN dead must log,
#                                           not act -- that is the taxonomy test)
#   ./wifi-guard.sh check [--dry-run]      the deferred reboot decision
#
# Cron: */2 * * * * sudo /usr/local/bin/wifi-guard.sh
# History and open work: docs/server/todo/tom-reboots-hang-2026-10-31.md

set -u

IFACE=wlan0
STATE=/run/wifi-guard.pingfail
REFUSE_STATE=/run/wifi-guard.modrefuse
RX_STATE=/run/wifi-guard.rx
LOCK=/run/wifi-guard.lock
REQUIRED_FAILS=2          # consecutive runs before treating the probe as dead
DRY=0
MODE=guard

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY=1 ;;
    check|guard)  MODE="$arg" ;;
  esac
done

FAKE=${WIFI_GUARD_FAKE:-}

# A dry run must NOT write a real-tagged journal line. Test output is
# indistinguishable from a genuine event once it is tagged wifi-guard, and after
# the cable comes out the guard log is the only witness to a link fault, so
# polluting it with test noise can mask the one line that matters.
say() {
  if [ "$DRY" = 1 ]; then
    printf 'DRY: %s\n' "$*"
    return 0
  fi
  logger -t wifi-guard "$*"
}

# Gateway for the wifi interface specifically, falling back to the LAN's usual one.
GW=${WIFI_GUARD_GW:-$(ip route show default dev "$IFACE" 2>/dev/null | awk '{print $3; exit}')}
GW=${GW:-192.168.1.1}
# Off-LAN second target. A literal, never a DNS name: a resolver failure must not
# be able to look like a dead wifi link. 1.1.1.1 is anycast (no single host to
# depend on), answers ICMP, and has been stable for years. Verified reachable
# over wlan0 from Tom before hard-coding it.
OFFLAN=${WIFI_GUARD_OFF:-1.1.1.1}

has_ipv4_real() { ip -4 addr show "$IFACE" 2>/dev/null | grep -q "inet "; }
have_other_uplink() { ip route show default 2>/dev/null | grep -v "dev $IFACE" | grep -q .; }

# Probe the gateway over wlan0 only. -c 3 so one stray dropped packet is not a
# verdict: a single failed attempt was observed on this link while it was fine.
# Both probes bind to the interface, so neither can silently follow eth0 and
# report on the wrong path.
probe_gw() {
  [ "$FAKE" = ping-fail ] && return 1
  ping -c 3 -W 2 -I "$IFACE" "$GW" >/dev/null 2>&1
}
probe_offlan() {
  [ "$FAKE" = ping-fail ] && return 1
  ping -c 3 -W 2 -I "$IFACE" "$OFFLAN" >/dev/null 2>&1
}

# What the two probes together mean. Deliberately conservative: only a link that
# cannot reach anything is acted on, because a false positive here reboots a box
# that may be perfectly healthy.
#   gw up   + off up   -> healthy
#   gw up   + off down -> local wifi is fine, the far side is unreachable: log
#                         only. A blocked or changed off-LAN target degrades to
#                         "log only", never to spurious recovery or reboots.
#   gw down + off up   -> wifi demonstrably works (we reached off-LAN over it),
#                         so the gateway is just not answering us: log only.
#   gw down + off down -> wifi or the whole path is dead: this is the only
#                         combination that escalates.
link_state() {
  local gw=down off=down
  probe_gw && gw=up
  probe_offlan && off=up
  case "$gw/$off" in
    up/up)     echo healthy ;;
    up/down)   echo upstream ;;
    down/up)   echo gateway-silent ;;
    down/down) echo dead ;;
  esac
}

# Recovery succeeded if wifi can reach *something* over the interface. Judging it
# by both targets being healthy would report a good recovery as a failure
# whenever the far side happened to be down -- and that false negative is what
# escalates toward a reboot.
link_usable() { has_ipv4 && [ "$(link_state)" != dead ]; }

# The force flags must apply in every mode, including `check`, or the reboot
# suppression cannot be proven without actually breaking the link.
has_ipv4() {
  [ "$FAKE" = no-ipv4 ] && return 1
  has_ipv4_real
}

wifi_profile() {
  nmcli -t -f NAME,TYPE connection show 2>/dev/null |
    awk -F: '$2=="802-11-wireless"{print $1; exit}'
}

fail_count() { cat "$STATE" 2>/dev/null || echo 0; }
set_fail_count() { [ "$DRY" = 1 ] || printf '%s\n' "$1" > "$STATE"; }
clear_fail_count() { [ "$DRY" = 1 ] || rm -f "$STATE"; }

# Both probes failing normally means the link is dead. There is one configuration
# where it does not: if the gateway blocks ICMP *and* the off-LAN target is
# filtered, a perfectly healthy link reads as dead and the guard would act on it.
# That would invert the whole fails-safe design and reboot Tom every few minutes.
# Detecting it properly would need provider-redundant probes, which is not worth
# building for a rare case; instead it announces itself, so it cannot masquerade
# as a fault. Association + carrier + counters still moving is evidence the link
# is passing traffic while both probes claim otherwise.
link_looks_alive() {
  [ -n "${rx_prev:-}" ] || return 1
  [ "${rx_now:-0}" -gt "${rx_prev:-0}" ] || return 1
  [ "$(cat "/sys/class/net/$IFACE/carrier" 2>/dev/null || echo 0)" = 1 ] || return 1
  nmcli -t -f GENERAL.STATE device show "$IFACE" 2>/dev/null | grep -qi connected || return 1
  return 0
}

recover_profile() {
  local con
  con=$(wifi_profile)
  if [ -z "${con:-}" ]; then
    say "no 802-11-wireless NM profile found; cannot restart the profile"
    return 1
  fi
  say "restarting wifi profile '$con' via nmcli"
  if [ "$DRY" = 1 ]; then return 0; fi
  nmcli connection down "$con" >/dev/null 2>&1 || true
  nmcli connection up "$con" >/dev/null 2>&1 || true
  sleep 20
  link_usable
}

# Return: 0 recovered, 1 reloaded but still dead, 2 module refused (still busy).
recover_module() {
  # iwd backend: no wpa_supplicant to start. Stop both owners of wlan0, reload
  # brcmfmac, then bring iwd back before NM (NM talks to iwd over D-Bus).
  say "reloading brcmfmac (stopping NetworkManager and iwd first)"
  if [ "$DRY" = 1 ]; then return 0; fi
  systemctl stop NetworkManager iwd
  if ! modprobe -r brcmfmac_cyw brcmfmac; then
    # Busy here usually means something still holds wlan0, i.e. the stack has
    # not finished tearing down -- a condition that often clears on its own.
    # One retry inside this run, then defer to the next 2-minute run rather than
    # rebooting on a transient.
    say "modprobe -r brcmfmac refused; retrying once after 5s"
    sleep 5
    if ! modprobe -r brcmfmac_cyw brcmfmac; then
      systemctl start iwd NetworkManager
      return 2
    fi
  fi
  modprobe brcmfmac
  modprobe brcmfmac_cyw
  systemctl start iwd
  systemctl start NetworkManager
  sleep 30
  link_usable && return 0
  return 1
}

defer_check() {
  say "wifi still down; deferring the reboot decision to a check in 150s"
  [ "$DRY" = 1 ] && return 0
  systemd-run --collect --on-active=150 --unit="wifi-guard-check-$$" "$0" check >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- check mode --
if [ "$MODE" = check ]; then
  # Verify real connectivity, not just an address: the failure mode we care
  # about is "address held, traffic dead", which an IPv4 test alone would pass.
  st=$(link_state)
  if [ "$st" = healthy ]; then
    say "check: wifi is working again; not rebooting"
    clear_fail_count
    exit 0
  fi
  if [ "$st" != dead ] && has_ipv4; then
    say "check: wifi reaches one of the targets ($st); not rebooting"
    clear_fail_count
    exit 0
  fi
  if have_other_uplink; then
    say "check: wifi still down but another uplink is up; not rebooting"
    clear_fail_count
    exit 0
  fi
  say "check: wifi dead ($st) and no other uplink; rebooting"
  [ "$DRY" = 1 ] && exit 0
  reboot
  exit 1
fi

# ---------------------------------------------------------------- guard mode --
exec 9>"$LOCK"
flock -n 9 || exit 0

rx_now=$(cat "/sys/class/net/$IFACE/statistics/rx_packets" 2>/dev/null || echo 0)
rx_prev=$(cat "$RX_STATE" 2>/dev/null || echo "")
[ "$DRY" = 1 ] || printf '%s\n' "$rx_now" > "$RX_STATE" 2>/dev/null || true

# (a) no address at all
if ! has_ipv4; then
  say "wlan0 has no IPv4 on $IFACE; recovering"
  reason="no-ipv4"
else
  state=$(link_state)
  case "$state" in
    healthy)
      clear_fail_count
      exit 0
      ;;
    upstream)
      say "gateway $GW reachable over $IFACE but $OFFLAN is not; treating as an upstream fault, not acting"
      clear_fail_count
      exit 0
      ;;
    gateway-silent)
      say "gateway $GW silent over $IFACE but $OFFLAN reachable; wifi works, not acting"
      clear_fail_count
      exit 0
      ;;
    dead)
      # (b) address held but wifi reaches nothing -- needs consecutive confirmations
      n=$(fail_count)
      n=$((n + 1))
      set_fail_count "$n"
      if [ "$n" -lt "$REQUIRED_FAILS" ] && [ -z "$FAKE" ]; then
        say "wlan0 reaches neither $GW nor $OFFLAN over $IFACE ($n/$REQUIRED_FAILS); waiting for confirmation"
        exit 0
      fi
      say "wlan0 reaches neither $GW nor $OFFLAN over $IFACE ($n/$REQUIRED_FAILS); recovering"
      if link_looks_alive; then
        say "possible probe blindness: both targets unreachable but $IFACE is associated, carrier is up and it received $((rx_now - rx_prev)) packets since the last run; the probes may be filtered rather than the link being dead"
      fi
      reason="probe-dead-both-targets"
      ;;
  esac
fi

say "wifi dead ($reason)"

# A dry run must show the whole plan, not stop at the first tier it would try:
# stopping early reads as "recovered" when nothing was attempted.
if [ "$DRY" = 1 ]; then
  say "PLAN: restart wifi profile '$(wifi_profile)' via nmcli, then re-test"
  say "PLAN: if still down, reload brcmfmac (stop NetworkManager+iwd, modprobe -r/_r, start iwd+NM), then re-test"
  say "PLAN: if still down, defer a reboot decision to 'check' in 150s"
  say "PLAN: check reboots only if wifi is still dead AND no other uplink has a default route"
  exit 0
fi

# REMOVED: a WIFI_GUARD_RECOVERY knob once allowed skipping these tiers with
# "none", which sent a genuinely dead link straight to a reboot. On a wifi-only
# box that is a reboot Tom may not survive, so the knob is gone rather than
# documented. Recovery always attempted; only the module tier can be skipped, and
# only because another uplink is carrying traffic.
if recover_profile; then
  say "recovered by restarting the wifi profile"
  clear_fail_count
  exit 0
fi
say "profile restart did not restore the link"

# The module reload stops NetworkManager, which also owns eth0 -- with a cable in,
# that turns a wifi fault into a total outage. Never do it while something else is
# carrying traffic; a working uplink means we can wait for a human instead.
if have_other_uplink; then
  say "skipping the disruptive brcmfmac reload: another uplink is carrying traffic"
  defer_check
  exit 0
fi

rc=0
recover_module || rc=$?
if [ "$rc" -eq 0 ]; then
  say "recovered by reloading brcmfmac"
  clear_fail_count
  rm -f "$REFUSE_STATE"
  exit 0
fi
if [ "$rc" -eq 2 ]; then
  # Refused twice. Give it one more cron cycle before escalating, so a module
  # that merely needs another few seconds is not answered with a reboot.
  n=$(cat "$REFUSE_STATE" 2>/dev/null || echo 0)
  n=$((n + 1))
  printf '%s\n' "$n" > "$REFUSE_STATE" 2>/dev/null || true
  if [ "$n" -lt 2 ]; then
    say "brcmfmac still busy; will retry on the next run instead of rebooting"
    exit 0
  fi
  say "brcmfmac refused to unload on $n consecutive runs; escalating the reboot decision"
else
  say "brcmfmac reload did not restore the link"
fi

defer_check
exit 0
