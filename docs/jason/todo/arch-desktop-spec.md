# Jason desktop — what I actually use and want (target spec)

Status: draft spec, 2026-11-09. This is the "what", not the "how" — see
`leave-omarchy.md` for the migration plan.

Rule: **anything not listed here does not get installed** on the new plain-Arch
desktop. Evidence, not guesses: `~/.config/hypr/*.lua`, running processes,
`~/.config/autostart`, `~/.local/share/applications`, and the inverse of
`scripts/pacman-atime-audit.sh` — 116 explicit packages that had a binary run in
the last 10 days.

## 1. Machine

Desktop, RTX 3070 (`nvidia-open-dkms`, `nvidia-utils`, `lib32-nvidia-utils`,
`libva-nvidia-driver`, `vulkan-icd-loader`). Two LG UltraGear panels: DP-2
landscape primary at 0x0, DP-1 portrait 1920x-190, transform 3.
Workspaces 1/3/4/5 pinned to DP-2, workspace 2 persistent on DP-1.

Disk: LUKS → btrfs `@ /`, `@home`, `@log`, `@pkg`, EFI `/boot`, zram swap.
Keep as-is (all stock Arch, no reason to change): **Limine** bootloader,
**snapper** + limine-snapper-sync, **sddm** login, **uwsm** session
(`Hyprland` launch chain), `sbctl` secure boot.

## 2. Session behaviour (must)

- Hyprland (stock Arch package) under uwsm; portals: hyprland + gtk;
  `hyprland-preview-share-picker` for screen share.
- Input: fcitx5 (Japanese + Chinese addons), `kb_layout us`, `caps:escape`,
  repeat 50/200, flat pointer accel, touchpad scroll factor 0.4.
- Idle → `hypridle` → `hyprlock`. Nightlight via `hyprsunset`.
- Clipboard: `wl-clipboard` + `wl-clip-persist`.
- Removable drives: `udiskie` (+ nautilus mount views).
- Audio: pipewire + pipewire-pulse + wireplumber.
- Screenshots: `grim` + `slurp` + `satty` (+ `wl-clipboard`), three binds — see
  §2.1/§3 of `needs.md` batch 5. Screen recording: `gpu-screen-recorder`.
  `hyprshot`, `flameshot`, `ksnip` and `omasnap` are all dropped.
- Power: `omarchy-power-profiles-daemon` behaviour (or `power-profiles-daemon`),
  external monitor brightness via `ddcutil`.
- Nightly dev environment: docker + docker-compose, tailscale, ufw, pass,
  gnome-keyring, proton-vpn-cli.

Decisions still open: bar, launcher, notifications, OSD, theming — see §7.

### 2.1 Workspace layout: SUPER + L toggles tiling ↔ floating

Wanted, and only this: `SUPER + L` floats the workspace you are on and `SUPER +
L` again tiles it back. No layout cycling, no titlebars, no per-workspace modes,
no state files.

Hyprland has no floating layout — `general:layout` and the per-workspace
`layout` rule accept `dwindle`, `master`, `scrolling`, `monocle`, `lua:<name>`
only (verified, `hyprctl -j descriptions`, Hyprland 0.56.2). Omarchy's *Workspace
Layout > Floating* is a ~500-line `/usr/share/omarchy/default/hypr/workspace-modes.lua`
faking it: per-window tags, open/move/fullscreen watchers, dynamic open rules,
the `hyprbars` plugin, and a state file per workspace. The toggle needs two
things instead: a named window rule that floats what opens there, and a pass over
the windows already on it.

Written and verified: [`config/hypr/binds.lua`](../../../config/hypr/binds.lua)
in this repo, next to every other bind. The shape is a named window rule plus a
loop over the windows already on the workspace — two things, not a mode engine.

Verified on Jason (Hyprland 0.56.2, 2026-11-11) with the same body driven from
`hyprctl eval` on a scratch workspace: two tiled windows floated on `on`, a
window opened afterwards floated, `off` tiled all three, and a fourth window
opened afterwards tiled. Other workspaces and other monitors untouched.

Trade-offs, all accepted: floating workspaces are forgotten on config reload
(they come back tiling); fullscreen windows are left alone; a window an app
floated by its own rule is tiled on toggle-off.

`SUPER + L` is Omarchy's layout-cycle key today — on the new desktop it is the
only layout key, which is the whole point.

## 3. Keybinds

The final keymap is [`docs/jason/binds.md`](../../jason/binds.md) — hand-edited,
37 binds plus 2 workspace-range rows (switch / move-to-workspace 1–10), and the only key source once Omarchy is gone. What
it replaces: Omarchy's ~130 default binds, of which the personal overrides were 21.
Notable removals from the old set: every webapp key, VNC, the Omarchy menu and
panels, the layout cycle, and (from the first draft) monitor-focus, multi-monitor
workspace moves, group toggle, tab cycling and the XF86 volume/media keys.

