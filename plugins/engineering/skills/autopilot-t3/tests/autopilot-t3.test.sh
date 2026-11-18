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

expect "the skills/autopilot folder is gone" test ! -e "$plugin/skills/autopilot"
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

# #367: the run is on Fable, and every child, execute and ship, is on Sonnet.
expect "the frontmatter holds the line model: fable" grep -qx 'model: fable' <<<"$frontmatter"
children=$(section "$skill" Children)
expect "the Children section reads the Sonnet model for every child" \
  grep -qF 'first read the Sonnet model for the child' <<<"$children"
expect "the Children section passes the Sonnet model as modelSelection for every child" \
  grep -qF -- '- `modelSelection`: `{"instanceId": "<inheritedProviderInstanceId>", "model": "<the Sonnet model id>"}`, for an execute child and a ship child alike.' <<<"$children"
expect "the Children section starts no child when no Sonnet model is found" \
  grep -qF 'If neither call lists a Sonnet model, start no child' <<<"$children"
expect "no line of the skill lets a child start without a model" \
  test "$(grep -cE 'needs no model|Pass no `modelSelection`|inherits (the run|this thread)' "$skill")" = 0
expect "the model check names the child for a ship child as for an execute child" \
  grep -qF "If the child's \`modelSelection.model\` is not the Sonnet model you passed" <<<"$children"
expect "the model check is not for an execute child only" \
  test "$(grep -cF "If an execute child's \`modelSelection.model\`" "$skill")" = 0
proposal_model=$(grep -F -- '- Model and modes:' "$skill")
expect "the proposal's Model and modes line says the skill puts each run's first turn on Fable" \
  grep -qF "the skill puts each run's first turn on Fable" <<<"$proposal_model"
expect "the proposal's Model and modes line says later turns run on the task's model" \
  grep -qF "later turns run on the task's model" <<<"$proposal_model"
expect "the proposal's Model and modes line says every child runs on Sonnet" \
  grep -qF 'every child runs on Sonnet' <<<"$proposal_model"
expect "the proposal's Model and modes line says to run the proposal in a thread on Fable" \
  grep -qF 'Run this first proposal in a thread on Fable' <<<"$proposal_model"

# Each T3 tool the skill uses is named in the body.
for tool in orchestrator_capabilities list_scheduled_tasks schedule_task t3_thread_update \
  t3_thread_list t3_thread_read t3_pending_request t3_thread_send t3_thread_launch; do
  expect "the body names the T3 tool $tool" grep -qF "\`$tool\`" <<<"$body"
done

# The skill checks no surface: it loads each T3 tool where a step first needs it.
expect "the skill has no step that checks the surface it is on" \
  test "$(step_names "$skill" | grep -cx 'T3')" = 0
expect "the skill loads each T3 tool with ToolSearch, query select:mcp__t3-code__" \
  grep -qF 'select:mcp__t3-code__' <<<"$body"
expect "the skill says nothing of a surface check: no 'runs only in a T3 Code thread'" \
  test "$(grep -ci 'runs only in a T3 Code thread' "$skill")" = 0

# None of the removed Autopilot skill's tools is named anywhere in the file.
for name in list_triggers create_trigger update_trigger list_sessions get_session list_events \
  create_session send_message PushNotification; do
  expect "the skill does not name $name" test "$(grep -cF "$name" "$skill")" = 0
done

# #404: a typed umbrella issue scopes the run.
expect "the frontmatter has argument-hint: \"[#umbrella issue]\"" \
  grep -qx 'argument-hint: "\[#umbrella issue\]"' <<<"$frontmatter"
expect "the body holds the line 'Umbrella issue: \$ARGUMENTS', and no other \$ARGUMENTS" \
  bash -c 'grep -qx "Umbrella issue: \$ARGUMENTS" <<<"$1" && test "$(grep -o "\\\$ARGUMENTS" <<<"$1" | wc -l)" = 1' _ "$body"
rules=$(section "$skill" Rules)
expect "the Rules define the scope once" \
  test "$(grep -cF 'an issue is in scope when it is `#<u>` or its Facts line carries `umbrella #<u>`' <<<"$rules")" = 1
expect "the Rules say steps 5 to 9 act only on issues in scope" \
  grep -qF 'Steps 5 to 9 read, answer, hand off, merge, review, ship and execute only issues in scope.' <<<"$rules"
expect "the Rules say the argument is input, not state" grep -qF 'is input, not state' <<<"$rules"
expect "the Rules start no child only while a child in scope is working" \
  grep -qF 'starts none while a child in scope is working' <<<"$rules"
expect "the Scheduled task step reads no scheduled task and asks no question in a run with an argument" \
  grep -qF 'In a run with an argument, read no scheduled task and ask no question: go on to step 4.' <<<"$(step_text "$skill" 'Scheduled task')"
