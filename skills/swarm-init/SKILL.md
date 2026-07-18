---
name: swarm-init
description: Initialize a new two-agent swarm run from the user's natural-language goal by inferring the appropriate internal workflow; writing concrete .swarm/MODE, TASK.md, and mode-correct ROSTER.md files; validating the setup; and producing exact copy-and-paste launch prompts for agent-a and agent-b. Use when the user asks to prepare, configure, initialize, or start a new swarm collaboration, or asks what prompts to give the two agents. Do not use to participate in an active run.
---

# Initialize a swarm run

Prepare the run, but do not participate as either agent.

1. Locate the intended workspace. If `.swarm/` is absent, install agent-swarm
   into it before continuing:
   `curl -fsSL https://raw.githubusercontent.com/danielifshitz/agent-swarm/main/install.sh | sh -s -- WORKSPACE`.
2. Check both mailbox trees and `.swarm/UNRESOLVED.md`. If any prior-run record
   exists, stop and ask the user to preserve or reset it; never mix runs.
3. Derive the intended deliverable from the user's natural-language request and
   inspect relevant workspace files read-only. Do not ask the user to choose a
   protocol mode. Ask one focused question only when the deliverable or scope
   itself cannot be inferred safely.
4. Infer and record one internal mode without presenting the choice to the user:
   - `review`: assess existing code or changes; agent-a authors fixes and
     agent-b independently reviews.
   - `plan`: converge on an implementation, migration, or decision plan without
     editing the artifact during discussion.
   - `brainstorm`: generate diverse possibilities before evaluation.
5. Write `.swarm/MODE` as exactly the mode word plus a newline.
6. Replace every placeholder in `.swarm/TASK.md` with concrete content under
   `Goal`, `Artifact`, `Constraints`, `Definition of done`, and `Out of scope`.
   Name exact paths, diff scopes, and verification commands when discoverable.
   Write “None specified” only when a section genuinely has no constraint.
7. Normalize `.swarm/ROSTER.md`:
   - review: agent-a=`author`, agent-b=`reviewer`, starter and artifact owner are
     agent-a.
   - plan or brainstorm: both agents=`peer`, starter and artifact owner are
     agent-a.
   - Keep ids `agent-a` and `agent-b`, `round_cap: 8`, `ideas_min: 7`, and
     `wait_timeout: 900` unless the user explicitly requests other values.
8. Run `.swarm/swarm validate`. Fix setup errors before proceeding.
9. Run `.swarm/swarm prompts` and return its output verbatim in one code block.
   Do not paraphrase, shorten, or add instructions inside the generated prompts.

End by telling the user to paste the Agent A block into one independent session
and the Agent B block into another.
