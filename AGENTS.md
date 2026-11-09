# Agents

This is a codebase for a homelab. For my homelab.

Always work out machine you are currently running on. `hostname` is the answer; the table below maps it to the machine.

It should use the following:
- Proton VPN
- Proton Drive
- Proton Pass
- Cloudflare

Everything should be documented, be agent friendly, and grounded with latest information.

## Security Posture

- Nothing listens on the WAN. Ingress is one outbound Cloudflare tunnel on Ralph, and origin services bind loopback.
- Firewalls allow per service and both hosts have ufw on.
- Human credentials live in Proton Pass.
- Tailnet SSH authenticates by identity.

## Which machine am I on?

| Host | `hostname` | Hardware | OS / arch | Role |
|---|---|---|---|---|
| **Jason** | `jason` | Desktop, RTX 3070 | Omarchy (Arch), x86_64 | YOLO fine-tuning for the Petcam; the `amp --no-tui` runner that reaches Tom and Ralph over the tailnet |
| **Ralph** | `ralph` | Dell OptiPlex 7070 Micro (i5-9500T, 16GB, 256GB NVMe) | Arch, `linux-lts`, x86_64 | The always-on server and public gateway: Jellyfin, qBittorrent, DHT sensor, fail2ban, media library, website, and the only Cloudflare tunnel |
| **Tom** | `tom` | Raspberry Pi 5 | Debian 13 (trixie), aarch64 | Only the Petcam camera: 1 fps stream + stills on the tailnet (`:8081`), which Ralph pulls and proxies. No detector, no web app, no nginx |
| **Rose** | `rose` | Laptop | not yet recorded — check on the box | Jellyfin with the TV, standing in for the Google Streamer for now |

Confirm in one line — prints e.g. `jason x86_64 Omarchy`:

```bash
printf '%s %s %s\n' "$(hostname)" "$(uname -m)" "$(. /etc/os-release; echo "$PRETTY_NAME")"
```

- SSH aliases land elsewhere: `tom` (`tom.tailad1015.ts.net`, user `tom`), `tom-lan` (`192.168.1.24`), `ralph` (`ralph.tailad1015.ts.net`, user `andy`). Commands run there act on that host, not on the session's host.
- If `hostname` is none of the four, it is an unrecorded machine: stop and ask, do not guess.
- Per-machine detail: `docs/ralph/README.md`, `docs/server/README.md` (Tom), `docs/petcam/README.md`.

All machines are on the same network and have an internet speed of at most 100mbit down/25mbit up.

## Detailed Todos and Tickets

The TODO.md is very high level and is intended for humans. When TODO items are too large and must be planned and broken down they should go into ./docs/{project}/todo/{brief}.md.

When they are done they should be moved to ./docs/{project}/complete/{brief}-{date}.md because they are completed.

## Decisions

When we complete tasks and make decisions we should add a new file that describes the decision and why it was made, and the task that was complete and the reason why.

These should live in the ./docs/{project}/complete/{brief}-{date}.md.

When decisions are made we need to update relevant README.md files for the project.

## Bootstrap

The homelab must be simple to bootstrap at any time. If the Raspberry Pi dies it should be very simple to move to Jason or Rose.

## Amp

Do not use ORBS — never, including self-hosted providers. Depend on runners
directly: `amp --no-tui` on Jason, which reaches Tom and Ralph over the tailnet.
See docs/amp/README.md.

## Deployment

Deploying code for this project should be using `ssh` with `git pull` and make for the website.
For the model retraining it should `scp` the new model directly to Tom from Jason.

## Research

To research and understand problems, decisions, tasks please use Chrome MCP and Web Search!
