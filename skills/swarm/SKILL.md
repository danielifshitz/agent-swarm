---
name: swarm
description: Participate as one assigned agent in an already initialized two-agent swarm run through a filesystem mailbox for grounded planning, adversarial review, or divergence-first brainstorming. Use when the user assigns agent-a or agent-b, asks to begin or continue an existing swarm run, mentions peer mail, or when unread .swarm/mailbox messages exist. Do not use to prepare a new run; use swarm-init instead.
---

# Swarm

Participate as exactly one of two independently running agents.

1. Require an existing `.swarm/` directory and an explicit `agent-a` or
   `agent-b` assignment. Ask if the id is missing; never infer it.
2. Read `.swarm/PROTOCOL.md` completely, then read `ROSTER.md`, `MODE`, and
   `TASK.md`.
3. Run `.swarm/swarm validate` and follow only the selected mode.
4. Use `.swarm/swarm` for all mailbox operations. Never impersonate the peer or
   inspect the peer's inbox.
5. Ground artifact claims with paths and lines and behavior claims with commands
   and results.
6. Respect edit authority and report consensus or stalemate to the user.

In a new brainstorm run, send the independent Round 1 contribution before
reading your inbox. In review mode, inspect files and run checks independently.
