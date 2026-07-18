#!/bin/sh
# Install agent-swarm into a workspace.
# Local:  ./install.sh [workspace] [--adapters all|LIST] [--force]
# Remote: curl -fsSL https://raw.githubusercontent.com/danielifshitz/agent-swarm/main/install.sh | sh
set -eu

usage() {
  cat <<'EOF'
Usage: install.sh [WORKSPACE] [--adapters LIST] [--force]

LIST is a comma-separated selection of:
  standard   .agents/skills/{swarm,swarm-init} (cross-agent convention)
  claude     .claude/skills/{swarm,swarm-init}
  cursor     .cursor/rules/{swarm,swarm-init}.mdc
  agents-md  install standard skills and append guarded AGENTS.md guidance
  all        all of the above (default)
  none       protocol files only

Existing TASK.md, ROSTER.md, and MODE are preserved unless --force is used.
Set SWARM_GITHUB_REPO=owner/repo and SWARM_REF=branch for a fork.
EOF
}

target=.
adapters=all
force=0
target_set=0
while [ "$#" -gt 0 ]; do
  case $1 in
    --adapters)
      [ "$#" -ge 2 ] || { printf '%s\n' "error: --adapters needs a value" >&2; exit 2; }
      adapters=$2
      shift 2
      ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *)
      [ "$target_set" -eq 0 ] || { printf '%s\n' "error: only one workspace may be specified" >&2; exit 2; }
      target=$1
      target_set=1
      shift
      ;;
  esac
done

[ "$target_set" -eq 1 ] || {
  if command -v git >/dev/null 2>&1 && git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    target=$git_root
  fi
}
[ -d "$target" ] || { printf 'error: no such workspace: %s\n' "$target" >&2; exit 2; }
target=$(CDPATH= cd -- "$target" && pwd)

script_path=$0
case $script_path in
  */*) source_dir=$(CDPATH= cd -- "$(dirname -- "$script_path")" 2>/dev/null && pwd || true) ;;
  sh|bash|dash|zsh|-*) source_dir= ;;
  *)
    if [ -f "$PWD/$script_path" ]; then
      source_dir=$PWD
    else
      source_dir=
    fi
    ;;
esac

cleanup_dir=
cleanup() {
  if [ -n "$cleanup_dir" ] && [ -d "$cleanup_dir" ]; then
    rm -rf -- "$cleanup_dir"
  fi
}
trap cleanup EXIT HUP INT TERM

if [ -z "$source_dir" ] || [ ! -f "$source_dir/skills/swarm/SKILL.md" ] || [ ! -f "$source_dir/core/swarm" ]; then
  repo=${SWARM_GITHUB_REPO:-danielifshitz/agent-swarm}
  ref=${SWARM_REF:-main}
  cleanup_dir=$(mktemp -d "${TMPDIR:-/tmp}/agent-swarm.XXXXXX")
  archive=$cleanup_dir/source.tar.gz
  url=${SWARM_ARCHIVE_URL:-"https://github.com/$repo/archive/refs/heads/$ref.tar.gz"}
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$archive"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$archive" "$url"
  else
    printf '%s\n' "error: remote install needs curl or wget" >&2
    exit 1
  fi
  tar -xzf "$archive" -C "$cleanup_dir"
  source_dir=
  for candidate in "$cleanup_dir"/*; do
    if [ -d "$candidate" ] && [ -f "$candidate/skills/swarm/SKILL.md" ]; then
      source_dir=$candidate
      break
    fi
  done
  [ -n "$source_dir" ] || { printf '%s\n' "error: downloaded archive has no skill" >&2; exit 1; }
fi

expanded=$adapters
[ "$expanded" = all ] && expanded=standard,claude,cursor,agents-md
old_ifs=$IFS
IFS=,
set -- $expanded
IFS=$old_ifs
for adapter in "$@"; do
  case $adapter in
    standard|claude|cursor|agents-md|none) ;;
    '') printf '%s\n' "error: empty adapter name" >&2; exit 2 ;;
    *) printf 'error: unknown adapter: %s\n' "$adapter" >&2; exit 2 ;;
  esac
done
if [ "$adapters" != none ] && printf '%s' ",$expanded," | grep -q ',none,'; then
  printf '%s\n' "error: 'none' cannot be combined with adapters" >&2
  exit 2
fi

mkdir -p "$target/.swarm/mailbox/agent-a/read" "$target/.swarm/mailbox/agent-b/read"
cp "$source_dir/core/PROTOCOL.md" "$target/.swarm/PROTOCOL.md"
cp "$source_dir/core/swarm" "$target/.swarm/swarm"
chmod 755 "$target/.swarm/swarm"

for name in ROSTER.md TASK.md MODE; do
  if [ ! -e "$target/.swarm/$name" ] || [ "$force" -eq 1 ]; then
    cp "$source_dir/core/$name" "$target/.swarm/$name"
  else
    printf 'preserved: .swarm/%s\n' "$name"
  fi
done

install_skills() {
  skills_root=$1
  for skill_name in swarm swarm-init; do
    destination=$skills_root/$skill_name
    mkdir -p "$destination/agents"
    cp "$source_dir/skills/$skill_name/SKILL.md" "$destination/SKILL.md"
    cp "$source_dir/skills/$skill_name/agents/openai.yaml" "$destination/agents/openai.yaml"
  done
}

standard_installed=0
for adapter in "$@"; do
  case $adapter in
    standard)
      install_skills "$target/.agents/skills"
      standard_installed=1
      ;;
    claude) install_skills "$target/.claude/skills" ;;
    cursor)
      mkdir -p "$target/.cursor/rules"
      cp "$source_dir/adapters/swarm.mdc" "$target/.cursor/rules/swarm.mdc"
      cp "$source_dir/adapters/swarm-init.mdc" "$target/.cursor/rules/swarm-init.mdc"
      ;;
    agents-md)
      if [ "$standard_installed" -eq 0 ]; then
        install_skills "$target/.agents/skills"
        standard_installed=1
      fi
      agents_file=$target/AGENTS.md
      if [ -f "$agents_file" ] && grep -q '<!-- swarm:start -->' "$agents_file"; then
        grep -q '<!-- swarm:end -->' "$agents_file" || {
          printf '%s\n' "error: AGENTS.md has a Swarm start marker without an end marker" >&2
          exit 1
        }
        agents_tmp=$target/.agents-swarm-$$.tmp
        awk -v fragment="$source_dir/adapters/AGENTS.fragment.md" '
          /<!-- swarm:start -->/ {
            while ((getline line < fragment) > 0) print line
            close(fragment)
            skipping = 1
            next
          }
          skipping && /<!-- swarm:end -->/ { skipping = 0; next }
          !skipping { print }
        ' "$agents_file" > "$agents_tmp"
        mv "$agents_tmp" "$agents_file"
      else
        if [ -s "$agents_file" ]; then printf '\n' >> "$agents_file"; fi
        cat "$source_dir/adapters/AGENTS.fragment.md" >> "$agents_file"
      fi
      ;;
    none) ;;
  esac
done

printf 'installed: agent-swarm -> %s\n' "$target"
printf '%s\n' "next: invoke \$swarm-init with your task, or configure .swarm files manually and run .swarm/swarm validate"
