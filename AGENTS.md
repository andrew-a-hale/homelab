# Agents

This is a codebase for a homelab. For my homelab.

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

## Where things run

**Tom** (Raspberry Pi 5) now runs only the Petcam camera: it serves the 1 fps stream and stills on the tailnet (`:8081`), and Ralph pulls and proxies them.
no detector, no web app, no nginx.

**Jason** (Desktop) does YOLO model fine tuning for the Petcam.

**Rose** (Laptop) uses jellyfin with TV in place of the Google Streamer TV solution temporarily.

**Ralph** (Dell OptiPlex 7070 Micro, Arch) is the always-on server and the public gateway: Jellyfin, qBittorrent, DHT Sensor, fail2ban, the media library, the website, and the only Cloudflare tunnel.

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
