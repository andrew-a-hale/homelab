# Jason — user-land whitelist

The user-facing half of [`packages.md`](packages.md): what a person opens, runs or
looks at. **System layer is out of scope** — kernel, bootloader, filesystems,
firmware, libraries, portals-as-dependencies and the like are the distro's problem,
not a whitelist decision.

Rule: if it is not on this page it is not installed. Evidence is from this box:
`~/.bash_history` (32,768 lines) for command counts, `pacman` atime for GUI apps,
`binds.md` for what is on a key. Verdicts and the 71 drops stay in
[`packages.md`](packages.md) and [`todo/needs.md`](todo/needs.md).

## Apps opened by hand

| Package | What it gives me | Evidence | |
|---|---|---|---|
| `chromium` | default browser (Profile 4) | `SUPER+B`, `SUPER+SHIFT+B` ||
| `firefox` | second browser | `firefox` ×9, `SUPER+SHIFT+RETURN` today ||
| `ghostty` | terminal | `SUPER+RETURN`, 1 window always open ||
| `nautilus` | file manager | `SUPER+F` ||
| `visual-studio-code-bin` | graphical editor | `code` ×28 | Drop |
| `neovim` | terminal editor | `nvim` ×100, `SUPER+N` ||
| `mpv` | video player | default video handler ||
| `libreoffice-fresh` | documents | editor for .docx/.xlsx ||
| `steam` | games | `SUPER+S` ||
| `vesktop` | Discord (Vencord) | running now, `SUPER+D` ||
| `gpu-screen-recorder` | screen/video capture | `ALT+PRINT` ||

## Terminals and command line

| Package | What it gives me | Evidence (history count) |
|---|---|---|
| `tmux` | persistent sessions | ×60, `SUPER+ALT+RETURN` |
| `herdr` | agent workspace manager — the one Omarchy app kept | ×25, `SUPER+CTRL+RETURN` |
| `git` | version control | ×3293 |
| `github-cli` | `gh` | ×126 |
| `lazygit` | git TUI | ×87 |
| `ripgrep` | `rg` | ×119 |
| `fd` | fast find | ×85 |
| `tree` | directory trees | ×56 |
| `jq` | JSON | ×1 |
| `unzip` | archives | ×12 |
| `make` | builds | ×1219 (from `base-devel`) |
| `pass` | password store | ×62 |
| `ssh` | remote hosts | ×102 (`openssh`, from base) |
| `btop` | process/resource monitor | ×7, `SUPER+A` |
| `eza`, `bat`, `fzf`, `zoxide`, `starship`, `fastfetch` | `ls`/`cat`/finder/prompt/fetch replacements | daily shell use |
| `gum` | shell scripts UI | repo scripts use it DROP |
| `entr`, `inotify-tools` | watch loops | build watchers |
| `nmap`, `socat`, `whois`, `inetutils`, `bind` | network diagnosis | homelab work on Ralph/Tom |
| `qrencode`, `zbar` | QR encode/decode | ad-hoc |
| `vhs` | terminal GIF/tape recordings | ×32 DROP |
| `yt-dlp`, `streamlink` | video downloads/streams | media grabs |
| `xmlstarlet` | XML poking | ad-hoc |
| `tldr`, `man-db`, `less`, `plocate` | documentation and lookup | daily |
| `wtype` | synthetic typing, scripted | ad-hoc |
| `usage` | CLI usage/spec helper | ad-hoc |
| `d2-bin` | diagrams from text | ad-hoc |
| `tailscale` | tailnet access to Tom/Ralph | `tailscale` in daily use |
| `proton-vpn-cli` | VPN (Proton) | ×35 |
| `gnome-keyring`, `libsecret` | keyring for git/ssh/secrets | `secret-tool` ×16 |

## Languages and dev toolchains

History counts in brackets; all of these are actively used, not aspirational.

| Package | What it gives me | Evidence |
|---|---|---|
| `dotnet-sdk` (+ `dotnet-runtime*`, `aspnet-*`) | .NET | `dotnet` ×2611 |
| `uv` | Python env/deps | `uv` ×958, `uvx` ×28 |
| `python310` | pinned interpreter | projects |
| `python-numpy`, `python-gobject` | libs those projects need | imports |
| `zig` | Zig | `zig` ×734 |
| `go` | Go | `go` ×705 |
| `elixir`, `erlang` | Elixir/OTP | `elixir` ×454, `mix` ×25 |
| `rustup` (+ cargo) | Rust | `cargo` ×276 |
| `odin` | Odin | `odin` ×176 |
| `r` | R | `Rscript` ×113 |
| `julia` | Julia | `julia` ×30 |
| `gleam` | Gleam | `gleam` ×14 |
| `clang`, `llvm` | C/C++ | builds |
| `gcc-fortran` | Fortran (numerics stacks) | deps |
| `emscripten` | WASM | builds |
| `ruby` | Ruby | tooling DROP |
| `nodejs`/`npm`/`bun`/`npx` | JS runtime + package managers | ×56/×32 |
| `docker`, `docker-compose`, `docker-buildx` | containers | ×148/×57 |
| `qemu-base`, `qemu-user-static-binfmt` | VMs + foreign-arch | cross-builds |
| `postgresql-libs`, `mariadb-libs` | DB client libs | project deps |
| `libqalculate` | `qalc` unit/expr calculator | ad-hoc |
| `yay` | AUR helper | ×83 |
| `nodejs` | JS runtime that installs the agent CLIs | `extra/nodejs` |
| `uv` | Python env/deps (also what mise was providing) | `extra/uv` |

## Desktop shell (user-facing parts only)