expect "the Facts step stops on an argument that is not an open umbrella issue with sub-issues" \
  grep -qF 'reply `Autopilot: #<u> is not an open umbrella issue with sub-issues; run /engineering:next to see its status.` and stop' <<<"$(step_text "$skill" Facts)"
for step in Children Merge Review Ship Execute; do
  expect "the $step step takes only issues in scope" grep -qF 'in scope' <<<"$(step_text "$skill" "$step")"
done
expect "the Children step leaves a working child that is not in scope alone" \
  grep -qF 'A child whose issue is not in scope is left alone: it does not end the turn' <<<"$(step_text "$skill" Children)"
expect "the Nothing to do step names the umbrella issue in a run with an argument" \
  grep -qF '`Autopilot: nothing to do for #<u>.`' <<<"$(step_text "$skill" 'Nothing to do')"
expect "the Reports section says a run with an argument has no backstop" \
  grep -qF 'A run with an argument has no such backstop' <<<"$(section "$skill" Reports)"

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

# #367: the README names the model of the run, of every child and of a thread started by hand.
expect "the Autopilot section says the run is on Fable" grep -qF 'The run is on Fable' <<<"$autopilot_section"
expect "the Autopilot section says every child is on Sonnet" \
  grep -qF 'every child, execute and ship, is on Sonnet' <<<"$autopilot_section"
expect "the Autopilot section says how to set an existing scheduled task's model to Fable" \
  grep -qF 'set its Model to Fable in its Edit task dialog' <<<"$autopilot_section"
expect "the README says a thread started by hand fits Opus at its default effort, and Sonnet is enough for execute on a sized issue" \
  grep -qF 'A thread you start by hand fits Opus at its default effort, and Sonnet is enough for execute on a sized issue.' "$readme"

# #367 D1: ADR-008's Models part and its rejected alternatives.
adr=$plugin/../../docs/adr/ADR-008-autopilot-builds-ready-issues-unattended.md
models=$(grep -F -- '- **Models.**' "$adr")
expect "ADR-008's Models part puts the run on Fable, by the skill's model line and the scheduled task's model" \
  bash -c 'grep -qF "The run is on Fable" <<<"$1" && grep -qF "skill'"'"'s \`model\` line" <<<"$1" && grep -qF "scheduled task'"'"'s model" <<<"$1"' _ "$models"
expect "ADR-008's Models part puts every child, execute and ship, on the current Sonnet model" \
  grep -qF 'every child, execute and ship, on the current Sonnet model' <<<"$models"
expect "ADR-008's Models part puts verify's grading agent on Opus" grep -qF "verify's grading agent runs on Opus" <<<"$models"
for alt in '**Ship inherits the run'"'"'s model:**' '**The grader inherits its thread'"'"'s model:**' \
  '**The run on Sonnet:**' '**A child'"'"'s report that types the skill' '**A second execute child on a stronger model after a failure:**'; do
  expect "ADR-008 rejects $alt" grep -qF -- "- $alt" "$adr"
done

# #404: the README names the optional umbrella issue argument, and ADR-008 records the typed scope.
expect "the README's command row names the optional #<umbrella issue> argument" \
  bash -c 'grep -F "| \`/engineering:autopilot-t3 [#umbrella issue]\` |" "$1" | grep -qF "\`#<umbrella issue>\`"' _ "$readme"
expect "the README's Autopilot section names /engineering:autopilot-t3 #<umbrella issue>" \
  grep -qF '/engineering:autopilot-t3 #<umbrella issue>' <<<"$autopilot_section"
expect "ADR-008's decision names the typed /engineering:autopilot-t3 #<u>" \
  grep -qF '`/engineering:autopilot-t3 #<u>`, typed by the user, builds only umbrella issue #<u>' "$adr"
for alt in "**The scope in the thread's title:**" '**A lock or claim label for the scoped run:**' \
  '**A backstop scheduled task for each typed run:**' "**A scoped run that waits while another issue's child works:**" \
  '**A feature-branch check in Autopilot:**'; do
  expect "ADR-008 rejects $alt" grep -qF -- "- $alt" "$adr"
done

# The plugin's description names autopilot-t3 and opens the plugin README; scripts/check-descriptions.sh checks the other listings.
description=$(jq -r .description "$manifest")
expect "plugin.json's description names autopilot-t3" grep -qF 'autopilot-t3' <<<"$description"
expect "plugin.json's description names no skill autopilot, only autopilot-t3" \
  test "$(grep -cF 'next, autopilot, ' <<<"$description")" = 0
expect "the plugin README's first paragraph is plugin.json's description" \
  test "$(sed -n 3p "$readme")" = "$description"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
