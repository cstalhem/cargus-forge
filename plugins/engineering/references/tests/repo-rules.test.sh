#!/usr/bin/env bash
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../.." && pwd)
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

inject='!`cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md"`'
for s in execute setup anneal verify; do
  skill=$plugin/skills/$s/SKILL.md
  expect "$s injects repo-rules.md under ## Repo rules" \
    bash -c 'awk "/^## Repo rules\$/ { s = 1; next } /^## / { s = 0 } s" "$1" | grep -qxF "$2"' _ "$skill" "$inject"
  expect "$s lists that cat in its allowed-tools" \
    grep -qxF '  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md")' "$skill"
done

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
