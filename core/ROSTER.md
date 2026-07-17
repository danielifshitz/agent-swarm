# Roster

Edit before starting. Agents read this file and do not modify it during a run.
Keep the protocol ids `agent-a` and `agent-b`; change runtimes and roles as
needed, and assign those ids explicitly when opening the two sessions.

## Agents

| id      | runtime | role   |
|---------|---------|--------|
| agent-a | any     | author |
| agent-b | any     | reviewer |

Use `author` and `reviewer` only in review mode. Use `peer` for both agents in
plan and brainstorm modes.

## Parameters

- starter: agent-a
- artifact_owner: agent-a
- round_cap: 8
- ideas_min: 7
- wait_timeout: 900
