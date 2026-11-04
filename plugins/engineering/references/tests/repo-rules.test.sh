#!/usr/bin/env bash
# Tests for references/repo-rules.md and the four skills that inject it: execute, setup, anneal and verify.
# They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
ref=$plugin/references/repo-rules.md
glossary=$root/docs/glossary.md
adr009=$root/docs/adr/ADR-009-conventions-are-claude-code-rules.md
repo_rules=$root/.claude/rules/repo.md
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

expect "repo-rules.md exists" test -f "$ref"
if [ ! -f "$ref" ]; then
  echo "1 failed"
  exit 1
fi
text=$(cat "$ref")

# Scenario 1: the one definition.
expect "it defines a rule as one line with no code, with an optional short reason clause" \
  bash -c 'grep -qF "one line" <<<"$1" && grep -qF "no code" <<<"$1" && grep -qF "short reason clause" <<<"$1"' _ "$text"
expect "a rule file has paths: when every rule in it applies to files under one folder" \
  bash -c 'grep -qF "paths:" <<<"$1" && grep -qF "every rule in the file applies to files under one folder" <<<"$1"' _ "$text"
expect "it holds the rule test" has "$text" '## Rule test'
rule_test=$(section "$ref" 'Rule test')
expect "the rule test: a session that never saw the PR can say when it applies and what it requires or forbids" \
  bash -c 'grep -qF "never saw the PR" <<<"$1" && grep -qF "when it applies and what it requires or forbids" <<<"$1"' _ "$rule_test"
expect "the rule test: the line states what the code does not show" has "$rule_test" 'what the code does not show'
expect "the rule test: a guideline rather than something that must hold every time" \
  has "$rule_test" 'a guideline rather than something that must hold every time'
expect "the rule test: says what nothing else in the repo already says" \
  has "$rule_test" 'what nothing else in the repo already says'
goes=$(section "$ref" 'When a rule goes')
expect "a rule goes when it fails the rule test" has "$goes" 'fails the rule test'
expect "a rule goes when a pre-PR check, a linter or another rule covers it" \
  bash -c 'grep -qF "pre-PR check" <<<"$1" && grep -qF "linter" <<<"$1" && grep -qF "another rule" <<<"$1"' _ "$goes"
expect "a rule goes when it names a thing that no longer exists" has "$goes" 'names a thing that no longer exists'
expect "a rule goes when it contradicts another rule" has "$goes" 'contradicts another rule'
backing=$(section "$ref" 'Backing skill')
expect "a rule gets a backing skill only when following it right takes steps or an example its line cannot hold" \
  has "$backing" 'only when following it right takes steps or an example that its line cannot hold'
expect "the description holds what the skill holds, in the third person, with its area's key terms" \
  bash -c 'grep -qF "description" <<<"$1" && grep -qF "third person" <<<"$1" && grep -qF "key terms" <<<"$1"' _ "$backing"
expect "the when_to_use holds the situation the rule applies in" \
  bash -c 'grep -qF "when_to_use" <<<"$1" && grep -qF "the situation the rule applies in" <<<"$1"' _ "$backing"
expect "the body holds steps and wrong/right examples, what to do rather than why" \
  bash -c 'grep -qF "steps" <<<"$1" && grep -qF "wrong/right" <<<"$1" && grep -qF "what to do rather than why" <<<"$1"' _ "$backing"
expect "a backing skill never restates a rule line" has "$backing" 'never restates a rule line'
expect "a rule with a backing skill ends with (see skill: <name>)" has "$text" '(see skill: <name>)'

# Scenario 2: portable.
expect "it names nothing specific to this repo: no cargus, forge or plugins/" \
  bash -c '! grep -qiE "cargus|forge|plugins/" "$1"' _ "$ref"

# Scenario 3: every folder it mentions may be absent.
for thing in '.claude/rules/' '.claude/skills/' 'glossary'; do
  line_hit=$(grep -iF -- "$thing" "$ref" | grep -ciE 'absent|no `\.claude|does not exist|has none|has no|if it exists|if the repo has')
  expect "it treats $thing as possibly absent" test "$line_hit" -ge 1
done

# Scenario 4: each of the four skills injects it as a ## Repo rules section and lists the cat.
inject='!`cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md"`'
for s in execute setup anneal verify; do
  skill=$plugin/skills/$s/SKILL.md
  expect "$s injects repo-rules.md under ## Repo rules" \
    bash -c 'awk "/^## Repo rules\$/ { s = 1; next } /^## / { s = 0 } s" "$1" | grep -qxF "$2"' _ "$skill" "$inject"
  expect "$s lists that cat in its allowed-tools" \
    grep -qxF '  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md")' "$skill"
done

# Scenario 5: no skill has its own definition of a rule.
for s in execute setup anneal verify; do
  skill=$plugin/skills/$s/SKILL.md
  for phrase in 'one line that says what code' 'no code, no rationale' "the glossary's **Rule**"; do
    expect "$s does not hold \"$phrase\"" bash -c '! grep -qF -- "$2" "$1"' _ "$skill" "$phrase"
  done