| Package | What it gives me | Note |
|---|---|---|
| `hyprland` | the compositor | `SUPER+L` floating toggle lives here |
| `waybar` | bar: workspaces, clock/date, wifi, volume | new, replaces `quickshell` |
| `fuzzel` | launcher | new, `SUPER+SPACE` |
| `hyprpaper` | wallpaper | new, replaces `owe` |
| `hyprlock`, `hypridle` | lock screen, idle | lock at 150s |
| `hyprland-preview-share-picker` | pick the window to share | screen share |
| `hyprpicker` | colour picker | 231 KB, ran recently — keep unless you say otherwise |
| `grim`, `slurp`, `satty` | screenshot → annotate → clipboard | `PRINT`, `SHIFT+PRINT` |
| `wl-clipboard`, `wl-clip-persist` | clipboard, survives app exit | no history manager, by decision |
| `udiskie`, `gvfs-*`, `gnome-disk-utility` | mount/attach removable drives | GUI + automount |
| `fcitx5` + `mozc`/`chinese-addons`/`hangul`/`chewing`/`gtk`/`qt` | Japanese/Chinese/Korean input | `Ctrl+Space` NOT NEEDED |
| `pipewire*`, `wireplumber`, `pamixer`, `alsa-utils` | audio | bar volume, `wpctl` |
| `noto-fonts*`, `ttf-jetbrains-mono-nerd-basic`, `ttf-cascadia-mono-nerd`, `ttf-ia-writer`, `woff2-font-awesome`, `fontconfig` | fonts, incl. CJK + emoji + icons | waybar/fuzzel/terminal |
| `gnome-themes-extra`, `yaru-icon-theme` | GTK theme + icons | until a theme decision is made |
| `sddm`, `uwsm` | login + session supervision | |

## Gaming

| Package | What it gives me |
|---|---|
| `steam` | games (Proton) |
| `nvidia-open-dkms`, `lib32-nvidia-utils`, `libva-nvidia-driver` | RTX 3070 driver + 32-bit + VA-API |
| `vulkan-radeon` | iGPU Vulkan |

## No mise, no `[omarchy]` repo

Both are out. That leaves three groups to place, all verified against the live
repo/AUR metadata:

**What mise was installing** (agent fleet — keep the tools, lose the installer):
`amp` ×11, `opencode` ×462, `pi` ×280, `playwright`, `claude`, `codex`. Both npm
packages are named differently from the binaries: `amp` is `@ampcode/cli`,
`opencode` is `@opencode/cli`. Install with `npm -g` on `extra/nodejs`, plus `uv`
from `extra/uv`. Nothing else depended on mise.

Trap, measured 2026-11-11: mise also owns **node** (`mise ls node` → 26.8.x,
`/home/andy/.local/share/mise/installs/node/26.13.0` is what `npm prefix -g`
resolves to), because `/usr/bin/npm`'s `#!/usr/bin/env node` finds mise's node
first on `PATH`. So a plain `npm i -g` lands inside mise's tree and dies with it.
At swap time, run npm through pacman's node explicitly:

```sh
sudo /usr/bin/node /usr/lib/node_modules/npm/bin/npm-cli.js i -g @ampcode/cli @opencode/cli
```

`pi` is not npm: it installs itself into `~/.pi/agent/bin/pi` and needs nothing.

**Packages that only existed in `[omarchy]`** and are still wanted:

| Wanted | Source without the omarchy repo |
|---|---|
| `bun` | AUR `bun-bin` 1.4.4 |
| `visual-studio-code-bin` | AUR `visual-studio-code-bin` 1.145.3 |
| `yay` (AUR helper) | AUR `yay` 13.1.0 — bootstrap via `git clone` + `makepkg -si` |
| `ufw-docker` | AUR `ufw-docker` |
| `tzupdate` | AUR `tzupdate` — or drop it, timezone is set once at install |
| `ttf-ia-writer` | AUR `ttf-ia-writer` |
| `yaru-icon-theme` | AUR `yaru-icon-theme` |
| JetBrains Mono **Nerd** | no AUR package exists: `extra/ttf-jetbrains-mono` + `extra/ttf-nerd-fonts-symbols` (what the waybar/fuzzel glyphs actually need), or the Nerd Fonts release zip |
| `linux-omarchy` | `extra/linux` — **already installed**, its UKI is already built and its Limine entry already exists, and `dkms` already has `nvidia/615.78.08` built for it. Booting it is the whole switch |
| `limine-mkinitcpio-hook`, `limine-snapper-sync` | **AUR, same versions** (1.40.0, 1.32.1), both maintained upstream by Zesko — neither is Omarchy software. **done 2026-11-11** — AUR builds are installed over the repo copies, see
[`complete/boot-entries-off-omarchy-2026-11-11.md`](complete/boot-entries-off-omarchy-2026-11-11.md).
`pacman -U` had to happen *before* `pacman -Rns omarchy` took them as orphans: the first owns the pacman hooks and `limine-entry-tool` that write `/boot/limine.conf`, so without it the next kernel update produces no bootable entry. `-snapper-sync` only adds snapshot entries, and is currently suppressed by the `/boot` usage limit (see `README.md`) |
| `omarchy`, `omarchy-*`, `quickshell`, `owe*`, `aether`, `hype`, `omawrite`, `omasnap`, `gliff`, `cliamp`, `monologue`, `disktree-bin`, `ttfx`, `omacalc`, `omacut`, `localsend`, `tobi-try`, `vortix`, `signed`, `asdcontrol`, `spotify`, `typora`, `omarchy-nvim`, `mise-bin`, `omarchy-power-profiles-daemon` | dropped — `power-profiles-daemon` from `extra` if the behaviour is wanted |

**Then** the repo can go: remove `[omarchy]` from `/etc/pacman.conf` and
`pacman -Rns` the layer, which is step 6 of
[`todo/leave-omarchy.md`](todo/leave-omarchy.md).
