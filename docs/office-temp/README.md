# Office temp & humidity (DHT12)

An ESP8266 (Wemos D1 mini) + DHT12 on a USB-serial adapter, read by **Ralph**,
published at `https://andrewahale.com/static/dht.json`. Verified 2026-11-08:
`/dev/ttyUSB0` present, `/srv/dht/dht.json` updated seconds ago, live over HTTPS.

## Shape

```
D1 mini (DHT12, I2C) ──micro-USB/CH340──▶ Ralph /dev/ttyUSB0
   firmware prints "25.0 C  24.9 %" 10×/s
        ▼
/usr/local/bin/dht-writer  ──▶  /srv/dht/dht.json   (atomic mv)
        ▲ dht.service (Restart=always, After=dev-ttyUSB0.device)
        ▼
nginx  location = /static/dht.json  →  alias /srv/dht/dht.json
```

The writer is [`scripts/dht-writer.sh`](../../scripts/dht-writer.sh) — 20 lines
of shell: `stty` the port, `read` lines, `printf` JSON to a temp file, `mv` it
into place so nginx never serves half a document.

## Install (Ralph)

```bash
sudo install -m755 scripts/dht-writer.sh /usr/local/bin/dht-writer
```

`/etc/systemd/system/dht.service`:

```ini
[Unit]
Description=USB DHT sensor -> /srv/dht/dht.json
After=dev-ttyUSB0.device
Requires=dev-ttyUSB0.device

[Service]
ExecStart=/usr/local/bin/dht-writer
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

`sudo systemctl enable --now dht`. The nginx alias is already in
`../ralph/nginx-ralph.conf`.

## Wiring

- DHT12 SDA → D1 mini D2 (GPIO4), SCL → D1 (GPIO5), 3V3 + GND
- D1 mini → USB-serial adapter (CH340) → Ralph

The firmware sketch lives in `scripts/dht/dht_firmware/` and is only needed to
reflash the board (`arduino-cli`); `scripts/dht/` also holds the older C
serial→JSON daemon, which the shell writer replaced.

## Verify

```bash
ssh ralph 'systemctl is-active dht; cat /srv/dht/dht.json'
curl -s https://andrewahale.com/static/dht.json
```

Fresh `date` field = healthy. A stale timestamp means the board is silent or
`/dev/ttyUSB0` renumbered (check `ls -l /dev/ttyUSB*`, then `systemctl restart dht`).

## Ceiling

**Not calibrated.** Ralph's sensor reads ~2.8 °C cooler than the retired Pi
sensor that sat in the same room, and neither was ever checked against a
reference. No offset is applied on purpose (`RUNBOOK.md`): the number is the
sensor's, not a guess.

History: `complete/dht-restart-2026-10-22.md` (the daemon-died incident).
