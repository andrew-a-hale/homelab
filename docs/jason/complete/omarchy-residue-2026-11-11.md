# Omarchy residue audit — 2026-11-11

Question: after removing the `[omarchy]` repo and its 34 packages, is anything
Omarchy still on the box — config, settings, or the migration machinery that
"could change anything"?

Method: name scan (`find / -iname '*omarchy*'`), content scan
(`grep -rl omarchy /etc /usr /usr/local`), unit check (`systemctl list-unit-files`
both scopes), cron, pacman hooks, and the pacman keyring. Re-run any of those to
re-check.

## Can anything still run? No.

The migration scripts lived inside `/usr/share/omarchy` (owned by the `omarchy`
package, gone) and were driven by user units (`omarchy-migrate-notify`,
`omarchy-crash-watch`, …) that were disabled during the cutover and disappeared
with the package. Checked and empty: `systemctl list-unit-files | grep -i omarchy`
(system and user), `crontab -l` (both scopes), `/etc/pacman.d/hooks` (only
`90-mkinitcpio-install` and `99-limine`), and `grep -rl 'omarchy/migrations'
/usr /etc` → nothing. `/var/lib/omarchy/migrations/` held eight timestamp markers
with no script left to read them; removed.

## What was actually still Omarchy

Three of these mattered:

1. **`/etc/os-release` said `NAME="Omarchy"`, `ID=omarchy`.** Anything that
   branches on distro id — installers, `makepkg`, `lsb_release`, my own
   `printf '%s …' $(. /etc/os-release …)` host check — saw Omarchy, not Arch.
   Arch has no `/etc/os-release`; it reads `/usr/lib/os-release`. Replaced with a
   symlink to that:
   `ln -sf ../usr/lib/os-release /etc/os-release` → `Arch Linux / ID=arch`.
2. **`/etc/pacman.d/mirrorlist` was a single line: `https://stable-mirror.omarchy.org`.**
   No Arch mirror at all, so every `pacman -S` was pulling Arch packages from
   Omarchy's CDN. `pacman-mirrorlist` reinstalled (stock file ships its Server
   lines commented), then the two official CDN mirrors uncommented —
   `fastly.mirror.pkgbuild.com`, `geo.mirror.pkgbuild.com` — and `pacman -Syy`
   run clean, `pacman -Dk` reports no errors.
3. **`/etc/sudoers.d/99-omarchy-installer-reboot`**: `andy ALL=(ALL) NOPASSWD:
   /usr/bin/reboot`. Any process running as `andy` could reboot without a
   password. Removed — `scripts/power-menu.sh` calls `systemctl reboot`, which is
   polkit, not sudo — and `visudo -c` revalidated.

The rest:

