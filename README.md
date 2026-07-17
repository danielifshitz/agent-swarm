# agent-swarm

A portable skill for two AI agents collaborating in one workspace. Agents plan,
review, or brainstorm through an auditable filesystem mailbox—without a server,
daemon, API, or vendor-specific runtime.

It works with any agent that can read workspace files and run a POSIX-style
shell. Project-local skill adapters are installed for the cross-agent
`.agents/skills` convention, Codex, Claude Code, and Cursor.

## Install

From a clone:

```sh
git clone https://github.com/danielifshitz/agent-swarm.git
agent-swarm/install.sh /path/to/your/workspace
```

Or directly into the current workspace:

```sh
curl -fsSL https://raw.githubusercontent.com/danielifshitz/agent-swarm/main/install.sh | sh
```

The remote command defaults to the current directory. To target another one:

```sh
curl -fsSL https://raw.githubusercontent.com/danielifshitz/agent-swarm/main/install.sh |
  sh -s -- /path/to/your/workspace
```

For a fork, set `SWARM_GITHUB_REPO=owner/repository` and optionally
`SWARM_REF=branch`. Packagers can set `SWARM_ARCHIVE_URL` to a complete source
archive URL.

## Start a run

1. Fill in `.swarm/TASK.md`.
2. Set the two agents and parameters in `.swarm/ROSTER.md`.
3. Choose a mode:

   ```sh
   printf '%s\n' review > .swarm/MODE
   # or: plan / brainstorm
   ```

4. Check the workspace:

   ```sh
   .swarm/swarm validate
   ```

5. Open two independent agent sessions and assign identities explicitly:

   - “You are agent-a. Read `.swarm/PROTOCOL.md` completely and begin.”
   - “You are agent-b. Read `.swarm/PROTOCOL.md` completely and begin.”

Never let sessions infer their identities.

## Mailbox command

Agents use one command for all channel operations:

```sh
printf '%s\n' 'Finding grounded at src/auth.py:88.' |
  .swarm/swarm send --from agent-b --to agent-a \
    --status OBJECTION --round 1

.swarm/swarm inbox agent-a
.swarm/swarm wait agent-a 900
.swarm/swarm read agent-a MESSAGE_FILENAME.md
.swarm/swarm archive agent-a MESSAGE_FILENAME.md
.swarm/swarm transcript
```

Run `.swarm/swarm help` for the complete command list.

## Installation options

```sh
./install.sh . --adapters all
./install.sh . --adapters standard,codex
./install.sh . --adapters none
./install.sh . --force
```

Adapters:

| Name | Installed path |
|---|---|
| `standard` | `.agents/skills/swarm/` |
| `codex` | `.codex/skills/swarm/` |
| `claude` | `.claude/skills/swarm/` |
| `cursor` | `.cursor/rules/swarm.mdc` |
| `agents-md` | guarded instructions appended to `AGENTS.md` |

Re-running the installer upgrades the protocol, command, and adapters while
preserving `.swarm/TASK.md`, `.swarm/ROSTER.md`, and `.swarm/MODE`. Use
`--force` only when you intentionally want to reset those three files.

## Modes

- `plan`: symmetric critique followed by an agreed plan or precise edit list.
- `review`: an author fixes numbered findings from a read-only reviewer.
- `brainstorm`: independent generation first, evaluation later, disagreements
  preserved rather than forced into consensus.

All modes require evidence-backed claims, prohibit first-response agreement to a
FINAL, and preserve either a consensus record or a documented stalemate.

## Development

```sh
sh tests/test.sh
```

The test performs clean installation, upgrade-preservation, mailbox, collision,
timeout, adapter, validation, and transcript checks in temporary workspaces.

## License

MIT
