# Tailnet auth on headless boxes: disable key expiry, accept SSH (2026-11-07)

**Decision:** both always-on, headless machines (`tom`, `ralph`) get **node key
expiry disabled** and are reached over **Tailscale SSH without a check prompt**.
Laptops/phones keep default expiry and their check.

## Why

Two separate clocks were going to lock us out of machines that have no keyboard
in normal use:

| Clock | Default | Where it bites |
|---|---|---|
| Node key expiry | **180 days** (`MAX` is also 180) | Node drops off the tailnet and needs interactive re-auth **on the machine** |
| Tailscale SSH `checkPeriod` | **12h** (`action: "check"`) | Every terminal re-auth by clicking a URL — this is the "Tailscale SSH requires an additional check" link seen on 2026-11-07 |

Measured on 2026-11-07 (`tailscale status --json`):

- `tom` key expiry **2027-01-14T05:26Z** — Tom is headless, has no monitor and
  a documented history of unexplained resets; losing it from the tailnet means
  no remote path at all (cloudflared only carries HTTP).
- `ralph` key expiry **2027-05-06T06:48Z** — the LUKS prompt already needs a
  keyboard at the console; needing one *and* an interactive Tailscale login
  doubles the failure.

## What to do (admin console, both machines)

1. **Machines → `ralph` → ⋯ → Disable key expiry.** Same for `tom`.
   Lasts indefinitely; it is one click each, and it is the only way (there is
   no `tailscale` CLI for it — the API `Update device key` method exists if this
   ever needs scripting).
2. **ACL `ssh` rule → `action: "accept"`** instead of `"check"`, so no
   12-hourly prompt. Tailnet membership is already the boundary; the check was
   only ever an anti-stolen-laptop speed bump, and neither of these two has a
   screen.

   ```json
   "ssh": [
     { "action": "accept",
       "src": ["autogroup:member"],
       "dst": ["autogroup:self"],
       "users": ["autogroup:nonroot", "root"] }
   ]
   ```

   If a periodic nudge is ever wanted, use `"checkPeriod": "168h"` (max) rather
   than the default 12h. `checkPeriod: "always"` exists and is the opposite of
   what we want.

## Not automated, on purpose

Nothing should script clicking a check URL — that defeats the point and hides a
lockout. The lazy fix is not a cron job, it is deleting the check from the ACL
and removing the expiry from the two machines.

Do **not** disable expiry on `jason`, `rose` or `iphone-11`: they come back to
the tailnet trivially and expiry is the only thing that retires a lost device.

## Rollback

Re-enable key expiry from the same ⋯ menu; restore `"action": "check"` in the
ACL. No state is stored locally, so both are console-only changes — the one
thing in this homelab you cannot fix from a shell.
