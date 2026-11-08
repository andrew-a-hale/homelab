# Decision: no orbs, runners only (2026-11-08)

Amp's account has a self-hosted orb provider registered as `home-orbs`. It was
investigated on 2026-11-08 to see whether it was real. It was not, and the
decision is to stop pursuing it: **this homelab runs work on runners and never
uses orbs, self-hosted or otherwise.**

## What was found

On `jason` (the machine the runner executes on):

- No `amp orb provider` process. The only Amp processes were two `amp --no-tui`
  runners.
- Nothing supervised it: no systemd user or system unit, no timer, no tmux
  server, no autostart entry, no crontab, and `Linger=no`, so even a user unit
  would have died at logout. Shell history shows one stray foreground
  `amp orb provider --token …` that was never given the required `<script>`
  argument.
- No dispatch program existed. `amp orb provider <script>` needs an executable
  handling `ORB_OPERATION`; nothing on the box referenced that string except the
  Amp binary itself. The `~/projects/pong` cargo project from that session is an
  unrelated raylib game.
- The token was not where Amp looks. `~/.local/share/amp/secrets.json` held only
  `oauth-refresh-token` and `apiKey`, and `AMP_ORB_PROVIDER_TOKEN` was absent
  from both runners' environments. The token lived only in `pass` at
  `dev/amp/home-orbs`, passed inline with `--token`.
- No provider log at all — no failed spawn jobs, no auth errors, because the
  controller never ran long enough to log any.

On `ralph`, the box an always-on provider would have belonged on:

- **No `amp` CLI installed at all**, so `amp orb provider` could not even be
  invoked.
- No `docker`, `podman` or `kubectl` — no backend for a dispatch script.
- No `~/.local/share/amp/secrets.json`, no token, no `ORB_OPERATION` script.
- Its shell is Guix-minimal (`hostname` itself is not on PATH), so any install
  would need care about the Arch/Guix split.

Amp's side agreed with the local picture: `home-orbs` was personal,
`isDefault: true`, `activeThreadCount: 0`, `orbTypes: []`.

## Why runners instead

Making `home-orbs` real was a stack of work — Amp CLI on Ralph, a container
runtime, an `ORB_OPERATION` dispatch script, a registered orb type, and a
supervised unit with lingering enabled — to replace something the `jason` runner
already does. Two runners were live on `jason` throughout, and the deployment
model here is already SSH-first (`ssh` + `git pull`, `scp` a model to Tom), so a
sandbox platform in the middle bought nothing.

## Consequences

- Orb threads defaulting to a provider with no orb types have nothing to launch
  and fail rather than falling back. Not creating orb threads makes that moot.
- The `home-orbs` registration still exists on Amp's side, the account setting
  `default_orb_provider` still points at it, and the provider token is still in
  `pass`. All three are dead weight now; deleting the registration needs the
  account owner, and the `pass` entry can be dropped or rotated.
- The rule is now global, not per-repo: Amp's personal `global_agent_guidance`
  setting says never to use orbs in any project, and `AGENTS.md` repeats it for
  this repo.

## Docs

- `docs/amp/README.md` (new): how agents execute here, and the runner inventory.
- `AGENTS.md`: the Amp section now says runners only, and drops the stale
  "runner to connect to Jason to ssh into Tom" wording.
- `TODO.md`: recorded under "Decided not to do".
