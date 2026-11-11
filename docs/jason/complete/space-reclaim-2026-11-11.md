# Space reclaim and Omarchy leftovers — 2026-11-11

Third and last pass of the migration night. Nothing here changes behaviour; it
deletes things that are regenerable or already dead. Measured before and after
with `df` / `du`, because the two disagree and `du` was the one that lied (btrfs,
shared extents).

## Before → after

| | Before | After |
|---|---|---|
| `/` used | 476G | 431G |
| `~/.cache` | 54G | 5.4G |
| `/var/cache/pacman/pkg` | 18G | 6.2G |
| journal | 3.1G | 482M |
| Docker `df` reclaimable | ~29G | 0 (build cache), 14.9G images left |

## What went

**Caches (48.6G, all regenerable on next use).** The two that mattered were
`uv` (25G of wheels and sdists) and `mise` (8G) — the latter kept caching for a
tool manager that no longer exists. Then `chromium` 7G, `mozilla` 2.7G (caches,
not profiles — those live in `~/.config`), `yay` 2G of build dirs, `zig` 1.4G,
`vpython` 1.5G, `electron` 1.1G.

**`~/.local/share/pnpm` 2.7G** — a store for a package manager that is not
installed and has no project referencing it.

**Dead Omarchy trees (~400M):** `~/.config/omarchy`, `~/.local/share/omarchy`,
`~/.local/state/omarchy`, and 12 `*.omarchy-upgrade-to-quattro.20260825065655.bak`
files that the Omarchy upgrader had left in `~/.config` in August — mako,
waybar, walker, swayosd, brave/chromium flags, mimeapps (×3), ttf, xdg-terminals.

**AUR build dirs 1.5G:** `~/build/aur/*/{src,pkg}` for the two limine packages,
already installed. `~/build` 2.2G → 682M.

**`pacman -Sc` 12G.** `paccache -rk3` reported "no candidate packages found" while
2170 package files sat there, so `pacman -Sc` did the job: keeps the installed
version of everything, drops superseded copies.

**Journal vacuum 2.7G** (`--vacuum-size=500M`).

**Docker: 17.2G build cache + 20 stopped containers.** `docker builder prune -f`
is pure garbage. `docker container prune -f` was more than that — it removed the
stopped dev containers for the project stack (academy-portal, digital-twin, elo,
mox, spicy, service-boilerplate…). **No data was lost**: all 22 volumes survived
(`academy-portal_academy-pgdata`, `digital-twin_pgdata`, `elo_postgres_data`,
`mox_db-data`, `spicy_pgdata`, …), the images are still cached, and the two live
containers (`service-boilerplate-db-1`, `-db-admin-1`) were untouched. Each of
those stacks is `docker compose up` away from existing again. Worth knowing
before doing it again: `container prune` is not the same size of decision as
`builder prune`.

## Packages: five leaves and 2.8G

No orphans existed (`pacman -Qtdq` empty) and `scripts/pacman-atime-audit.sh 90`
reported **nothing unused in 90 days** — every explicit package with a binary had
one run inside the last quarter. So this part is not an audit result, it is six
judgement calls, each with a `Required By: None` and a reason:

| Package | Size | Why it went |
|---|---|---|
| `dotnet-source-built-artifacts` | 1.27G | Source-built .NET binaries for building .NET *itself*. Not a dependency of `dotnet-sdk` (that wants `dotnet-runtime` + `dotnet-targeting-pack`). `dotnet --version` still 10.0.101 afterwards |
| `emscripten` | 1.29G | Only hits were inside `node_modules` of a pi example and a rust bindgen JSON. No project here builds wasm; `clang`/`llvm` stay for rust |
| `yaru-icon-theme` | 63M | Omarchy's icon theme; nothing in `~/.config/gtk-*`, hypr or `config/` names it |
| `bun-bin` | 85M | No `bun.lockb`/`bunfig.toml` anywhere in `~/projects`, last binary read Oct 10 — node/npm do that job |
| `tzupdate` | 2.4M | Ships one binary, no `.timer`, no unit — the timezone is set once |
| `feh` | 1M | X11 wallpaper setter; `hyprpaper` is the wallpaper |

`cmake` (103M) came out with them: removing `emscripten` left it orphaned and
`pacman -Rns` swept it. Reinstall if a C++ build ever asks.

Net: 1205 packages / 191 explicit.

**Kept on purpose, though each is one command to drop:** `julia` 571M (run Oct
16), `odin` 122M, `d2-bin` 40M, `python310` 55M, `amp-desktop-bin` 284M, `herdr`
21M, `visual-studio-code-bin` 1.05G, `lib32-nvidia-utils` 563M (Steam needs the
32-bit stack). The 90-day audit says all of them were executed recently, so it is
a taste question, not a dead-weight one.

## Snapshots are not pinning much

Checked before blaming them: exclusive size per snapshot is 0–1.4G (the rest is
shared CoW of the live tree), so deleting 9–13 would buy at most ~1.5G. Not worth
losing the rollback points.

## Also fixed

- `/etc/plymouth/plymouthd.conf` had `Theme=omarchy`, a theme package that is
  gone. Now `Theme=spinner` (a stock theme that is actually installed).
- `/etc/pacman.conf` keeps a one-line comment where `[omarchy]` was, pointing at
  the backup — deliberate, it explains the gap to whoever reads it next.

## Left alone, on purpose

| Thing | Size | Why it stays |
|---|---|---|
| `~/.local/share/Steam` | 340G | Real games. `Path of Exile 2` alone is 145G, `Expedition 33` 44G, `Grim Dawn` 16G. Moving or pruning it is a user decision, not cleanup — see below |
| `~/.config/hypr.omarchy-2026-11-11` | small | The rollback tree. Keep until a week of the new config has held |
| `~/.local/share/Trash` | 566M | Not mine to empty |
| `~/.rustup` 2.8G, `~/go` 2.9G, `~/.cargo` 354M, `~/.local/share/NuGet` 443M | | Toolchains he actually uses (or used recently); deleting is not "cleanup" |
| `~/.local/share/{nvim,opencode}` 1.9G + 1.2G | | Plugin/agent data, would re-download and lose state |
| Docker images | 25G, 14.9G reclaimable | Re-pullable, but 101 of them suggests intent |
| `/mnt/storage` `/mnt/games` | | Empty by design |

## The one real decision left

`/` is 431G used and 340G of it is Steam — `common` 263G, `compatdata` 69G of
per-game Wine prefixes, `shadercache` 2.8G. `nvme1n1` (229G, `/mnt/games`) cannot
hold it; `sda1` (1.8T, `/mnt/storage`) can, but it is a spinning disk.

Options, in order of how much they actually help:

1. **Uninstall what is not being played.** PoE2 at 145G is the whole argument for
   a second look; uninstalling one game is worth 40% of the library.
2. **Second library on `/mnt/storage`** — Steam → Settings → Storage → Add Drive.
   Cold games on the HDD, current ones on NVMe. Zero data loss, per-game choice.
3. **Leave it.** 496G free is not a problem yet.

`compatdata` is the sneaky one: those are per-game prefixes and grow even when
the game does not. Anything uninstalled leaves an orphan prefix behind —
`compatibilitytools.d`/`compatdata` prunes are manual.
