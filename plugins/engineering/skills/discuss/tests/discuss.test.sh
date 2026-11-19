#!/usr/bin/env bash
# Test for discuss's model line (#357): its frontmatter runs it on Fable. It reads the repo's files only and needs no
# network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
skill=$here/../SKILL.md
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

frontmatter=$(awk '/^---$/ { n++; next } n == 1' "$skill")
expect "the discuss frontmatter holds the line model: fable" grep -qx 'model: fable' <<<"$frontmatter"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