## 4. Apps in use (last 10 days, by group)

- **Browser**: chromium (default, profile 4), firefox (Discord web).
- **Terminals**: ghostty, tmux.
- **Editor**: neovim, visual-studio-code-bin.
- **Files/media**: nautilus, gnome-disk-utility, mpv, streamlink, yt-dlp,
  libreoffice-fresh, kdenlive, imagemagick, libvips.
- **Comms**: signal-desktop, vesktop. The official `discord` client is dropped —
  `vesktop` is independent of it (`Required By: None`, different dependencies).
- **Gaming**: steam (Proton; `wine-staging` never ran → drop).
- **Dev**: git, github-cli, docker, docker-compose, mise-bin, bun-bin, go,
  rustup, zig, julia, elixir, r, ruby, clang, llvm, python310, uv, odin,
  emscripten, postgresql-libs, lazygit, herdr, expac.
- **CLI**: btop, eza, fd, ripgrep, zoxide, starship, fzf-less setup, jq, gum,
  less, man-db, plocate, unzip, socat, inetutils, inotify-tools, nmap,
  nfs-utils, ntfs-3g, ntfsprogs, dosfstools, btrfs-progs, efibootmgr,
  networkmanager, nmcli/avahi, bind (dig), wireless-regdb, systemd-resolvconf.
- **Omarchy-built apps in use**: herdr only — `hype omawrite omasnap gliff cliamp
  monologue disktree-bin ttfx` are dropped (`needs.md` batch 1). Screen capture
  becomes a needed feature: `grim` + `slurp` + `satty`.
- **Fonts**: JetBrains Mono Nerd, Noto (incl. CJK + emoji), Cascadia Mono Nerd,
  iA Writer.

## 5. Web apps — none

Decided 2026-11-11: **no web apps**. Everything is a normal browser tab; the 12
`chromium --app=` windows are not recreated. The binds that opened them go with
them — `SUPER+M` (YouTube Music), `SUPER+Y` (YouTube), `SUPER+SHIFT+S` (Steam
store), `SUPER+D` (Discord web in firefox). `SUPER+B` / `SUPER+SHIFT+B` stay: they
launch the browser, not a web app.

## 6. Omarchy-only software that has to be replaced or rebuilt

No Arch package exists; each needs an AUR/source decision:

`hype`, `omawrite`, `omasnap`, `gliff`, `cliamp`, `monologue`, `herdr`,
`disktree-bin`, `ttfx`, `owe` (video wallpaper daemon — only if video
wallpapers stay), `aether` (colour-from-wallpaper theming — unused, drop),
`omacut/omacalc/localsend/tobi-try/vortix` (unused, drop).

## 7. Wants — decisions I still have to make

- [ ] Bar: waybar, something lighter, or none (status via keybind/btop)?
- [ ] Launcher/run menu: fuzzel, rofi, or none (Super+Return everything)?
- [ ] Notifications: mako, dunst, swaync, or none?
- [ ] Volume/brightness OSD: swayosd, or silent keys?
- [ ] Theming: keep Tokyo Night + wallpaper theming (aether/owe), or flat
      dark + `wallust`/pywal and stop there?
- [ ] Clipboard history: keep Omarchy's clipboard menu (needs a tool) or drop?
- [ ] Keep the "menu" concept (SUPER+SPACE) at all, or keybind-only?
- [ ] Emoji picker, share picker, dictation, voxtype, v4l2-relayd: any of it?
- [x] Per-workspace floating — settled in §2.1: one `SUPER + L` toggle (named
      window rule + one loop), nothing else from Omarchy's layout system.
- [ ] Anything else Omarchy was hiding (tiling layout plugins, per-monitor
      theming, Hyprland animations)?

## 8. Explicitly not wanted

wine-staging, typora, spotify, boost, terraform, rclone, localsend,
jellyfin-server, python39/poetry stack, omarchy-nvim, printing (cups +
system-config-printer), bluetooth utilities beyond the basics, extra terminals
(alacritty, foot, kitty), screenshot tools (flameshot, ksnip, hyprshot),
`sl`, `asdcontrol`, `tobi-try`, `vortix`, `macut/omacalc`, the 42 `hw-*` machine
profiles, 46 `install-*` / 35 `remove-*` helpers, 37 AI usage meters, quickshell
shell, plymouth theme, Omarchy sddm theme, `/etc/skel` dotfiles.