| Path | What it was | Done |
|---|---|---|
| `/etc/pam.d/omarchy-lock-password` | Omarchy's faillock PAM stack for its lock screen | removed; our `hyprlock.conf` uses the `hyprlock` PAM service |
| `/etc/sddm.conf.d/99-omarchy-login.conf` | `RememberLastUser/Session` | renamed `99-login.conf`, same content |
| `/etc/sddm.conf.d/10-wayland.conf{.pacnew,.pacsave}` | pointed `CompositorCommand` at `/usr/share/sddm/hyprland.lua`, a file that no longer exists | dropped; wrote a plain `10-wayland.conf` with `DisplayServer=wayland` |
| `/etc/skel/.bashrc` | sourced `/usr/share/omarchy/default/bash/{env-bootstrap,rc}` — every new user got a broken shell | replaced with a stock Arch skeleton |
| `/etc/default/limine` | "Written by omarchy-upgrade-to-quattro", `BOOT_ORDER` listed `linux-omarchy*` | comment reworded, order is now `linux, linux-*, *fallback, Snapshots` |
| `/etc/limine-entry-tool.d/zz-jason.conf` | `TARGET_OS_NAME="Omarchy"`, `CUSTOM_UKI_NAME="omarchy"` | `"Arch"` / `"arch"` → UKI is `arch_linux.efi`, menu title `Arch` (verified across a second `limine-update`, so it does not come back) |
| `/boot/limine.conf` | existing entry still titled `/+Omarchy` | strimmed; `limine-update` keeps the new name |
| `/var/lib/omarchy/migrations/*` | eight inert migration markers | removed |
| `/etc/systemd/network/omarchy-networkd-retired-*` | dead directory from a past upgrade | removed |
| `/etc/sysctl.d/90-omarchy-file-watchers.conf.{pacnew,pacsave}` | inotify `max_user_watches=524288` was **live in kernel but had no active file** — it would have reverted to 65536 at next boot | wrote `/etc/sysctl.d/90-file-watchers.conf` |
| omarchy key in the pacman keyring | trusted key `40DFB630…C571`, its package long gone | `pacman-key --delete` |
| `~/.config/hypr/{hyprland,bindings,autostart,input,looknfeel,monitors,envs}.conf` | Omarchy's Hyprland config, still sourcing `/usr/local/share/omarchy/…` paths | removed. All 58 live binds are `__lua` dispatchers, zero Omarchy binds; `hyprctl configerrors` empty. Keeping them was a trap: if `hyprland.lua` ever vanished, Hyprland would fall back to those and load nothing |
| `~/.config/hypr/shaders/`, `bindings.lua`, `hyprsunset.conf`, five `*.bak`/`*.template.bak` | Omarchy theme shaders, its bundled binds, a night-light config for a removed package | removed |
| `~/.config/uwsm/{env,default}` (only `.bak` left) | exported `OMARCHY_PATH` into the session | removed; the directory is gone, env comes from `hyprland.lua` |
| `~/.config/*/NativeMessagingHosts/com.omarchy.{ytdlp,copy_url}.json` | browser native-messaging registrations pointing at `/usr/share/omarchy/bin/…`, now dead paths | removed from every browser profile |
| `/etc/chromium|brave/policies/managed/omarchy.json` | `DefaultBrowserSettingEnabled: false` (sensible policy, Omarchy-branded name) | renamed `00-no-default-prompt.json` |
| `/etc/ssh/ssh_config.d/20-omarchy-keepalive.conf` | keepalive settings | renamed `20-keepalive.conf` |
| `/var/lib/dkms/nvidia/*7.2.5-3-omarchy`, `/usr/lib/modules/7.2.5-3-omarchy` | stale NVIDIA DKMS build and module tree for a kernel that no longer exists | `dkms remove`, then the directories |
| 6× `mirrorlist.omarchy-upgrade-to-quattro.*.bak`, 6× `pacman.conf.*.bak` | August upgrade backups | removed |

## Deliberately kept

- `/etc/pacman.conf.omarchy-2026-11-11` — the backup of the removed repo block,
  referenced by a comment in `/etc/pacman.conf`.
- `~/.config/hypr.omarchy-2026-11-11`, `~/.bashrc.omarchy-2026-11-11` — the
  rollback copies, until the new config has held for a week.
- `/boot/a56d…/limine_history/omarchy_linux.efi_sha256_…` — the snapshot boot
  entry's copy of the old UKI. It is *content*, not configuration; renaming it
  would break snapshot 16's menu entry.

## Re-checking later

```sh
sudo find / -xdev -iname '*omarchy*' -not -path '/proc/*' 2>/dev/null   # names
sudo grep -rl omarchy /etc /usr/local 2>/dev/null                        # content
systemctl list-unit-files | grep -i omarchy; systemctl --user list-unit-files | grep -i omarchy
cat /etc/os-release | head -3; grep '^Server' /etc/pacman.d/mirrorlist
hyprctl configerrors; hyprctl -j binds | grep -c omarchy
```

Expect: no names outside `/boot/a56d…`, no units, `ID=arch`, real mirrors, no
config errors, zero Omarchy binds.
