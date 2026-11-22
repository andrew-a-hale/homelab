# Omarchy: final sweep — 2026-11-20

Task: "Omarchy should be entirely removed from this system." The 2026-11-11
[residue audit](omarchy-residue-2026-11-11.md) cleared `/etc`, `/usr` and the
systemd scopes. What it left was the *user* side: dead launchers and imports
that still named Omarchy paths, plus assets and backups from its migration
machinery.

Method: repeat the residue audit over `$HOME` (name scan and content scan), fix
each live reference, then delete what no longer has anything behind it.

## What was actually broken (not just named)

| Thing | Symptom |
|---|---|
| `~/.config/hyprland-mimeapps.list` → `omarchy-browser.desktop` → `omarchy-launch-browser` (gone) | clicks on links in any app went nowhere; the file overrode `firefox.desktop` for Hyprland sessions. Deleted — `mimeapps.list` (firefox for http/https/mailto) is back in charge |
| 15 web-app `.desktop` files running `omarchy-launch-webapp`, `omarchy-webapp-handler-{hey,zoom}` | dead entries in the launcher. `docs/jason/whitelist.md` already settled on **no web apps**, so all of them went, with `~/.local/share/applications/icons/` |
| `Docker.desktop` → `omarchy-launch-docker-tui` | dead, nothing to replace it (no lazydocker installed). Deleted |
| `~/.XCompose` line 1: `include "/usr/share/omarchy/default/xcompose"` | include of a missing file |
| `~/.config/ghostty/config` imported `~/.local/state/omarchy/current/theme/ghostty.conf` | theme path never existed under the new session (it was optional, so it silently did nothing) |
| `~/.local/share/fcitx5/themes/omarchy`, `Theme=omarchy` in `classicui.conf` | input-method popup themed from a directory whose icons pointed into Omarchy's tree. Theme → `default` / `default-dark`; directory removed |
| `~/.config/{alacritty,foot,kitty}` | configs for terminals that are not installed, each importing the same dead theme path |
| `~/.config/brave-flags.conf` loading three Omarchy chromium extensions | Brave is not installed; the flag pointed at `/usr/share/omarchy/...` |
| `~/.config/hyprland-preview-share-picker/config.yaml` stylesheet | `stylesheets: []` |
| dangling skill symlinks (`.claude`, `.agents`, `.codex`, `.hermes`, `.gemini`) | pointed at `/usr/share/omarchy/default/agents/skills/*` — the OMARCHY skills every agent harness was being told about |
| stale `HEY.desktop` / `Alacritty.desktop` / `foot.desktop` / `feh.desktop` handlers in `~/.config/mimeapps.list` | pointed at deleted or never-installed desktop files |

## Deleted outright

- migration backups: 9× `*.<…>.omarchy-upgrade-to-quattro.*.bak`, 4× chromium
  `Preferences.omarchy-copy-url-repair.bak`, `icons.omarchy-…bak`,
  `chromium-flags.conf.bak-*`
- `~/.local/state/Omarchy/omasnap/`, `~/.local/state/tensaku/omarchy-wrapper-done`
- omarchy brand assets: `.claude/themes/omarchy.json`,
  `.pi/agent/themes/omarchy-system.json`, 12 Brave `com.omarchy.*.json`
  native-messaging registrations, the `bjarne.ethereal-omarchy` VS Code
  extension and its cached VSIX
- `~/.local/state/nvim/{sessions,undo}` entries for `/usr/share/omarchy` files,
  and the `omarchy-theme-hotreload` plugin in two nvim backups
- `/etc/pacman.conf.omarchy-2026-11-11` (the old repo block — git history and the
  residue record keep it) and the comment pointing at it, plus a stale
  `/etc/pacman.conf.bak`

## Reworded, not deleted

Comments that explained *why* a value is what it is, minus the Omarchy framing:
`config/hypr/{hyprland,autostart,binds,input,looknfeel}.lua`,
`config/hypr/hyprpaper.conf`, `config/waybar/config.jsonc`, `config/shell/bashrc`,
`/etc/sysctl.d/90-file-watchers.conf`.
`/etc/limine-entry-tool.d/zz-jason.conf` also lost its dead `linux-omarchy`
`BOOT_ORDER` token; `config/limine/zz-jason.conf` was rewritten to match and
redeployed (`limine-update` clean, UKI still `arch_linux.efi`).
`~/.config/nvim/lua/config/remote_clipboard.lua` (and the `pi-config` copy):
`vim.g.omarchy_remote_clipboard_*` → `vim.g.remote_clipboard_*`,
`@omarchy-nvim-cleared-buffer` → `@nvim-cleared-buffer`.

## Deliberately left

- `/boot/a56d…/limine_history/omarchy_linux.efi_sha256_…` and the snapshot menu
  entry labelled `post-omarchy-cleanup` — snapshot *content*, renaming breaks
  snapper's mapping. `/boot` is a separate mount and the only place the string
  survives on disk.
- `docs/` — the decision log is the reason this machine is what it is. History,
  not configuration.
- Browser profile data (`~/.mozilla`, `~/.config/chromium`,
  `~/.local/share/opencode`, agent session logs): user content, not config.

## Verify

```sh
sudo find / -xdev -iname '*omarchy*' -not -path '/proc/*' 2>/dev/null   # → nothing
sudo grep -rIl omarchy /etc /usr/local /usr/share/applications 2>/dev/null  # → nothing
grep -rIl omarchy ~/.config ~/.bashrc ~/.XCompose                       # → nothing
systemctl list-unit-files | grep -i omarchy; systemctl --user list-unit-files | grep -i omarchy
hyprctl configerrors; hyprctl -j binds | grep -c omarchy                # → empty, 0
xdg-mime query default x-scheme-handler/https                           # → firefox.desktop
```

Run on 2026-11-20: all of the above clean; a web-app-free launcher, fcitx5 on
its stock theme, ghostty and nvim starting without the removed imports.