done

# Scenario 6: each brief holds the Repo rules section.
anneal=$plugin/skills/anneal/SKILL.md
setup=$plugin/skills/setup/SKILL.md
verify=$plugin/skills/verify/SKILL.md
execute=$plugin/skills/execute/SKILL.md
# step_text <file> <number>: the text of that numbered step, up to the next numbered step or `## ` heading.
step_text() { awk -v n="$2" '/^## / { s = 0 } /^[0-9]+\. \*\*/ { s = (index($0, n ". **") == 1) } s' "$1"; }
anneal_investigate=$(step_text "$anneal" 3)
anneal_check=$(step_text "$anneal" 4)
setup_brief=$(awk '/Component: <the language/ { s = 1 } /^         ```$/ { s = 0 } s' "$setup")
verify_grade=$(step_text "$verify" 3)
expect "anneal's investigator brief holds the Repo rules section" has "$anneal_investigate" 'Repo rules'
expect "anneal's checker brief holds the Repo rules section" has "$anneal_check" 'Repo rules'
expect "setup's research brief holds the Repo rules section" has "$setup_brief" 'Repo rules'
expect "verify's grader task holds the Repo rules section" has "$verify_grade" 'Repo rules'

# Scenario 7: execute's reflect step.
reflect=$(step_text "$execute" 5)
expect "reflect: each rule passes the rule test" has "$reflect" 'rule test'
expect "reflect: it decides by the Repo rules section whether each rule its PR adds needs a backing skill" \
  bash -c 'grep -qF "backing skill" <<<"$1" && grep -qF "Repo rules" <<<"$1"' _ "$reflect"
expect "reflect: a rule that an issue's scenario carries is decided too" has "$reflect" 'scenario carries'

# Scenario 8: anneal's checker.
check=$anneal_check
expect "the checker returns the rule only if it passes the rule test, reworded if needed, and none otherwise" \
  bash -c 'grep -qF "rule test" <<<"$1" && grep -qF "reword" <<<"$1" && grep -qF "none" <<<"$1"' _ "$check"

# Scenario 9: anneal's investigator reads .claude/rules/ for rules that go.
investigate=$anneal_investigate
expect "the investigator reports an existing rule that the Repo rules section says goes as a finding" \
  bash -c 'grep -qF "goes" <<<"$1" && grep -qF "finding" <<<"$1" && grep -qF ".claude/rules/" <<<"$1"' _ "$investigate"

# Scenario 10: verify's Rules row.
rules_row=$(grep -F 'rule test' "$verify")
expect "verify grades each changed rule line by the rule test, from the diff of .claude/rules/" \
  bash -c 'grep -qF "rule test" <<<"$1" && grep -qF "git diff origin/<base>...<sha> -- .claude/rules/" <<<"$1"' _ "$rules_row"
expect "verify grades the rule lines before the issue, the PR body or the rest of the diff" \
  bash -c 'grep -qF "before" <<<"$1" && grep -qF "the PR body" <<<"$1" && grep -qF "the rest of the diff" <<<"$1"' _ "$(grep -F 'rule test' "$verify")"
expect "verify fails a (see skill: <name>) that names no skill at <sha>" \
  bash -c 'grep -qF "(see skill: <name>)" <<<"$1" && grep -qF "no skill at \`<sha>\`" <<<"$1"' _ "$(grep -F 'rule test' "$verify")"

# Scenario 11: this repo's rule file.
expect "repo.md holds the line about what a skill holds" \
  grep -qxF -e '- A skill holds the steps and examples behind rules, never a restatement of rules or pre-PR checks.' "$repo_rules"
expect "repo.md has no line that says a skill holds a rule's reasons" \
  bash -c '! grep -qiE "skill.*(holds|hold).*reasons" "$1"' _ "$repo_rules"

# Decisions: the glossary and ADR-009.
expect "the glossary defines Rule test" grep -qF '**Rule test**: The checks that decide whether a line can be a rule' "$glossary"
expect "the glossary defines Backing skill" \
  grep -qF '**Backing skill**: A skill in a repo'"'"'s `.claude/skills/` that holds the steps or examples that one or more rules cannot fit in their line' "$glossary"
expect "the glossary keeps the Rule entry" grep -qF '**Rule**: One line in a file under `.claude/rules/`' "$glossary"
expect "ADR-009 says a rule ends with (see skill: <name>) when a skill holds what its line cannot" \
  grep -qF '(see skill: <name>)' "$adr009"
expect "ADR-009 names references/repo-rules.md as the one definition" grep -qF 'references/repo-rules.md' "$adr009"
expect "ADR-009 no longer says a rule has no rationale" bash -c '! grep -qF "no rationale" "$1"' _ "$adr009"
expect "ADR-009 rejects a skill behind every rule" grep -qF '**A skill behind every rule:**' "$adr009"
expect "ADR-009 rejects the definition in each skill" grep -qF '**Each skill'"'"'s own wording of the definition:**' "$adr009"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
