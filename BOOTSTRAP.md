# Agent bootstrap

Prepare a new two-agent swarm run in the workspace where you are currently
working. The user's task is the natural-language request accompanying the URL
to this file.

Do not participate as agent-a or agent-b. Your job ends after returning the two
launch prompts.

1. Resolve the workspace root without asking the user for a path:
   - Use `git rev-parse --show-toplevel` when inside a Git repository.
   - Otherwise use the current working directory.
2. Before installing, check for `.swarm/mailbox/**/*.md` or
   `.swarm/UNRESOLVED.md`. If a prior or active run exists, stop and ask the user
   whether to preserve it in a different location. Never mix run records.
3. Download and inspect the installer from:
   `https://raw.githubusercontent.com/danielifshitz/agent-swarm/main/install.sh`.
4. Run the downloaded installer with the resolved workspace as its explicit
   positional argument and the default adapters. Do not install into the
   agent-swarm source repository unless that is the user's actual workspace.
5. Read the installed `.agents/skills/swarm-init/SKILL.md` completely. If the
   current runtime has not discovered the newly installed skill, follow that
   file directly; do not wait for a restart.
6. Apply those instructions to the user's accompanying task. Infer the internal
   workflow from the requested outcome; never ask the user to choose a protocol
   mode.
7. Write and validate `.swarm/MODE`, `.swarm/TASK.md`, and
   `.swarm/ROSTER.md`, then run `.swarm/swarm prompts`.
8. Return the generated output verbatim in one code block. Tell the user to
   paste the Agent A block into one independent session and the Agent B block
   into another session sharing the same local workspace.

If downloading, installation, or validation fails, report the exact command,
exit status, and error. Do not claim the run is ready.
