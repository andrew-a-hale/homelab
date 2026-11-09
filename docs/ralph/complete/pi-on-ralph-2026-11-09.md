# Pi on Ralph, reachable from the phone — 2026-11-09

**Goal:** run `pi` on Ralph, in `~/projects/homelab`, from the phone over the
tailnet, with the repo's own skills.

## Decision

**SSH + tmux. No web front-end, no Cloudflare Access, no ttyd.**

Ralph already has key-only `sshd`, `22/tcp` open only on `tailscale0`, and the
phone has Tailscale + Termux. A tmux session is the whole feature; there is
nothing to build on top of it. Opencode's browser UI (`opencode web`, one
password, `tailscale serve`) was considered and is kept in reserve for if a
terminal on a 6-inch keyboard turns out to be the actual pain — it is a phone
UX swap, not an agent swap.

Ralph's agent is deliberately **minimal**: pi plus the repo's `skills/`
(`homelab-health`, `petcam-retrain`), nothing from `~/projects/pi-config`.
Skill/extension/package parity with Jason is not wanted here.

## What was installed on Ralph

```bash
sudo pacman -S --needed nodejs npm tmux
sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent   # 1.5.0
```

`~/.pi/agent/settings.json` is a real file (not a symlink into `pi-config`),
provider `opencode-go` / `deepseek-v4.1-flash`, no `packages`. Re-add ponytail
later with `pi install npm:@dietrichgebert/ponytail`.

## Credential

`OPENCODE_API_KEY` in Ralph's `~/.profile`, from a key created for Ralph — not
Jason's. The provider's IP allowlist is `220.244.74.53/32`, Ralph's egress:
direct over `wlan0`, `wg-quick@proton0` installed but inactive, IPv4 only. That
is the **house** IP, not Ralph's; it moves when the ISP or router reassigns, and
it breaks if `proton0` is ever brought up (egress then leaves via a shared
Proton exit). Treat the allowlist as a speed bump, not identity.

## Phone

```bash
ssh andy@ralph -t 'tmux new -A -s pi'
```

`-A` reattaches the same session, so a dropped mobile connection loses nothing.

## Things that bit

- Ralph pulls GitHub over **HTTPS**; it has no GitHub SSH key (`ssh -T
  git@github.com` → denied). Cloning `pi-config` over SSH failed; the repo is
  public, so HTTPS works for read-only pulls.
- Jason's `~/.pi/agent` is almost entirely symlinks into `~/projects/pi-config`
  (`settings.json`, `models.json`, `skills`, `extensions`, `prompts`, `bin`,
  `APPEND_SYSTEM.md`, `keybindings.json`, `machine.conf`). `rsync -a` copied the
  symlinks and not the targets, so Ralph ended up pointing at a nonexistent
  clone. Copying that directory to another host needs `-L` or a follow-up clone.
