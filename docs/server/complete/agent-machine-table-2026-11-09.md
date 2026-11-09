# AGENTS.md: how an agent tells which machine it is on (2026-11-09)

## Task

TODO: "Update AGENTS.md with a table to help agents understand which machine
they are on. Rose, Jason, Tom, or Ralph."

Trigger: agents kept attributing facts to the wrong host (one recorded case in
`../todo/runbook-bootstrap-audit-2026-11-08.md`: `~/petcam-train` assumed on
Rose, actually on Jason). "Where things run" was prose, so it read fine and
identified nothing.

## Decision

One table in `AGENTS.md` keyed on `hostname`, one command to produce the key:

```bash
printf '%s %s %s\n' "$(hostname)" "$(uname -m)" "$(. /etc/os-release; echo "$PRETTY_NAME")"
```

| Host | `hostname` | Hardware | OS / arch |
|---|---|---|---|
| Jason | `jason` | Desktop, RTX 3070 | Omarchy (Arch), x86_64 |
| Ralph | `ralph` | OptiPlex 7070 Micro | Arch `linux-lts`, x86_64 |
| Tom | `tom` | Raspberry Pi 5 | Debian 13, aarch64 |
| Rose | `rose` | Laptop | not yet recorded |

Why this and not more:

- **`hostname` alone as the key.** It is the one thing every agent can read on
  every host without a tool, and on this house it is already the real name
  (`jason`, `ralph`, `tom`, `rose` on the tailnet). No inventory file, no lookup
  script, nothing to keep in sync.
- **Roles folded into the table** instead of kept as a second prose section.
  Two lists of the same four machines drift; one table cannot.
- **"If it is none of the four, stop and ask."** Cheaper than an exhaustive
  machine-identification heuristic, and the failure mode (a fifth box appears)
  is a question, not a guess.
- **SSH aliases called out**, because the expensive mistake is running a command
  through `ssh tom ...` and then reporting it as local. `tom`/`tom-lan`/`ralph`
  and their users are listed next to the table.
- **Rose left as "not yet recorded" rather than invented.** Its distro is
  unverified and nothing in the repo says otherwise; a made-up `Omarchy` row is
  exactly the wrong-host error this task exists to stop. Fill it in the next
  time someone is on the laptop.

Per-machine depth stays where it already is — `docs/ralph/README.md`,
`docs/server/README.md` (Tom), `docs/petcam/README.md` — and the table links
them, so `AGENTS.md` does not grow a fourth copy of the inventory.

## Verified

On Jason, 2026-11-09:

```
$ printf '%s %s %s\n' "$(hostname)" "$(uname -m)" "$(. /etc/os-release; echo "$PRETTY_NAME")"
jason x86_64 Omarchy
```

Ralph/Tom rows are taken from `docs/ralph/README.md` and `docs/server/README.md`;
`tailscale status` agrees on the four peer names.

No decision record was previously needed for the order of the machines, only
for their identity — nothing else in the repo changed.
