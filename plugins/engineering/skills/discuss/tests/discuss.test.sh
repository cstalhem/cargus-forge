#!/usr/bin/env bash
# Tests for the lessons that moved from the staging memory entries into the repo (#352): discuss's design checks and
# Defaults bullet, formats.md's exception line, domain-model.md's gate, ADR-007, two rules, a plugin-testing
# measurement and a commands.md row. They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
skill=$plugin/skills/discuss/SKILL.md
formats=$plugin/references/formats.md
domain=$plugin/references/domain-model.md
adr007=$root/docs/adr/ADR-007-question-delete-simplify-first.md
conventions=$root/.claude/rules/conventions.md
build_rules=$root/.claude/rules/engineering-build.md
testing_skill=$root/.claude/skills/plugin-testing/SKILL.md
commands=$root/docs/agents/commands.md
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

# has <text> <fixed string>: the text holds the string.
has() { grep -qF -- "$2" <<<"$1"; }

# section <file> <heading>: the text under a `## ` heading, up to the next one.
section() { awk -v h="## $2" '/^## / { s = ($0 == h) ; next } s' "$1"; }

# step_text <file> <number>: the text of that numbered step, up to the next numbered step or `## ` heading.
step_text() { awk -v n="$2" '/^## / { s = 0 } /^[0-9]+\. \*\*/ { s = (index($0, n ". **") == 1) } s' "$1"; }

# Scenarios 1 to 3: discuss's design recommendations and its Rounds step.
expect "the discuss skill file exists" test -f "$skill"
rounds=$(step_text "$skill" 2)
rules_check=$(grep -F '**Rules:**' <<<"$rounds")
need_check=$(grep -F '**Need:**' <<<"$rounds")
defaults=$(grep -F '**Defaults:**' <<<"$rounds")
expect "Rules check: against each .claude/rules/ file that loads for the files the recommendation touches" \
  has "$rules_check" 'each `.claude/rules/` file that loads for the files it touches'
expect "Rules check: a recommendation never contradicts a rule, so it changes or the round asks whether the issue edits the rule too" \
  bash -c 'grep -qF "never contradicts one" <<<"$1" && grep -qF "asks as a numbered question whether the issue edits that rule too" <<<"$1"' _ "$rules_check"
expect "Need check: names the scenario or decision that needs each part it adds" \
  bash -c 'grep -qF "scenario or decision that needs each part" <<<"$1" && grep -qF "a script, a section, a check or a file" <<<"$1"' _ "$need_check"
expect "Need check: a part that none needs stays out, and in an umbrella issue goes under ## Out of scope" \
  bash -c 'grep -qF "none needs stays out of the design" <<<"$1" && grep -qF "\`## Out of scope\`" <<<"$1" && grep -qF "can come back when a real run needs it" <<<"$1"' _ "$need_check"
expect "Defaults bullet: a point with one sensible answer is one line, Default: <answer>, because <why>, before the numbered questions" \
  bash -c 'grep -qF "\`Default: <answer>, because <why>\`" <<<"$1" && grep -qF "before the numbered questions" <<<"$1"' _ "$defaults"
expect "Defaults bullet: \"yes\" accepts it and the user can override it as they would a question" \
  bash -c 'grep -qF "\"yes\" accepts it" <<<"$1" && grep -qF "override it as they would a question" <<<"$1"' _ "$defaults"

# Scenario 4: formats.md's exception line.
exception=$(grep -F 'The one exception' "$formats")
expect "formats.md: the original body goes at the end under ## Request, without its own ## Request line and with each heading one level deeper" \
  bash -c 'grep -qF "under \`## Request\`, without its own \`## Request\` line and with each of its headings one level deeper" <<<"$1"' _ "$exception"

# Scenario 5: the gate in domain-model.md.
gate=$(section "$domain" Gate)
expect "domain-model.md gate: a made-up name passes only when more than one skill, script or doc reads or writes it" \
  has "$gate" 'passes the gate only when more than one skill, script or doc reads or writes it'

# Scenario 6: ADR-007 holds D1.
adr_decision=$(grep -F -- '- **Decision:**' "$adr007")
adr_details=$(section "$adr007" Details)
adr_rejected=$(section "$adr007" 'Rejected alternatives')
expect "ADR-007's Decision holds the Need check and the default" \
  bash -c 'grep -qF "names the scenario or decision that needs each part a recommendation adds and leaves out a part that none needs" <<<"$1" && grep -qF "states a point with one sensible answer as a default instead of asking it" <<<"$1"' _ "$adr_decision"
expect "ADR-007's Details hold the Need check" has "$adr_details" '**Need check:**'
expect "ADR-007's Details hold the Defaults" has "$adr_details" '**Defaults:**'
expect "ADR-007 rejects the principles in references/rules.md" has "$adr_rejected" '**The principles in `references/rules.md`:**'
expect "ADR-007 rejects the principles in the memory directory" has "$adr_rejected" '**The principles in the memory directory:**'
expect "ADR-007 cites #352 as a source" grep -qF '[#352](https://github.com/cstalhem/cargus-forge/issues/352)' "$adr007"

# Scenario 7: the Plugin skills rule.
plugin_skills=$(section "$conventions" 'Plugin skills')
expect "conventions.md: the Plugin skills section holds the injection budget rule" \
  has "$plugin_skills" '- A script whose output a skill injects with `` !`…` `` keeps that output under about 24,000 characters, because past about 30,000 the model silently gets only a file path and a 2KB preview (see skill: plugin-testing).'

# Scenario 8: the measurement in plugin-testing.
inject=$(section "$testing_skill" 'Inject a file into a skill body')
expect "plugin-testing: the measurement names Claude Code 2.1.316" has "$inject" '2.1.316'
expect "plugin-testing: 29,014 characters came through in full" has "$inject" '29,014'
expect "plugin-testing: 30,014 characters became <persisted-output> with a 2KB preview" \
  bash -c 'grep -qF "30,014" <<<"$1" && grep -qF "<persisted-output>Output too large" <<<"$1" && grep -qF "2KB preview" <<<"$1"' _ "$inject"
expect "plugin-testing: the model is not told that the rest is missing" has "$inject" 'no sign to the model that the rest was missing'
expect "plugin-testing: the limit applies to each injection separately" has "$inject" 'each injection separately'

# Scenario 9: the T3 tool rule.
expect "engineering-build.md holds the T3 tool rule" \
  grep -qxF -e "- A skill's call to a T3 tool rests on the schema that the host loads through ToolSearch, not on t3code's \`main\`, and checks the call's result, because the host can run an older T3 build." "$build_rules"

# Scenario 10: the commands.md row and note.
expect "commands.md: the row updates the installed plugin to main after a merge" \
  grep -qF '| Update the installed plugin to `main` after a merge | `claude plugin marketplace update && claude plugin update <name>@cargus-forge --scope user` |' "$commands"
expect "commands.md: a note says that a new folder copies the user-scope install's version" \
  bash -c 'grep -qF "new folder copies the user-scope install" "$1" && grep -qF "\`claude plugin marketplace update\` alone leaves it on the old version" "$1"' _ "$commands"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
