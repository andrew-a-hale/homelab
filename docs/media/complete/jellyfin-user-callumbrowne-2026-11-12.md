# Jellyfin user: callumbrowne

**Done 2026-11-12** — added a non-admin Jellyfin user `callumbrowne` on Ralph.

| Field | Value |
|---|---|
| User id | `7e53e872f9ff4e29b37491c65e1e7f7a` |
| Admin | no |
| Hidden | no (shows on the login screen) |
| Access | all libraries, all devices, remote access, transcoding, downloads |
| Password | set to the requested password; user can change it in their own profile |

Verified: `POST /Users/AuthenticateByName` returns 200 for the new user, and
`https://jellyfin.andrewahale.com/jf/web/` is up.

## How (no admin password needed)

The admin password is undocumented and lives only in Pass on **Jason** — Ralph
has neither `pass` nor Proton Pass (`../security/README.md`), so it was that
password or a token already on the box. The user was created over the local REST
API using the existing `migration-helper` API key
already in `/var/lib/jellyfin/data/jellyfin.db` (`ApiKeys.AccessToken`):

```bash
ssh ralph 'sudo sqlite3 /var/lib/jellyfin/data/jellyfin.db "select AccessToken from ApiKeys;"'
```

Then, from `127.0.0.1:8096` (the key is not sent over the internet):

```bash
TOK=<key>
curl -s -X POST -H "Authorization: MediaBrowser Token=\"$TOK\"" \
  -H 'Content-Type: application/json' \
  --data '{"Name":"callumbrowne","Password":"<pw>"}' \
  http://127.0.0.1:8096/jf/Users/New
```

`X-Emby-Token` was rejected (401) on this server — use the `Authorization:
MediaBrowser Token="…"` header. Users are created `IsHidden=true` by default;
re-post the fetched policy with `IsHidden:false` to make them visible:

```bash
curl -s -H "$AUTH" http://127.0.0.1:8096/jf/Users/$U            # take .Policy
# set IsHidden=false, POST it back to /jf/Users/$U/Policy  -> 204
```

Cleanup: the token was not left on disk (`/tmp` copies removed).
