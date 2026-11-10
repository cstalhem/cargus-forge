#!/usr/bin/env bash
# Tests for execute's PENDING resume in a T3 Code thread, for where it opens its draft PR and for how its
# step 2 gets onto the issue branch: its skill
# file, the Autopilot skill's report instruction, the plugin README, the ADRs, the glossary and the
# engineering-build rule.
# They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
skill=$plugin/skills/execute/SKILL.md
autopilot_t3=$plugin/skills/autopilot-t3/SKILL.md
readme=$plugin/README.md
adr006=$root/docs/adr/ADR-006-engineering-runs-in-t3-code-threads.md
adr008=$root/docs/adr/ADR-008-autopilot-builds-ready-issues-unattended.md
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

# The T3 case of step 7: the skill's lines that name schedule_task.
t3_step=$(grep -F 'schedule_task' "$skill")

step2=$(grep -E '^2\. ' "$skill")
expect "step 2 runs no printenv and no tool check" \
  bash -c '! grep -qE "printenv|orchestrator_capabilities" <<<"$1"' _ "$step2"
expect "step 7 loads schedule_task with ToolSearch" \
  grep -qF 'query `select:mcp__t3-code__schedule_task`' <<<"$t3_step"
expect "step 7 stops when schedule_task cannot be loaded or fails" \
  grep -qF '`schedule_task` could not be loaded or failed' "$skill"
expect "step 7 computes the time with date, GNU first and BSD as the fallback" \
  grep -qF "date -u -d '+10 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+10M +%Y-%m-%dT%H:%M:%SZ" <<<"$t3_step"
expect "step 7 gives the resume the title execute #<n>: PENDING resume <k+1> of 3" \
  grep -qF 'title `execute #<n>: PENDING resume <k+1> of 3`' "$skill"
expect "step 7 gives the resume the prompt /engineering:execute #<n> PENDING resume <k+1> of 3" \
  grep -qF 'prompt `/engineering:execute #<n> PENDING resume <k+1> of 3`' "$skill"
expect "step 7 gives schedule_task a once schedule with runAt" \
  grep -qF '{"type": "once", "runAt": "<that time>"}' <<<"$t3_step"
expect "step 7 binds the task to the current thread" grep -qF 'bindToCurrentThread` true' <<<"$t3_step"
expect "step 7 checks the result for a once schedule and a nextRunAt" \
  grep -qE 'once.*nextRunAt|nextRunAt.*once' "$skill"
expect "step 7 names the T3 Code build that has one-time scheduled tasks" \
  grep -qF 'v0.1.7, or a nightly from 2026-11-01 on' "$skill"
expect "the arguments rule names schedule_task as a way a resume is scheduled" \
  grep -qE '^- The arguments are .*schedule_task' "$skill"
expect "the allowed-tools line lets execute run the GNU date command" \
  grep -qF "Bash(date -u -d '+10 minutes' +%Y-%m-%dT%H:%M:%SZ)" "$skill"
expect "the allowed-tools line lets execute run the BSD date command" \
  grep -qF 'Bash(date -u -v+10M +%Y-%m-%dT%H:%M:%SZ)' "$skill"

# A child sends no report on a turn that ends on a resume the skill scheduled itself.
expect "autopilot-t3's report instruction makes an exception for a resume the skill scheduled itself" \
  grep -qF 'scheduled itself' "$autopilot_t3"

expect "the plugin README documents the T3 case of a PENDING resume" \
  grep -qE 'PENDING.*schedule_task|schedule_task.*PENDING' "$readme"
expect "the plugin README names the T3 Code build it needs" grep -qF 'v0.1.7' "$readme"

expect "ADR-006's PENDING bullet covers a T3 Code thread" \
  grep -qE 'PENDING verdict.*T3 Code thread|T3 Code thread.*PENDING verdict' "$adr006"
expect "ADR-006 rejects an interval scheduled task that the resumed run deletes" \
  grep -qF 'interval scheduled task that the resumed run deletes' "$adr006"
expect "ADR-008 states the report exception" grep -qF 'scheduled itself' "$adr008"

expect "the glossary defines PENDING resume" grep -qF '**PENDING resume**:' "$glossary"
expect "the glossary defines T3 Code thread" grep -qF '**T3 Code thread**:' "$glossary"

# The draft PR is opened in step 3 only: its condition, lookup and POST, run after each push.
rules_md=$root/.claude/rules/engineering-build.md
step3=$(grep -E '^3\. ' "$skill")
step6=$(grep -E '^6\. ' "$skill")
deviation5=$(sed -n '/^  5\. The issue fails the size test/,/^  6\. /p' "$skill" | sed '$d')
lookup='pulls?head={owner}:<branch>&state=open'

expect "the open-PR condition appears only in step 3" \
  test "$(grep -cF 'branch has no open PR' "$skill")" -eq 1 -a "$(grep -F 'branch has no open PR' <<<"$step3" | wc -l)" -eq 1
expect "the POST that opens the PR appears only in step 3" \
  test "$(grep -cF -e '-X POST repos/{owner}/{repo}/pulls ' "$skill")" -eq 1 -a "$(grep -cF -e '-X POST repos/{owner}/{repo}/pulls ' <<<"$step3")" -eq 1
