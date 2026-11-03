#!/usr/bin/env bash
# Tests for the order of the steps in the autopilot and autopilot-t3 skills, and for the plugin README's
# "What a run does". They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
readme=$plugin/README.md
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

# step_names <file>: the name of each numbered step under `## Steps`, one per line, such as `Merge`.
step_names() {
  awk '/^## Steps/ { s = 1; next } /^## / { s = 0 }
    s && /^[0-9]+\. \*\*[^*]+\*\*/ { n = $0; sub(/^[0-9]+\. \*\*/, "", n); sub(/\*\*.*/, "", n); sub(/\.$/, "", n); print n }' "$1"
}

# step_number <file> <name>: the number of the step with that name.
step_number() {
  awk -v name="$2" '/^## Steps/ { s = 1; next } /^## / { s = 0 }
    s && index($0, "**" name ".**") && match($0, /^[0-9]+\./) { print substr($0, 1, RLENGTH - 1) }' "$1"
}

# step_text <file> <name>: the text of the step with that name, up to the next numbered step.
step_text() {
  awk -v name="$2" '/^## / { s = 0 }
    /^[0-9]+\. \*\*/ { s = index($0, "**" name ".**") > 0 }
    s' "$1"
}

# section <file> <heading>: the text under a `## ` heading, up to the next one.
section() {
  awk -v h="## $2" '$0 == h { s = 1; next } /^## / { s = 0 } s' "$1"
}

# joined: reads lines on stdin and prints them joined with commas.
joined() { paste -sd, -; }

for variant in autopilot autopilot-t3; do
  skill=$plugin/skills/$variant/SKILL.md
  expect "$variant: the skill file exists" test -f "$skill"
  [ -f "$skill" ] || continue

  expect "$variant: the steps end with Merge, Review, Ship, Execute, Nothing to do" \
    test "$(step_names "$skill" | tail -n 5 | joined)" = "Merge,Review,Ship,Execute,Nothing to do"

  review=$(step_number "$skill" Review)
  ship=$(step_number "$skill" Ship)
  execute=$(step_number "$skill" Execute)

  expect "$variant: the Review step reads the final PRs with pulls?head=" \
    grep -qF 'pulls?head=' <<<"$(step_text "$skill" Review)"
  expect "$variant: the Ship step makes no pulls?head= read of its own" \
    test "$(step_text "$skill" Ship | grep -cF 'pulls?head=')" = 0

  handoff_refs=$(section "$skill" Hand-off | grep -oE 'step [0-9]+' | sort -u)
  expect "$variant: every step in the Hand-off section is Review's, step $review" \
    test "$handoff_refs" = "step $review"

  expect "$variant: the steps that start no child for a claimed issue are Ship and Execute, steps $ship and $execute" \
    grep -qF "steps $ship and $execute start no child" "$skill"
done

# The README's "What a run does" lists the steps in the skills' order, and the T3 section says so too.
readme_steps=$(awk '/^### What a run does/ { s = 1; next } /^##/ { s = 0 }
  s && /^[0-9]+\. \*\*[^*]+\*\*/ { n = $0; sub(/^[0-9]+\. \*\*/, "", n); sub(/\*\*.*/, "", n); sub(/\.$/, "", n); print n }' "$readme" | joined)
expect "the README's What a run does lists Plugin, Children, Merge, Review, Ship, Execute" \
  test "$readme_steps" = "Plugin,Children,Merge,Review,Ship,Execute"
expect "the README's T3 section says Autopilot merges, comments on a ready PR, then starts children" \
  grep -qF 'comments on a ready single-issue PR or final PR, then starts ship and execute children' "$readme"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
