#!/usr/bin/env bash
# Tests for execute's PENDING resume in a T3 Code thread: its skill file, the two Autopilot skills'
# report instructions, the plugin README, the ADRs and the glossary.
# They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
skill=$plugin/skills/execute/SKILL.md
autopilot=$plugin/skills/autopilot/SKILL.md
autopilot_t3=$plugin/skills/autopilot-t3/SKILL.md
readme=$plugin/README.md
adr006=$root/docs/adr/ADR-006-engineering-runs-in-cloud-sessions.md
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

expect "step 2 checks for the orchestrator_capabilities tool, deferred counts" \
  grep -qE 'orchestrator_capabilities.*deferred|deferred.*orchestrator_capabilities' "$skill"
expect "step 7 computes the time with date, GNU first and BSD as the fallback" \
  grep -qF "date -u -d '+10 minutes' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+10M +%Y-%m-%dT%H:%M:%SZ" <<<"$t3_step"
expect "step 7 gives schedule_task the title execute #<n>: PENDING resume <k+1> of 3" \
  grep -qF 'title `execute #<n>: PENDING resume <k+1> of 3`' <<<"$t3_step"
expect "step 7 gives schedule_task the prompt /engineering:execute #<n> PENDING resume <k+1> of 3" \
  grep -qF 'prompt `/engineering:execute #<n> PENDING resume <k+1> of 3`' <<<"$t3_step"
expect "step 7 gives schedule_task a once schedule with runAt" \
  grep -qF '{"type": "once", "runAt": "<that time>"}' <<<"$t3_step"
expect "step 7 binds the task to the current thread" grep -qF 'bindToCurrentThread` true' <<<"$t3_step"
expect "step 7 checks the result for a once schedule and a nextRunAt" \
  grep -qE 'once.*nextRunAt|nextRunAt.*once' "$skill"
expect "step 7 names the T3 Code build that has one-time scheduled tasks" \
  grep -qF 'v0.1.7, or a nightly from 2026-11-01 on' "$skill"
expect "the cloud case keeps send_later" grep -qF 'send_later' "$skill"
expect "the arguments rule names schedule_task as a way a resume is scheduled" \
  grep -qE '^- The arguments are .*schedule_task' "$skill"
expect "the allowed-tools line lets execute run the GNU date command" \
  grep -qF "Bash(date -u -d '+10 minutes' +%Y-%m-%dT%H:%M:%SZ)" "$skill"
expect "the allowed-tools line lets execute run the BSD date command" \
  grep -qF 'Bash(date -u -v+10M +%Y-%m-%dT%H:%M:%SZ)' "$skill"

# A child sends no report on a turn that ends on a resume the skill scheduled itself.
expect "autopilot's report line makes an exception for a resume the skill scheduled itself" \
  grep -qF 'scheduled itself' "$autopilot"
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

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
