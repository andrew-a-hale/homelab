# TODO

## Home Lab

- [ ] Investigate usenet instead of torrents
- [ ] Guest SSID
- [x] Node key expiry disabled for `ralph` and `tom` — both headless, so an expiring key would have dropped the box off the tailnet with no browser to re-auth. Verified 2026-11-08: `tailscale status --json` → `KeyExpiry: None` for both. jason, rose and iphone-11 keep the default expiry (they have browsers). The ACL/Tailscale-SSH half was done the same day: no `ssh` rule, `RunSSH` false on both hosts (`docs/security/complete/tailnet-key-only-and-narrow-policy-2026-11-08.md`). Tom is **not** leaving the tailnet — deprioritised on purpose.

## Purchases

- [ ] Google TV Streamer or Nvidia Shield
- [ ] Ethernet Powerline for TV
- [ ] Smart blub + Lamp: https://www.smarthome.com.au/product/shelly-multicolor-wi-fi-bulb-gen3-e27/

## Trades

- [ ] Electrician: move the internet port + Power and Ethernet

