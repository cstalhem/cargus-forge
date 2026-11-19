#!/usr/bin/env bash
# Tests for the autopilot-t3 skill: it is typed only, and the plugin README's first paragraph is the plugin's
# description. They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
skill=$plugin/skills/autopilot-t3/SKILL.md
readme=$plugin/README.md
manifest=$plugin/.claude-plugin/plugin.json
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

frontmatter=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1' "$skill")
expect "the frontmatter has disable-model-invocation: true" \
  grep -qx 'disable-model-invocation: true' <<<"$frontmatter"

description=$(jq -r .description "$manifest")
expect "the plugin README's first paragraph is plugin.json's description" \
  test "$(sed -n 3p "$readme")" = "$description"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
