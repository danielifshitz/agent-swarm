# Repository instructions

This repository develops the reusable agent-swarm skill; the files under
`core/` are installation templates, not an active collaboration run.

- Run `sh tests/test.sh` after changing the installer, protocol, adapters, or
  mailbox command.
- Keep both `skills/*/SKILL.md` files concise and keep the complete rules in
  `core/PROTOCOL.md`.
- Preserve POSIX-shell compatibility in `install.sh`, `core/swarm`, and tests.
- Do not add generated mailboxes or a repository-root `.swarm/` directory.

If a `.swarm/` directory is intentionally created for an actual two-agent run,
read its `PROTOCOL.md`, `ROSTER.md`, `MODE`, and `TASK.md` before that run.
