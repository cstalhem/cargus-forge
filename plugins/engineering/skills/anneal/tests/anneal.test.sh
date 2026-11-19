#!/usr/bin/env bash
# Tests for the anneal skill's wiring: its injected commands with their allowed-tools entry, and that it is typed
# only. They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
skill=$plugin/skills/anneal/SKILL.md
failures=0

# expect <description> <command...>: the command must succeed.
expect() {
  local desc=$1
  shift
  if "$@"; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc"
    failures=$((failures + 1))
  fi
}

expect "the skill file exists" test -f "$skill"
if [ ! -f "$skill" ]; then
  echo "1 failed"
  exit 1
fi

frontmatter=$(awk '/^---$/ { n++; next } n == 1' "$skill")

expect "the Facts fetch origin main and print the SHAs of HEAD and origin/main" \
  grep -qF '!`git fetch -q origin main && git rev-parse HEAD origin/main`' "$skill"
expect "the allowed-tools line lets the skill run that fetch" \
  grep -qF 'Bash(git fetch -q origin main && git rev-parse HEAD origin/main)' "$skill"
expect "the glossary and git ls-files are injected" \
  bash -c 'grep -qF "!\`cat docs/glossary.md" "$1" && grep -qF "!\`git ls-files\`" "$1"' _ "$skill"
expect "the frontmatter has disable-model-invocation: true" \
  grep -qxF 'disable-model-invocation: true' <<<"$frontmatter"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
