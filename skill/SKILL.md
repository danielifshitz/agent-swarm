---
name: swarm
description: Coordinate two AI agents working in one shared workspace through a filesystem mailbox for grounded planning, adversarial code review, or divergence-first brainstorming. Use when a user asks to work with another agent or session, mentions agent-a/agent-b or a peer agent, requests pair planning or agent-to-agent review, or when a .swarm directory or unread .swarm/mailbox message exists.
---

# Swarm

Coordinate exactly two independently running agents through `.swarm/mailbox`.

1. If `.swarm/` is absent, tell the user to initialize the workspace with the
   repository installer. Do not invent protocol files.
2. Read `.swarm/PROTOCOL.md` completely before task work.
3. Read `.swarm/ROSTER.md`, `.swarm/MODE`, and `.swarm/TASK.md`.
4. Determine the explicit agent id. Ask the user if it is unknown; never guess.
5. Run `.swarm/swarm validate`, then follow only the selected mode section.
6. Use `.swarm/swarm` for sending, waiting, reading, archiving, and transcripts.

Never impersonate a missing peer. Never hand-write mailbox messages. In review
mode, inspect files and run checks independently. Respect the mode's edit
authority and ending rules. Report consensus or stalemate to the user.
