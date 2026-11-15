# Vesktop → official Discord client (2026-11-12)

## What was wrong

Vesktop 1.6.9 (the latest upstream release, 2026-11-05) on Jason could not stream
in either direction: `Stream failed to start :( Error: 2012` when viewing a
friend's Go Live, and no working screenshare. The app was connected —
`discord.com` and `gateway.discord.gg` resolve, the gateway websockets are
established, guild/channels/voice state all render, and CDP showed the
`RTCControlSocket` heartbeat/ACK loop healthy. `MediaCapabilities` reports H.264,
AV1 and VP9 all `supported: true` (software, `powerEfficient: false`). So it was
the client's WebRTC/stream path, not the network, DNS, VPN or the account.

## Decision

Use the official `discord` client from `[extra]` (`1:1.0.169-1`) for Discord, and
retire the `vesktop` AUR package. `SUPER + D` now launches `discord`.

## Why

- Unofficial clients are the one thing that keeps breaking: Vesktop's stream
  path has open issues with Wayland screenshare, and Vencord-on-official-client
  hits the same errors, while the stock client is reported working (it bundles
  its own OpenH264 — its log shows `[MediaEngineStore] OpenH264 is ready`,
  Vesktop's never does).
- No AUR build, no AUR maintenance: `discord` is packaged in `[extra]`.
- Reversal of the 2026-11-11 call in
  [`arch-desktop-spec-2026-11-11.md`](arch-desktop-spec-2026-11-11.md), which
  dropped the official client because "vesktop is independent of it". Independence
  was never the problem; streaming was.

## Files touched

- `config/hypr/binds.lua` — `SUPER + D` → `discord`
- `docs/jason/binds.md` — bind table
- `docs/jason/whitelist.md` — `discord` in the pacman list, `vesktop` dropped
  from the AUR table (now seven AUR packages)

## Left over

`pacman -Rns vesktop` once a stream has been watched and shared from the
official client.
