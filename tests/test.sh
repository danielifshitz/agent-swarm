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

workspace=$test_root/workspace
mkdir -p "$workspace"
printf '%s\n' '# Existing project instructions' > "$workspace/AGENTS.md"

sh "$repo/install.sh" "$workspace" --adapters all

assert_file "$workspace/.swarm/PROTOCOL.md"
assert_file "$workspace/.swarm/swarm"
assert_file "$workspace/.agents/skills/swarm/SKILL.md"
assert_file "$workspace/.codex/skills/swarm/SKILL.md"
assert_file "$workspace/.claude/skills/swarm/SKILL.md"
assert_file "$workspace/.cursor/rules/swarm.mdc"
grep -q '# Existing project instructions' "$workspace/AGENTS.md" || fail "AGENTS.md content was lost"
grep -q '<!-- swarm:start -->' "$workspace/AGENTS.md" || fail "AGENTS.md adapter missing"

cd "$workspace"
.swarm/swarm validate | grep -q 'ok: swarm workspace'

printf '%s\n' 'CUSTOM TASK CONTENT' > .swarm/TASK.md
sh "$repo/install.sh" "$workspace" --adapters all >/dev/null
grep -q 'CUSTOM TASK CONTENT' .swarm/TASK.md || fail "upgrade overwrote TASK.md"
[ "$(grep -c '<!-- swarm:start -->' AGENTS.md)" -eq 1 ] || fail "duplicate AGENTS.md block"

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
(cd "$remote_workspace" && .swarm/swarm validate >/dev/null)

printf '%s\n' 'PASS: all agent-swarm tests'