expect "the open-PR lookup appears in step 3 only" \
  test "$(grep -cF "$lookup" "$skill")" -eq 1 -a "$(grep -cF "$lookup" <<<"$step3")" -eq 1
expect "step 3 runs the lookup after each push, deviation 5's and step 6's included" \
  grep -qE 'After each push.*deviation 5.*step 6' <<<"$step3"
expect "deviation 5 pushes as step 3 says and has no PR command or PR body of its own" \
  bash -c 'grep -qF "push it as step 3 says" <<<"$1" && ! grep -qE "POST|body|open a draft PR" <<<"$1"' _ "$deviation5"
expect "step 6 rewrites the PR that step 3's lookup found or opened, with PATCH and a read-back" \
  bash -c 'grep -qF "Step 3'"'"'s lookup after this push" <<<"$1" && grep -qF -e "-X PATCH repos/{owner}/{repo}/pulls/<pr> -f title" <<<"$1" && grep -qF "Read the PR back" <<<"$1"' _ "$step6"
expect "step 6 has no POST, no lookup and no fork between opening and rewriting" \
  bash -c '! grep -qE "POST|pulls\?head|no open PR|If it has one" <<<"$1"' _ "$step6"
expect "ADR-006's size-test-stop bullet says the push opens the draft PR through step 3 with the placeholder body" \
  grep -qE 'The push opens it through step 3 with the placeholder body' "$adr006"
expect "ADR-006 rejects the failing criterion in the stop's PR body" \
  grep -qF "**Keep the failing criterion in the size-test stop's PR body:**" "$adr006"
expect "ADR-006 rejects stating the open command in the PR step" \
  grep -qF '**State the condition and the open command in the PR step, and point step 3 and the size-test stop there:**' "$adr006"
expect "the engineering-build rule says each GitHub write has one step" \
  grep -qF -x -e '- A skill states each GitHub write and its condition in one step, and other steps point to that step.' "$rules_md"

# The PR body format lives in formats.md; execute's steps point to it.
formats=$plugin/references/formats.md
pr_body=$(sed -n '/^## PR body$/,$p' "$formats")
step1=$(grep -E '^1\. ' "$skill")

expect "formats.md has a PR body section after the Final PR body section" \
  test "$(grep -nF '## Final PR body' "$formats" | cut -d: -f1)" -lt "$(grep -nxF '## PR body' "$formats" | cut -d: -f1)"
expect "the PR body section gives the first line Closes #<n> for a single issue" grep -qF 'Closes #<n>' <<<"$pr_body"
expect "the PR body section gives the sub-issue first line" \
  grep -qF 'Sub-issue #<n> of #<parent>. This PR goes into `<base>`, so it has no `Closes` line.' <<<"$pr_body"
expect "the PR body section template has What it delivers and Deviations sections" \
  bash -c 'grep -qxF "## What it delivers" <<<"$1" && grep -qxF "## Deviations" <<<"$1"' _ "$pr_body"
expect "the PR body section says each bullet names a decision or a scenario, with no list per file" \
  bash -c 'grep -qF "D<n>" <<<"$1" && grep -qF "#<umbrella> D<n>" <<<"$1" && grep -qF "the scenario it makes pass" <<<"$1" && grep -qF "does not list the changes per file" <<<"$1"' _ "$pr_body"
expect "the PR body section says when Deviations is there and gives the Autopilot line" \
  bash -c 'grep -qF "only when a deviation rule was used or a question was answered from another session" <<<"$1" && grep -qF "Autopilot: <question> → <answer>, because <why>" <<<"$1"' _ "$pr_body"
expect "execute's step 1 reads formats.md" grep -qF '${CLAUDE_PLUGIN_ROOT}/references/formats.md' <<<"$step1"
expect "execute's rules do not restate the Autopilot line that formats.md defines" \
  bash -c '! grep -qF "Autopilot: <question>" "$1"' _ "$skill"
expect "step 6 writes the PR body in the format of formats.md" grep -qF 'PR body format of `formats.md`' <<<"$step6"
expect "step 6 no longer spells out the first line or the sections" \
  bash -c '! grep -qE "Sub-issue #|Closes #|## What it delivers|## Deviations" <<<"$1"' _ "$step6"
expect "step 3 takes the draft PR's first line from formats.md, not from step 6" \
  bash -c 'grep -qF "first line of the PR body in \`formats.md\`" <<<"$1" && ! grep -qF "step 6 defines" <<<"$1"' _ "$step3"

# Step 2 has one case per distinct action.
expect "step 2 runs git switch <branch> in one place" \
  test "$(grep -cF 'git switch <branch>' "$skill")" -eq 1
expect "step 2 has one Anything else stop" \
  test "$(grep -cF '**Anything else**' "$skill")" -eq 1
expect "the skill names no worktree-… branch prefix" \
  bash -c '! grep -qF "worktree-…" "$1"' _ "$skill"
expect "the engineering-build rule says a step has one case per distinct action" \
  grep -qF -x -e '- A skill step that branches on session state has one case per distinct action, never one case per way of reaching the same action.' "$rules_md"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
