# The TV's own DLNA server: rejected (recorded 2026-11-08)

**Decision:** keep playing Jellyfin on the TV through a laptop + HDMI until a
Google TV Streamer or Shield arrives. Do not spend time on the Hisense 65AU6K's
native DLNA client.

## Why

- The TV runs **VIDAA OS** — no Jellyfin or Play Store app, so its only path to
  the library is its native Media app over DLNA.
- Jellyfin's DLNA plugin (14.0.0.0, not built in on Jellyfin 12.x — Dashboard →
  Plugins, then `sudo systemctl restart jellyfin`) **does** discover the TV, but
  the TV refuses to play under the fallback "Generic Device" profile:
  `No matching device profile found`. No VIDAA profile exists upstream.
- The file was vanilla H.264/AAC, so it was never a codec or transcode problem.
  VIDAA + DLNA is a time sink with no endpoint.

## Consequence

The laptop + HDMI workaround stays until the Streamer/Shield purchase
(`TODO.md`), which brings the official Jellyfin app and direct play.
