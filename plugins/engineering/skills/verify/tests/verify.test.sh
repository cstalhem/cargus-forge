#!/usr/bin/env bash
# Tests for verify's merge risk: the grading agent's task in step 3, the report format, the order of the
# report in step 4, the two steps that say the risk changes no verdict and no ready mark, the glossary
# entry and the plugin README.
# They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
skill=$plugin/skills/verify/SKILL.md
readme=$plugin/README.md
glossary=$root/docs/glossary.md
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

step3=$(sed -n '/^3\. \*\*Grade\.\*\*/,/^4\. \*\*Checks\.\*\*/p' "$skill" | sed '$d')
step4=$(sed -n '/^4\. \*\*Checks\.\*\*/,/^5\. \*\*Post\.\*\*/p' "$skill" | sed '$d')
step6=$(sed -n '/^6\. \*\*Result\.\*\*/,/^## Repo rules$/p' "$skill" | sed '$d')
report=$(sed -n '/^     ## verify: /,/^     ### Verify commands$/p' "$skill")

# Step 3: the four categories and their ratings.
expect "step 3 rates Alignment as poor / decent / good" grep -qF '**Alignment** (poor / decent / good)' <<<"$step3"
expect "step 3 rates Impact as large / medium / small" grep -qF '**Impact** (large / medium / small)' <<<"$step3"
expect "step 3 rates Rollback cost as high / medium / low" grep -qF '**Rollback cost** (high / medium / low)' <<<"$step3"
expect "step 3 rates Error detection as poor / decent / good / N/A" \
  grep -qF '**Error detection** (poor / decent / good / N/A)' <<<"$step3"
expect "step 3 has no category called Verification" bash -c '! grep -qi "verification" <<<"$1"' _ "$step3"

# Step 3: the level.
expect "step 3 gives the level rule: high at two worst ratings, medium at one worst or two middle, low otherwise, N/A as good" \
  grep -qF 'high when two or more categories have their worst rating (poor, large, high, poor), medium when one does or when two or more have their middle rating (decent, medium, medium, decent), low otherwise. N/A counts as good.' <<<"$step3"

# Step 3: what each category looks at.
expect "Alignment names the PR's What it delivers bullets and Deviations lines" \
  grep -qF 'named by a `## What it delivers` bullet or a `## Deviations` line of the PR' <<<"$step3"
expect "Alignment in umbrella scope names the scenarios, the decisions and the merged sub-issue PRs' Deviations lines" \
  grep -qF "named by the umbrella's scenarios, its decisions or the \`## Deviations\` lines of the merged sub-issue PRs" <<<"$step3"
expect "Alignment is poor for an unnamed change to behaviour and decent for one to text or formatting" \
  bash -c 'grep -qF "Poor when an unnamed change touches behaviour" <<<"$1" && grep -qF "decent when an unnamed change touches only text or formatting" <<<"$1"' _ "$step3"
expect "Impact names the files that every later agent session loads" \
  grep -qF '`.claude/rules/`, CLAUDE.md, a skill'"'"'s `allowed-tools`, hooks, CI workflows' <<<"$step3"
expect "Error detection is N/A when the change cannot fail at runtime" \
  grep -qF 'N/A when the change cannot fail at runtime' <<<"$step3"
expect "step 3 names the source of the category text in one line" \
  test "$(grep -cF 'https://github.com/warpdotdev/common-skills/blob/main/.agents/skills/merge-risk/SKILL.md' "$skill")" -eq 1
expect "the source line credits Matt Pocock's pr skill" \
  bash -c 'grep -F "warpdotdev/common-skills" "$1" | grep -qF "Matt Pocock'"'"'s \`pr\` skill"' _ "$skill"

# The report format.
heading='## verify: **<VERDICT>** · merge risk **<level>** · <PR or umbrella> scope · #<issue> (<title>)'
expect "the report heading has the verdict, then the merge risk level, then the scope" \
  grep -qxF "     $heading" <<<"$report"
expect "the report heading still starts with ## verify: **<VERDICT>**, which Autopilot matches" \
  grep -qF '     ## verify: **<VERDICT>**' <<<"$report"
expect "the report has a Merge risk section with one line for each of the four categories" \
  bash -c 'for c in Alignment Impact "Rollback cost" "Error detection"; do grep -qxF "     - **$c:** <rating>" <<<"$1" || exit 1; done' _ "$report"
expect "the Merge risk section comes after the Checked at line and before the table" \
  bash -c 'c=$(grep -nF "Checked at" <<<"$1" | head -1 | cut -d: -f1); m=$(grep -nxF "     ### Merge risk" <<<"$1" | cut -d: -f1); t=$(grep -nF "| # | Scenario" <<<"$1" | cut -d: -f1); [ -n "$c" ] && [ -n "$m" ] && [ -n "$t" ] && [ "$c" -lt "$m" ] && [ "$m" -lt "$t" ]' _ "$report"

# Step 4: the order of the report, and the risk's part in the verdict.
expect "step 4 gives the report's order with Merge risk after the Checked at line" \
  grep -qF 'The report'"'"'s order is: the heading, the "Checked at" line, `### Merge risk`, the table, `### Gaps` (only when a row fails), `### Verify commands`, then `### Checks` in PR scope.' <<<"$step4"
expect "step 4 says the merge risk is graded on every run and sets no verdict" \
  bash -c 'grep -qF "merge risk is graded on every run" <<<"$1" && grep -qF "sets no verdict" <<<"$1"' _ "$step4"
