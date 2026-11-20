#!/usr/bin/env bash
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
skill=$here/../SKILL.md
failures=0

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
