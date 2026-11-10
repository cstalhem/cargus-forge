#!/usr/bin/env bash
# Tests for the autopilot-t3 skill: its file, the order of its steps, the plugin README's Autopilot
# section and "What a run does", and the plugin's description.
# They read the repo's files only and need no network.
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

expect "the cloud Autopilot skill's folder is gone" test ! -e "$plugin/skills/autopilot"
expect "no file under the plugin names /engineering:autopilot other than /engineering:autopilot-t3" \
  test -z "$(grep -rElI --exclude=autopilot-t3.test.sh '/engineering:autopilot($|[^-])' "$plugin")"

expect "the skill file exists" test -f "$skill"
if [ ! -f "$skill" ]; then
  echo "1 failed"
  exit 1
fi

# The frontmatter is the text between the first two `---` lines, and the body is the rest.
frontmatter=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1' "$skill")
body=$(awk 'NR > 1 && $0 == "---" { seen = 1; next } seen' "$skill")

expect "the frontmatter has name: autopilot-t3" grep -qx 'name: autopilot-t3' <<<"$frontmatter"
expect "the frontmatter has disable-model-invocation: true" \
  grep -qx 'disable-model-invocation: true' <<<"$frontmatter"
expect "the body injects status.sh as the Facts" \
  grep -qF '!`bash "${CLAUDE_PLUGIN_ROOT}/skills/next/status.sh"`' <<<"$body"

# Each T3 tool the skill uses is named in the body.
for tool in orchestrator_capabilities list_scheduled_tasks schedule_task t3_thread_update \
  t3_thread_list t3_thread_read t3_pending_request t3_thread_send t3_thread_launch; do
  expect "the body names the T3 tool $tool" grep -qF "\`$tool\`" <<<"$body"
done

# The skill checks no surface: it loads each T3 tool where a step first needs it.
expect "the skill has no step that checks the surface it is on" \
  test "$(step_names "$skill" | grep -cxE 'T3|Cloud')" = 0
expect "the skill loads each T3 tool with ToolSearch, query select:mcp__t3-code__" \
  grep -qF 'select:mcp__t3-code__' <<<"$body"
expect "the skill says nothing of a surface check: no 'runs only in a T3 Code thread'" \
  test "$(grep -ciE 'runs only in a T3 Code thread|cloud session' "$skill")" = 0

# None of the cloud session's tools is named anywhere in the file.
for name in list_triggers create_trigger update_trigger list_sessions get_session list_events \
  create_session send_message PushNotification; do
  expect "the skill does not name $name" test "$(grep -cF "$name" "$skill")" = 0
done

# The order of the steps.
expect "the steps end with Merge, Review, Ship, Execute, Nothing to do" \
  test "$(step_names "$skill" | tail -n 5 | joined)" = "Merge,Review,Ship,Execute,Nothing to do"

review=$(step_number "$skill" Review)
ship=$(step_number "$skill" Ship)
execute=$(step_number "$skill" Execute)

expect "the Review step reads the final PRs with pulls?head=" \
  grep -qF 'pulls?head=' <<<"$(step_text "$skill" Review)"
expect "the Ship step makes no pulls?head= read of its own" \
  test "$(step_text "$skill" Ship | grep -cF 'pulls?head=')" = 0

handoff_refs=$(section "$skill" Hand-off | grep -oE 'step [0-9]+' | sort -u)
expect "every step in the Hand-off section is Review's, step $review" \
  test "$handoff_refs" = "step $review"

expect "the steps that start no child for a claimed issue are Ship and Execute, steps $ship and $execute" \
  grep -qF "steps $ship and $execute start no child" "$skill"

# The plugin README has one Autopilot section, for autopilot-t3, with What a run does and the hand-offs table.
expect "the plugin README has one Autopilot section" \
  test "$(grep -c '^## Autopilot' "$readme")" = 1
expect "the plugin README's Autopilot section is headed '## Autopilot'" grep -qx '## Autopilot' "$readme"
autopilot_section=$(section "$readme" Autopilot)
subheadings=$(awk '/^## Autopilot$/ { s = 1; next } /^## / { s = 0 } s && /^### /' "$readme" | joined)
expect "the Autopilot section holds What a run does and the hand-offs table" \
  grep -qF '### What a run does,### The three hand-offs' <<<"$subheadings"
expect "the Autopilot section names /engineering:autopilot-t3" \
  grep -qF '/engineering:autopilot-t3' <<<"$autopilot_section"

# The README's "What a run does" lists the steps in the skill's order.
readme_steps=$(awk '/^### What a run does/ { s = 1; next } /^##/ { s = 0 }
  s && /^[0-9]+\. \*\*[^*]+\*\*/ { n = $0; sub(/^[0-9]+\. \*\*/, "", n); sub(/\*\*.*/, "", n); sub(/\.$/, "", n); print n }' "$readme" | joined)
expect "the README's What a run does lists Plugin, Children, Merge, Review, Ship, Execute" \
  test "$readme_steps" = "Plugin,Children,Merge,Review,Ship,Execute"
expect "the README's Autopilot section says Autopilot merges, comments on a ready PR, then starts children" \
  grep -qF 'comments on a ready single-issue PR or final PR, then starts ship and execute children' "$readme"

# The plugin's description names autopilot-t3 and opens the plugin README; scripts/check-descriptions.sh checks the other listings.
description=$(jq -r .description "$manifest")
expect "plugin.json's description names autopilot-t3" grep -qF 'autopilot-t3' <<<"$description"
expect "plugin.json's description names no cloud skill autopilot" \
  test "$(grep -cF 'next, autopilot, ' <<<"$description")" = 0
expect "the plugin README's first paragraph is plugin.json's description" \
  test "$(sed -n 3p "$readme")" = "$description"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
