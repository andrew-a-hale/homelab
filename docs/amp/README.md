# Amp

How Amp agents execute work in this homelab. **Runners only — no orbs.**

## Execution model

| Path | What | Status |
|---|---|---|
| Runner | `amp --no-tui` processes on `jason`, serving a checkout and reaching Tom and Ralph over the tailnet | In use |
| Orbs | Amp's sandboxed environments, including self-hosted providers | **Rejected 2026-11-08** |

A runner is an ordinary process on a real machine with the real checkout, which
is what this homelab wants: deployment is `ssh` + `git pull` (and `scp` a model
to Tom), and every host is already reachable over the tailnet. An orb would put
a sandbox between the agent and that, and a *self-hosted* orb provider needs its
own controller, container runtime, dispatch script and supervised unit to do it.

## Runners

| Runner ID | Host | Directory | Capabilities |
|---|---|---|---|
| `03faddf7-75b0-415f-9b0a-8e2e423608c7` | jason | `/home/andy/projects/homelab` | runner, any-directory, create-worktree |
| `6cf3660f-e1d6-47cc-bada-a4af94ba8b49` | jason | `/home/andy/projects/andrewahale.com` | runner, any-directory, create-worktree |

Both are interactive `amp --no-tui` processes on the desktop; they are not
systemd units, so they come back when Amp is started, not at boot. `ralph` has
no Amp CLI installed, so it has no runner.

## The `home-orbs` registration

Amp's account still lists a personal provider named `home-orbs`, with no orb
types and no active threads, and the account setting `default_orb_provider` also
points at it, so it is the default for any orb thread that does not pick one.
Nothing implements it and nothing should: treat it as an artifact to delete, not
a service to start. See `complete/no-orbs-runners-only-2026-11-08.md`.
