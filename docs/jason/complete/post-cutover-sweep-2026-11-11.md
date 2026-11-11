# Post-cutover sweep: disks, fallback kernel, mise — 2026-11-11

Follow-up to [`left-omarchy-2026-11-11.md`](left-omarchy-2026-11-11.md). Four
loose ends from the cutover, all closed the same night. Every destructive step
was preceded by a copy; every claim below was checked on the box, not assumed.

## 1. `/mnt/storage` and `/mnt/games` are ext4 now

The decision to wipe both NTFS volumes to ext4 was recorded during the migration
but never executed. Done now, with the one piece of data that mattered carried
across:

```sh
rsync -a /mnt/storage/backup/ ~/backup-staging/      # 434,562,628 B, diff -r clean
sudo umount /mnt/storage /mnt/games
sudo cp /etc/fstab /etc/fstab.bak-2026-11-11
sudo mkfs.ext4 -q -L storage -m 1 /dev/sda1          # 1.8T
sudo mkfs.ext4 -q -L games   -m 1 /dev/nvme1n1p2     # 229G
```

`fstab` UUIDs swapped for the new filesystems (`ntfs` / `ntfs-3g` entries →
`ext4 defaults,noatime 0 2`), `mount -a` clean, then `backup/` restored and
verified identical. Mount points are chowned to `andy`, which they were not
before (`/mnt/storage` used to be `root:root` because the NTFS mount was).

`-m 1` reserves 1% instead of the default 5% — ~90G handed back on the 1.8T
volume for a filesystem that is not `/`.

**Gone with the wipe:** `World of Warcraft` + `WowUp-2.22.0.AppImage` (7.4G on
`/mnt/games`). That was the agreed outcome — WoW was the only thing on either
disk and the migration record already had it leaving.

`protondrive-weekly.sh` needed no change: it reads `/mnt/storage/backup`, which
exists again with the same contents.

## 2. Fallback kernel dropped; snapshot boot entries now exist

Stock `linux` had booted fine, so:

```sh
sudo pacman -Rns linux-omarchy linux-omarchy-headers
```

`limine-entry-tool` removed the `linux-omarchy` entry and re-signed everything by
itself. `/boot` went 540M → 269M (53% → 27%). One harmless error at the end of
the transaction — `failed signing /boot/vmlinuz-linux: does not exist` — because
this setup boots UKIs (`/boot/EFI/Linux/omarchy_linux.efi`) and there is no
monolithic `vmlinuz` to sign. The UKI itself signed fine.

Then the snapshot entries, which had **never** worked. Two independent causes:

1. `/etc/default/limine` sets `LIMIT_USAGE_PERCENT=50` — not our
   `/etc/limine-entry-tool.d/zz-jason.conf`. A key in the `d/` directory does not
   override that file; the watcher reads `/etc/default/limine` and prints the
   limit from there.
2. Each snapshot entry is a **full copy of the UKI** — 267 MiB. Even with one
   kernel, 26% + 26% = 52% > 50%, so it still refused:
   `Boot partition usage from 26.3% to 52.4% (+267.4 MiB) will exceed the 50.0% limit`.

So the limit was raised to 70 and the cap set to one entry — a 1 GiB `/boot`
holds the live UKI plus exactly one snapshot copy, and two would not fit:

```
/etc/default/limine            LIMIT_USAGE_PERCENT=70
zz-jason.conf                  MAX_SNAPSHOT_ENTRIES=1
```

Verified by creating a snapshot and watching the watcher copy the UKI:

```
Omarchy
├─ linux
└─ Snapshots
   └─ 16 │ 2026-11-11 23:32:36
EFI fallback
```

Snapshot 16 is that test, kept and renamed `post-omarchy-cleanup` — it is the
first point in time that is fully Omarchy-free. `/boot` sits at 53%.

**Ceiling:** one snapshot entry, not six. Raising `MAX_SNAPSHOT_ENTRIES` past 1
does nothing until `/boot` is bigger or the UKI smaller — the watcher will
refuse each additional copy. `snapper` still keeps its normal history; only the
boot-menu entries are capped.

## 3. `mise` is gone

