# Public ingress: Jellyfin reviewed — proxy fix + detection done, edge rules declined (2026-11-08)

**Status:** closed 2026-11-08. `KnownProxies` and fail2ban/detection are running;
**Cloudflare Access, the edge rate-limit rule and the Access notifications were
declined** — one strong password on a media box does not justify losing the native
Jellyfin apps. Fail2ban's limitation is recorded in
`host-hardening-and-detection-2026-11-08.md` → *Ceiling*: a ban at the origin
cannot reach a client that arrives through the tunnel. Source:
`docs/security/README.md`.

## Why

Jellyfin is the only internet-facing authenticated app with no second factor
and no Cloudflare Access in front of it. And because cloudflared connects to
`127.0.0.1:8096` with `KnownProxies` unset in `/etc/jellyfin/network.xml`,
**every internet request looks local** to Jellyfin: no IP is trusted, no real
client address is logged, and any IP-based protection is inert. Admin there
means plugin install = code execution as the `jellyfin` user.

Impact of a guessed admin password: the media library, and a code path to
shell. Not the host — but Ralph is the box RSA keys and the tunnel live on.

## 1. Cloudflare Access in front of `jellyfin.andrewahale.com` — **DECLINED 2026-11-08**

Reason: the native mobile/TV apps cannot complete an Access OTP, and Jellyfin already
has a strong password. The trade was SSO-on-web for broken apps; not worth it.

Copy the Pet Cam app exactly: Zero Trust → Access → Applications → add
self-hosted `jellyfin.andrewahale.com`, policy *just me* (`andrew@andrewahale.com`,
One-time PIN, 24 h).

- Caveat from `docs/website/README.md`: the mobile Jellyfin apps cannot
  complete an Access OTP. Either use a service token for native clients, or
  accept web-only away from home. Decide when you get there — don't leave
  Jellyfin unprotected because the apps are awkward.
- Verify from outside: `curl -sI https://jellyfin.andrewahale.com/ | grep -i location`
  should point at `cloudflareaccess.com`.

## 2. Tell Jellyfin it is behind a proxy — **DONE 2026-11-08**

`KnownProxies` (`127.0.0.1`, `::1`) + `IsRemoteAccessAllowed` are in
`/etc/jellyfin/network.xml`; a probe request carrying
`X-Forwarded-For: 198.51.100.7` is logged with that IP, so internet clients are no
longer recorded as loopback.

```bash
ssh ralph
sudo tee -a /etc/jellyfin/network.xml   # inside <NetworkConfiguration>:
#   <KnownProxies><string>127.0.0.1</string><string>::1</string></KnownProxies>
#   <IsRemoteAccessAllowed>true</IsRemoteAccessAllowed>
sudo systemctl restart jellyfin
```

Then confirm the real client IP shows up in Dashboard → Activity. Without
this, the "remote" security class never applies and login attempts all appear
as `127.0.0.1`.

## 3. Rate-limit the login at the edge — **DECLINED 2026-11-08**

Decided to rely on the password + the `auth/24h` signal in the daily health log.
If spraying ever shows up, the rule below is ready to paste.

This is the **only** effective throttle for internet clients: fail2ban bans happen
at Ralph's packet filter, but tunnelled traffic arrives from `127.0.0.1`, so it
never sees the ban (`../complete/host-hardening-and-detection-2026-11-08.md` →
*Ceiling*). Free plan allows 5 custom WAF rules and **1** rate-limiting rule —
use the rate-limiting one here:

- expression `http.host eq "jellyfin.andrewahale.com" and http.request.method eq "POST" and http.request.uri.path contains "Users/AuthenticateByName"`
- 10 requests / 1 minute per IP → *Managed Challenge* (not *Block*, so a fat-fingered
  password from a shared IP is not a lockout).

A plain WAF custom rule would also work, but the rate-limiting rule gives you the
counter and the challenge without guessing a threshold per address.

## 4. Detection — the "did someone try" half — **DONE 2026-11-08**

fail2ban is running with three jails (`sshd`, `nginx-http-auth`, `jellyfin`) and
`ignoreip` keeps loopback unbanned (cloudflared arrives from `127.0.0.1`; banning
it takes the site down). Bans act on LAN clients only — a tunnelled attacker
comes from loopback, so the jellyfin jail is signal, not prevention (see §3).
`scripts/homelab-health.sh` now reports `auth/24h` on both hosts plus `bt-401` and
`fail2ban` on Ralph. Still open: the Cloudflare notifications (dashboard).

Nothing on Ralph can answer that today: `fail2ban` and `auditd` are both
inactive, and `scripts/homelab-health.sh` only checks that services are up.

Minimum useful set:

- `fail2ban` with jails on the nginx logs (`/var/log/nginx/access.log`, 401s on
  `/bt/` and `/jf/`) and on `sshd` — this is the log that caught 7 failed
  password attempts on Tom in the last 30 days that nobody noticed.
- Cloudflare Zero Trust → Notifications: alert on Access denied spikes and on
  WAF blocks.
- Extend `scripts/homelab-health.sh` with one line type — failed auth count per
  day per host — so the existing daily 08:00 line in `~/homelab-health.log`
  becomes a trend, not just an uptime bit.

## 5. Headers (5 min, optional) — **DECLINED**

The public site returns no `strict-transport-security` and no CSP. Cloudflare
terminates TLS so the practical risk is low; add HSTS in Cloudflare (SSL/TLS →
Edge Certificates) and leave CSP alone until the site's inline JS is known.

## Done when

- Jellyfin is behind Access (or a service-token equivalent) and proves it from
  outside.
- Jellyfin logs show real client IPs.
- A burst of failed logins produces a ban and an alert.
- `~/homelab-health.log` carries a daily failed-auth count.
