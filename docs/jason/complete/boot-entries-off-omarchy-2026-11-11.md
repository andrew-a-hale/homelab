# Boot entries no longer depend on Omarchy (Jason), 2026-11-11

Status: **done and verified**, no reboot needed. Snapshot 13 `pre-aur-limine` is
the way back.

## The two packages were never Omarchy's

`limine-mkinitcpio-hook` and `limine-snapper-sync` are upstream GPL3 tools by
Zesko (`gitlab.com/Zesko/limine-entry-tool`, `.../limine-snapper-sync`). The
`[omarchy]` repo only repackaged them — pkgrel `-2` against the AUR's `-1`, same
upstream versions, and the AUR PKGBUILD is maintained by the upstream author.
They appeared Omarchy-only for one mechanical reason: `pacman -Qi` listed
`Required By: omarchy`, so `pacman -Rns omarchy` would have taken both as
orphans. Losing the first one means the next kernel upgrade builds a UKI that no
boot entry points at.

## What was done

1. `snapper create -d pre-aur-limine` → snapshot 13.
2. Built both from the AUR in `~/build/aur/` (`makepkg -s`), then
   `pacman -U` over the repo copies: now `1.40.0-1` and `1.32.1-1`, i.e. the AUR
   builds. `pacman -Qk` → 56 and 52 files, 0 missing. The install re-ran the
   hooks, rebuilt and re-signed the `linux-omarchy` UKI, and rewrote
   `/boot/limine.conf`; `limine-list` still reports `Omarchy → linux-omarchy,
   linux`.
3. Found the real dependency hiding behind the packages: the settings that make
   the tool produce **UKIs at all**, and reuse the existing filenames, live in
   `/etc/limine-entry-tool.d/omarchy-{defaults,uki}.conf` — owned by
   **`omarchy-settings`**, not by either limine package. `ENABLE_UKI=yes` and
   `CUSTOM_UKI_NAME="omarchy"` are in there. Removing the package would have
   silently dropped the boot stack back to non-UKI defaults with the OS entry
   renamed from `/etc/os-release`.
   Fix: [`config/limine/50-jason.conf`](../../../config/limine/50-jason.conf),
   deployed to `/etc/limine-entry-tool.d/50-jason.conf`. It sorts before
   `omarchy-defaults.conf`, so nothing changed while Omarchy is still installed;
   it takes over the moment that package goes.
4. Verified with `limine-update`: the only difference in `/boot/limine.conf` was
   the two UKI hashes (rebuilt), so entry names, cmdline and structure are
   untouched — no duplicated kernel parameters from both files being read.

## Also established

- `limine-snapper-sync` works but produces **no** snapshot entries today: `/boot`
  is 54% of 1G (two UKIs at 272M each) against `LIMIT_USAGE_PERCENT=50` in
  `/etc/default/limine`. Dropping `linux-omarchy` halves that usage, which is
  what turns snapshot booting on. It is kept, not dropped.
- `/etc/mkinitcpio.d/` holds only `linux.preset.pacsave` — no active preset, and
  neither kernel package ships one. That is fine: `limine-mkinitcpio` drives
  mkinitcpio itself, so presets are not part of this boot path.

## Remaining for the swap

- `pacman -Rns omarchy omarchy-settings` will try to remove the two limine
  packages as orphans; they are already AUR-owned, so `-Rns omarchy` alone is
  enough — do not let it take `limine-mkinitcpio-hook`.
- Agent CLIs: `@ampcode/cli`, `@opencode/cli` via
  `/usr/bin/node /usr/lib/node_modules/npm/bin/npm-cli.js`, not plain `npm -g`
  (mise owns node and the global prefix). Documented in
  [`../whitelist.md`](../whitelist.md).
