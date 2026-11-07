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
expect "the README's Build paragraph names the merge risk" \
  bash -c 'grep -E "^\*\*Build\*\*" "$1" | grep -qF "merge risk"' _ "$readme"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