`mise-bin` looked load-bearing because it provided `node`, `uv`, `go`, `zig`,
`julia`, `elixir`, `claude`, `codex`, `gh`. It was not: `/etc/mise/conf.d/` was
owned by the `omarchy` package, and removing Omarchy had already stopped mise
from managing any of those. Checked against a clean login shell — every one of
them resolves to `/usr/bin`, i.e. the pacman package:

```
node npm uv go zig julia elixir ruby gh claude codex amp opencode pi   all /usr/bin/*
mise                                                                   MISSING
```

What actually still ran through mise shims: `claude`, `codex`, and `pi`. All
three are now global npm packages on the system node:

```sh
sudo /usr/bin/node /usr/lib/node_modules/npm/bin/npm-cli.js i -g \
  @anthropic-ai/claude-code@2.1.322 @openai/codex@0.167.1
sudo /usr/bin/node /usr/lib/node_modules/npm/bin/npm-cli.js i -g \
  --ignore-scripts @earendil-works/pi-coding-agent@1.5.2
```

`--allow-scripts=@anthropic-ai/claude-code` was needed once: npm 11 blocks
postinstall scripts by default and Claude Code's `install.cjs` is what fetches
its native binary. Without it the `claude` binary is a stub that prints
instructions. `pi` needs `--ignore-scripts`, per its own README.

`~/projects/pi-config/bin/pi` used to bootstrap itself through mise
(`mise use -g pi` + `mise x pi -- pi`). It now `exec /usr/bin/pi "$@"` — the
absolute path matters, because this script *is* `pi` on `PATH`
(`~/.pi/agent/bin/pi` symlinks to it) and `exec pi` recursed forever.

```sh
sudo pacman -Rns mise-bin
rm -rf ~/.config/mise
```

13G of `~/.local/share/mise` was removed; `installs/pi` is left until the
running session ends, then `rm -rf ~/.local/share/mise` finishes the job.

**Nothing else changed:** `/etc/bashrc`-level `mise activate` was already gone
with the Omarchy `~/.bashrc` header, and no systemd unit or cron job referenced
mise.

## 4. `libva` — not broken

The cutover left `LIBVA_DRIVER_NAME=nvidia` with Firefox logging
`libva error: /usr/lib/dri/nvidia_drv_video.so init failed`. Re-tested with the
current config, both with and without the env vars unset:

```
vainfo → Driver version: VA-API NVDEC driver [direct backend]
         VAProfileH264High : VAEntrypointVLD  (and the rest of NVDEC's list)
```

The driver initialises. The Firefox line was from before the reboot, when
`libva-nvidia-driver` and the session env had just changed under it. Env stays as
is: `NVD_BACKEND=direct`, `LIBVA_DRIVER_NAME=nvidia`,
`__GLX_VENDOR_LIBRARY_NAME=nvidia`.

## State after

| | Before tonight | Now |
|---|---|---|
| Packages | 1220 / 200 explicit | 1219 / 199 |
| Kernel | `linux` + `linux-omarchy` fallback | `linux` only |
| `/boot` | 540M (53%), no snapshot entries | 535M (53%), 1 snapshot entry |
| `/mnt/storage` | NTFS 1.9T, 681M | ext4 1.8T, 416M |
| `/mnt/games` | NTFS 233G, 7.4G (WoW) | ext4 229G, empty |
| mise | 13G of installs | removed |

## Traps worth remembering

- `LIMIT_USAGE_PERCENT` in `/etc/limine-entry-tool.d/*.conf` is **ignored**; that
  one key lives in `/etc/default/limine`. The watcher logs it on every refusal —
  read the log, it names the file's value and the arithmetic.
- Snapshot entries cost a whole UKI copy each. Do not plan snapshot booting on a
  1G `/boot` with 270M UKIs.
- `pacman -Rs` on a kernel package runs `limine-entry-tool` hooks mid-transaction;
  `failed signing /boot/vmlinuz-linux` is expected noise on a UKI-only setup.
- Newly `mkfs`'d mount points are `root:root`. `chown` them (or set them up with
  the right owner) before anything unprivileged writes there.
- `npm -g` with the system node needs an absolute `/usr/bin/node ... npm-cli.js`
  when a second node is earlier on `PATH`; and npm 11 silently blocks postinstall
  scripts, which for `claude-code` is fatal but only visible on first run.
