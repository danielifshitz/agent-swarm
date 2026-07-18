#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/agent-swarm-test.XXXXXX")
cleanup() { rm -rf -- "$test_root"; }
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_file "$repo/BOOTSTRAP.md"
grep -q 'git rev-parse --show-toplevel' "$repo/BOOTSTRAP.md" || fail "bootstrap omits workspace discovery"
grep -q '.agents/skills/swarm-init/SKILL.md' "$repo/BOOTSTRAP.md" || fail "bootstrap omits initializer handoff"
grep -q '.swarm/swarm prompts' "$repo/BOOTSTRAP.md" || fail "bootstrap omits prompt generation"

workspace=$test_root/workspace
mkdir -p "$workspace"
printf '%s\n' '# Existing project instructions' > "$workspace/AGENTS.md"

(cd "$repo" && sh install.sh "$workspace" --adapters all)

assert_file "$workspace/.swarm/PROTOCOL.md"
assert_file "$workspace/.swarm/swarm"
assert_file "$workspace/.agents/skills/swarm/SKILL.md"
assert_file "$workspace/.agents/skills/swarm-init/SKILL.md"
assert_file "$workspace/.claude/skills/swarm/SKILL.md"
assert_file "$workspace/.claude/skills/swarm-init/SKILL.md"
assert_file "$workspace/.cursor/rules/swarm.mdc"
assert_file "$workspace/.cursor/rules/swarm-init.mdc"
[ ! -e "$workspace/.codex/skills/swarm/SKILL.md" ] || fail "redundant Codex skill copy installed"
grep -q '# Existing project instructions' "$workspace/AGENTS.md" || fail "AGENTS.md content was lost"
grep -q '<!-- swarm:start -->' "$workspace/AGENTS.md" || fail "AGENTS.md adapter missing"

cd "$workspace"
workspace=$PWD
if .swarm/swarm validate >/dev/null 2>&1; then
  fail "untouched task template passed validation"
fi
cat > .swarm/TASK.md <<'TASK'
# Task

## Goal

Review the mailbox implementation for correctness. CUSTOM TASK CONTENT

## Artifact

`core/swarm` in the installed test fixture.

## Constraints

Preserve POSIX shell compatibility.

## Definition of done

`sh -n .swarm/swarm` exits zero and both agents disposition all findings.

## Out of scope

Network services and graphical interfaces.
TASK
.swarm/swarm validate | grep -q 'ok: swarm workspace'
.swarm/swarm prompts > "$test_root/review-prompts.txt"
grep -q 'COPY THIS PROMPT TO AGENT A' "$test_root/review-prompts.txt" || fail "Agent A prompt missing"
grep -q 'COPY THIS PROMPT TO AGENT B' "$test_root/review-prompts.txt" || fail "Agent B prompt missing"
grep -q 'You are the author, artifact owner, and starter' "$test_root/review-prompts.txt" ||
  fail "review author prompt is incorrect"
grep -q 'You are the reviewer. Never modify tracked files' "$test_root/review-prompts.txt" ||
  fail "reviewer prompt is incorrect"
grep -q "$workspace" "$test_root/review-prompts.txt" || fail "prompts omit absolute workspace"

printf '%s\n' brainstorm > .swarm/MODE
if .swarm/swarm validate >/dev/null 2>&1; then
  fail "review roles passed brainstorm validation"
fi
sed -e 's/| agent-a | any     | author |/| agent-a | any     | peer   |/' \
    -e 's/| agent-b | any     | reviewer |/| agent-b | any     | peer   |/' \
    .swarm/ROSTER.md > "$test_root/brainstorm-roster.md"
cp "$test_root/brainstorm-roster.md" .swarm/ROSTER.md
.swarm/swarm prompts > "$test_root/brainstorm-prompts.txt"
[ "$(grep -c 'After validation, do not inspect your inbox' "$test_root/brainstorm-prompts.txt")" -eq 2 ] ||
  fail "brainstorm prompts do not protect independent Round 1"
grep -q "roster's ideas_min" "$test_root/brainstorm-prompts.txt" || fail "prompt contains broken apostrophe"
printf '%s\n' review > .swarm/MODE
cp "$repo/core/ROSTER.md" .swarm/ROSTER.md

sed 's/follow `.agents\/skills\/swarm-init\/SKILL.md`/OLD SWARM INSTRUCTIONS/' \
  AGENTS.md > "$test_root/old-agents.md"
