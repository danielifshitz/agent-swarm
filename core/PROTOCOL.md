# Swarm Protocol v2

Two AI agents collaborate in one workspace through files. The protocol requires
only a shared filesystem and a POSIX shell; it does not depend on a model,
vendor, server, daemon, or API.

## 1. Start safely

Before changing the task artifact:

1. Read `.swarm/ROSTER.md`, `.swarm/MODE`, and `.swarm/TASK.md`.
2. Read the section below for the selected mode.
3. Determine your agent id from the user's instruction. If it is not explicit,
   stop and ask. Never infer it from runtime names or roster order.
4. Run `.swarm/swarm validate`.
5. Follow the selected mode's launch behavior. In plan and review, check your
   inbox. In a new brainstorm run, send your independent Round 1 contribution
   before reading the peer's mail.

Do not continue alone after a run has started. A missing or timed-out peer is an
outcome to report, not permission to impersonate it.

## 2. Mailbox contract

Each agent has one inbox. Only its owner reads and archives it; only the peer
writes to it.

```text
.swarm/mailbox/agent-a/       agent-b writes; agent-a reads
.swarm/mailbox/agent-a/read/  processed messages
.swarm/mailbox/agent-b/       agent-a writes; agent-b reads
.swarm/mailbox/agent-b/read/  processed messages
```

Use `.swarm/swarm`; do not hand-create final message files.

```sh
printf '%s\n' 'Proposed change, grounded at docs/plan.md:34.' |
  .swarm/swarm send --from agent-a --to agent-b \
    --status PROPOSAL --round 1

.swarm/swarm wait agent-a 900
.swarm/swarm inbox agent-a
.swarm/swarm read agent-a MESSAGE_FILENAME.md
.swarm/swarm archive agent-a MESSAGE_FILENAME.md
```

`send` writes in the destination directory and atomically renames a uniquely
named temporary file. Messages are immutable. `archive` only moves a processed
message into `read/`; it never deletes it.

`.swarm/swarm transcript` reads both mailboxes. It is for the human or the final
handoff; agents must not use it during an active run to inspect the peer's
unread inbox.

The human can run `.swarm/swarm prompts` after preparing MODE, TASK, and ROSTER
to print the two mode-aware launch prompts verbatim.

### Message format

```text
From: <agent-id>
To: <agent-id>
Status: PROPOSAL | QUESTION | RESPONSE | OBJECTION | VERIFICATION | FINAL | AGREEMENT | STALEMATE
Round: <positive integer>
Final-Ref: <FINAL filename, required for AGREEMENT>

<focused body>
```

The CLI writes the first four headers. Pass `--final-ref` for an `AGREEMENT`.
Reference artifacts as `path:line`. Do not copy large file contents into mail.

## 3. Grounding and verification

Every claim about an artifact must be traceable to it.

- Cite objections with exact `path:line` locations.
- For behavioral claims, provide the command, material output, and exit status.
- In review mode, inspect the diff and files yourself and run relevant tests.
  The author's summary is orientation, not evidence.
- If a check cannot run, state why and what remains unverified.

## 4. Rounds and endings

A round is one discussion stage. Each agent may send at most one substantive
message in a round. In plan and review, the starter sends first and the peer
responds with the same round number. In brainstorm, both send independently in
each round. Increment after both agents have sent for the current round.

`round_cap` is the highest allowed round number and includes FINAL,
VERIFICATION, and AGREEMENT traffic. Reserve enough rounds for the ending. If
the cap is reached without a valid ending, use STALEMATE.

### Consensus ending

1. One agent sends `FINAL`. Its filename is the final identifier.
2. The peer's first response to that FINAL must be `VERIFICATION` or a grounded
   `OBJECTION`, never `AGREEMENT`.
3. After any objections are resolved, both agents send `AGREEMENT` with the
   same `Final-Ref`.
4. Each AGREEMENT enumerates every objection and its disposition: accepted,
   rejected with reason, or obsolete.

Agreement means the agents accept the recorded result. In brainstorm mode it
does not mean they prefer the same ideas; a FINAL may preserve disagreement.

### Stalemate ending

Use `STALEMATE` when the round cap is reached, a blocking disagreement remains,
or the peer times out. The first agent to identify the ending writes
`.swarm/UNRESOLVED.md` with each position, its grounding, and what evidence or
human decision could settle it. Both agents send STALEMATE when possible, then
stop and report the outcome.

## 5. Modes

### plan

- Both agents are peers; the roster's `starter` opens.
- Neither agent edits the artifact during discussion.
- Examine assumptions, dependencies, sequencing, failure modes, rollback, and
  verification criteria.
- FINAL contains the complete revised plan or an edit list precise enough to
  determine it uniquely.
- Only after the consensus ending may `artifact_owner` apply the agreed edits.

### review

- The roster must have exactly one `author` and one `reviewer`; the author must
  also be `artifact_owner` and `starter`.
- The reviewer never modifies tracked files. The author may update the reviewed
  files between rounds in response to findings.
- The author opens with a short map: intent, diff scope, files, and test command.
- The reviewer independently inspects and sends numbered findings. Every
  finding has severity `blocking`, `major`, or `nit`, a location, and evidence.
- The author answers every finding by number: accept and fix, or reject with a
  reason. The reviewer verifies accepted fixes.
- FINAL is the disposition list for every finding. Agreement accepts those
  dispositions, not a blanket claim that the code is flawless.
- A rejected blocking finding requires the reviewer's explicit acceptance of
  the reason; otherwise end in STALEMATE.

### brainstorm

- Both agents are peers and do not edit a task artifact during discussion.
- Round 1 is independent: send your own ideas before reading the peer's mail.
- Each Round 1 message contains at least `ideas_min` one-line ideas.
- Rounds 1 and 2 only generate, combine, and extend. Do not evaluate.
- Round 3 onward may evaluate with grounded reasoning.
- FINAL categorizes ideas as `promising`, `needs-work`, `rejected` (with reason),
  or `unresolved-disagreement` (with both positions).
- After a consensus ending, `artifact_owner` writes the categorized result only
  if TASK names an output artifact.

## 6. Human handoff

Always report whether the run reached consensus or stalemate, identify the
FINAL or `.swarm/UNRESOLVED.md`, and mention `.swarm/swarm transcript` as the
complete record.