expect "step 6 says the merge risk decides no ready mark" grep -qF 'merge risk decides no ready mark' <<<"$step6"

# The glossary and the README.
expect "the glossary holds the Merge risk entry of D8" \
  bash -c 'grep -qF -x "**Merge risk**: The level, low, medium or high, that verify gives a PR or a feature branch beside its verdict, from its ratings of alignment, impact, rollback cost and error detection; it changes no verdict and no merge." "$1" && grep -qxF "_Avoid_: risk score" "$1"' _ "$glossary"
expect "the README's verify bullet names the merge risk" \
  bash -c 'grep -E "^- \`verify\`" "$1" | grep -qF "merge risk"' _ "$readme"
# #367: the grading agent runs on Opus, in both scopes.
expect "step 3 launches the grading agent with model opus, in PR scope and in umbrella scope" \
  grep -qF 'Launch one agent with the Agent tool, `subagent_type: general-purpose` and `model` `opus`, in PR scope and in umbrella scope, never a fork.' <<<"$step3"
expect "the README's verify bullet says the grading agent runs on Opus" \
  bash -c 'grep -E "^- \`verify\`" "$1" | grep -qF "grading agent on Opus"' _ "$readme"
expect "the README's Build paragraph names the merge risk" \
  bash -c 'grep -E "^\*\*Build\*\*" "$1" | grep -qF "merge risk"' _ "$readme"

# #420: the Tested check and the Test integrity row, in PR scope only (#417 D8).
tested=$(sed -n '/^   - \*\*Tested\*\*/,/^   - \*\*Test integrity\*\*/p' "$skill" | sed '$d')
integrity=$(sed -n '/^   - \*\*Test integrity\*\*/,/^   - Add one row to the table for each/p' "$skill" | sed '$d')

expect "scenario 1: step 3 gives each scenario a Tested check, and a scenario passes only when Exists, Substantive, Wired and Tested are all yes" \
  grep -qF 'a scenario passes only when Exists, Substantive, Wired and Tested are all yes' <<<"$step3"
expect "scenario 1: the report table has a Tested column" \
  grep -qF '| # | Scenario | Tested | Grade | Evidence |' <<<"$report"
expect "scenario 1: the Tested check reads the PR body's Scenario tests section in the format of formats.md" \
  bash -c 'grep -qF "\`## Scenario tests\`" <<<"$1" && grep -qF "references/formats.md" <<<"$1"' _ "$tested"
expect "scenario 1: the Tested check applies in PR scope only, and a scenario in umbrella scope has none" \
  bash -c 'grep -qF "(PR scope only)" <<<"$1" && grep -qF "In umbrella scope, a scenario has no Tested check" <<<"$1"' _ "$tested"
expect "scenario 2: Tested is no, with a gap, when a condition below it holds" \
  grep -qF 'Tested is no, with a gap, when' <<<"$tested"
expect "scenario 2: Tested is no when the scenario's line is missing" \
  grep -qF "the scenario's line is missing" <<<"$tested"
expect "scenario 2: Tested is no when the red is not a good red, as scenario-tests.md defines it" \
  bash -c 'grep -qF "its red is not a good red" <<<"$1" && grep -qF "references/scenario-tests.md" <<<"$1"' _ "$tested"
expect "scenario 2: Tested is no when the failure line does not match what the test asserts" \
  grep -qF 'its failure line does not match what the test asserts' <<<"$tested"
expect "scenario 2: Tested is no when the expected value does not come from the scenario's THEN" \
  grep -qF "the test's expected value does not come from the scenario's THEN" <<<"$tested"
expect "scenario 2: Tested is no when the test asserts only a call" \
  grep -qF 'the test asserts only a call' <<<"$tested"
expect "scenario 2: verify judges the record and does not break the code to prove a test (#417 D6)" \
  grep -qF 'do not break the code to prove the test' <<<"$tested"
expect "scenario 3: Tested is no when a no-test reason is not one of the four, or does not fit the scenario" \
  grep -qF 'a no-test reason that is not one of the four, or that does not fit the scenario' <<<"$tested"
expect "scenario 4: step 3 adds a Test integrity row in PR scope, graded on the diff against the fake-green moves of scenario-tests.md" \
  bash -c 'grep -qF "(PR scope only)" <<<"$1" && grep -qF "gh pr diff <pr>" <<<"$1" && grep -qF "fake-green move" <<<"$1" && grep -qF "scenario-tests.md" <<<"$1"' _ "$integrity"
expect "scenario 4: the Test integrity row fails when the diff holds a move, and its gap names the file:line and the move" \
  bash -c 'grep -qF "FAIL otherwise" <<<"$1" && grep -qF "name the \`file:line\` and the move" <<<"$1"' _ "$integrity"
expect "scenario 5: removing or loosening an existing test is a move only when no scenario of the issue changes that behaviour" \
  grep -qF 'is a move only when no scenario of the issue changes that behaviour' <<<"$integrity"
expect "step 5 names tested among the checks a gap can fail" \
  grep -qF 'the check that failed (exists, substantive, wired or tested)' "$skill"
expect "the glossary's Gap entry names tested among the checks (#420 D1)" \
  grep -qxF '**Gap**: A scenario, `Term` row or `ADR` row that verify grades as failing, with the check that failed (exists, substantive, wired or tested) and why.' "$glossary"
expect "the README's verify bullet names the test record and the fake-green moves" \
  bash -c 'grep -E "^- \`verify\`" "$1" | grep -qF "fake-green moves"' _ "$readme"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