cp "$test_root/old-agents.md" AGENTS.md
sh "$repo/install.sh" "$workspace" --adapters all >/dev/null
grep -q 'CUSTOM TASK CONTENT' .swarm/TASK.md || fail "upgrade overwrote TASK.md"
[ "$(grep -c '<!-- swarm:start -->' AGENTS.md)" -eq 1 ] || fail "duplicate AGENTS.md block"
grep -q 'follow `.agents/skills/swarm-init/SKILL.md`' AGENTS.md || fail "AGENTS.md block was not upgraded"
grep -q '# Existing project instructions' AGENTS.md || fail "AGENTS.md upgrade lost user content"

message_one=$(printf '%s\n' 'first body' | .swarm/swarm send \
  --from agent-a --to agent-b --status PROPOSAL --round 1)
message_two=$(printf '%s\n' 'second body' | .swarm/swarm send \
  --from agent-a --to agent-b --status PROPOSAL --round 1)
[ "$message_one" != "$message_two" ] || fail "message filename collision"
[ "$(find .swarm/mailbox/agent-b -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')" -eq 2 ] ||
  fail "expected two unread messages"

.swarm/swarm inbox agent-b | grep -q "$message_one"
.swarm/swarm read agent-b "$message_one" | grep -q 'first body'
.swarm/swarm archive agent-b "$message_one" | grep -q 'archived:'
assert_file ".swarm/mailbox/agent-b/read/$message_one"

if printf '%s\n' bad | .swarm/swarm send \
  --from agent-a --to agent-b --status AGREEMENT --round 2 >/dev/null 2>&1; then
  fail "AGREEMENT without Final-Ref succeeded"
fi

if printf '%s\n' bad | .swarm/swarm send \
  --from agent-a --to .. --status QUESTION --round 2 >/dev/null 2>&1; then
  fail "path-traversal agent id succeeded"
fi

if .swarm/swarm wait agent-a 0 >/dev/null 2>&1; then
  fail "empty wait did not time out"
else
  status=$?
  [ "$status" -eq 124 ] || fail "empty wait returned $status instead of 124"
fi

incoming=$(printf '%s\n' 'ready' | .swarm/swarm send \
  --from agent-b --to agent-a --status QUESTION --round 2)
[ "$(.swarm/swarm wait agent-a 1)" = "$incoming" ] || fail "wait returned wrong message"

.swarm/swarm transcript > "$test_root/transcript.txt"
grep -q 'first body' "$test_root/transcript.txt" || fail "transcript omitted archived mail"
grep -q 'second body' "$test_root/transcript.txt" || fail "transcript omitted unread mail"

invalid_workspace=$test_root/invalid
mkdir -p "$invalid_workspace"
if sh "$repo/install.sh" "$invalid_workspace" --adapters imaginary >/dev/null 2>&1; then
  fail "unknown adapter succeeded"
fi
[ ! -e "$invalid_workspace/.swarm" ] || fail "invalid install mutated workspace"

archive=$test_root/source.tar.gz
tar -czf "$archive" -C "$(dirname -- "$repo")" "$(basename -- "$repo")"
remote_workspace=$test_root/remote
mkdir -p "$remote_workspace"
SWARM_ARCHIVE_URL="file://$archive" sh -s -- "$remote_workspace" --adapters none \
  < "$repo/install.sh" >/dev/null
assert_file "$remote_workspace/.swarm/swarm"
cp "$workspace/.swarm/TASK.md" "$remote_workspace/.swarm/TASK.md"
(cd "$remote_workspace" && .swarm/swarm validate >/dev/null)

git_workspace=$test_root/git-workspace
mkdir -p "$git_workspace/nested"
git init -q "$git_workspace"
(cd "$git_workspace/nested" && \
  SWARM_ARCHIVE_URL="file://$archive" sh -s -- --adapters none < "$repo/install.sh" >/dev/null)
assert_file "$git_workspace/.swarm/swarm"
[ ! -e "$git_workspace/nested/.swarm" ] || fail "automatic install ignored Git root"

agents_workspace=$test_root/agents-only
mkdir -p "$agents_workspace"
sh "$repo/install.sh" "$agents_workspace" --adapters agents-md >/dev/null
assert_file "$agents_workspace/.agents/skills/swarm-init/SKILL.md"
grep -q '<!-- swarm:start -->' "$agents_workspace/AGENTS.md" || fail "agents-md guidance missing"

printf '%s\n' 'PASS: all agent-swarm tests'
