#!/usr/bin/env bash
# Tests for the anneal skill: its skill file, the plugin README, the description in four places, the glossary
# and the ADRs. They read the repo's files only and need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
skill=$plugin/skills/anneal/SKILL.md
readme=$plugin/README.md
glossary=$root/docs/glossary.md
adr010=$root/docs/adr/ADR-010-anneal-shapes-fixes-without-discuss.md
adr008=$root/docs/adr/ADR-008-autopilot-builds-ready-issues-unattended.md
adr_index=$root/docs/adr/README.md
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

# step_text <file> <name>: the text of the step with that name, up to the next numbered step or `## ` heading.
step_text() {
  awk -v name="$2" '/^## / { s = 0 }
    /^[0-9]+\. \*\*/ { s = index($0, "**" name ".**") > 0 }
    s' "$1"
}

# has <text> <fixed string>: the text holds the string.
has() { grep -qF -- "$2" <<<"$1"; }

expect "the skill file exists" test -f "$skill"
if [ ! -f "$skill" ]; then
  echo "1 failed"
  exit 1
fi

frontmatter=$(awk '/^---$/ { n++; next } n == 1' "$skill")
sync=$(step_text "$skill" Sync)
areas=$(step_text "$skill" Areas)
investigate=$(step_text "$skill" Investigate)
check=$(step_text "$skill" Check)
route=$(step_text "$skill" Route)
requests=$(step_text "$skill" Requests)
umbrella=$(step_text "$skill" Umbrella)
subissues=$(step_text "$skill" Sub-issues)
report=$(step_text "$skill" Report)
rules=$(awk '/^## Rules/ { s = 1; next } /^## / { s = 0 } s' "$skill")

# Scenario 1: stop before any agent unless HEAD is origin/main after a fetch.
expect "the Facts fetch origin main and print the SHAs of HEAD and origin/main" \
  grep -qF '!`git fetch -q origin main && git rev-parse HEAD origin/main`' "$skill"
expect "the allowed-tools line lets the skill run that fetch" \
  grep -qF 'Bash(git fetch -q origin main && git rev-parse HEAD origin/main)' "$skill"
expect "the Sync step stops when the SHAs differ, before any agent" \
  bash -c 'grep -qiF "differ" <<<"$1" && grep -qF "stop: start no agent" <<<"$1"' _ "$sync"
expect "Sync is the first step" test "$(grep -m1 -E '^[0-9]+\. \*\*' "$skill" | cut -c1-12)" = '1. **Sync.**'

# Scenario 2: the run starts.
for src in 'CLAUDE.md' '.claude/rules/' 'docs/adr/'; do
  expect "the Areas step reads $src" has "$areas" "$src"
done
expect "the glossary and git ls-files are injected" \
  bash -c 'grep -qF "!\`cat docs/glossary.md" "$1" && grep -qF "!\`git ls-files\`" "$1"' _ "$skill"
expect "the Areas step picks at most six areas" has "$areas" 'at most six areas'
expect "the Investigate step starts one investigator for each area, in parallel" \
  bash -c 'grep -qF "one investigator for each area" <<<"$1" && grep -qF "in parallel" <<<"$1"' _ "$investigate"
expect "the rules make every agent a general-purpose agent, never a fork" \
  has "$rules" 'general-purpose agent started with the Agent tool, never a fork'
expect "the rules put the investigator on Opus" has "$rules" 'an investigator with `model` `opus`'
expect "the brief holds the area" has "$investigate" 'Area: <name>.'
expect "the brief keeps behaviour for users the same" has "$investigate" 'Behaviour for users stays the same.'
expect "the brief welcomes bold rewrites" has "$investigate" 'Bold rewrites are welcome'
expect "the brief proposes no alternative an ADR rejects" has "$investigate" 'Propose no alternative that an ADR rejects.'
for field in 'title:' 'file:line:' 'change:' 'why it is simpler:' 'rule:'; do
  expect "the brief's finding shape holds $field" has "$investigate" "- $field"
done
expect "the rule field is the rule that would have made the fix unneeded" \
  has "$investigate" 'would have made the fix unneeded had the code followed it when it was written'

# Scenario 3: a fresh checker for each finding.
expect "the Check step starts one checker for each finding" has "$check" 'one checker for each finding'
expect "the rules put the checker on Sonnet" has "$rules" 'a checker with `model` `sonnet`'
expect "the checker gets only the finding and its files" has "$check" 'Give it only the finding and the files it names'
for verdict in confirmed corrected refuted; do
  expect "the checker may return $verdict" has "$check" "- $verdict:"
done
expect "the checker confirms a rule only when the code before breaks it and the code after follows it" \
  has "$check" 'only if the code before the fix breaks it and the code after the fix follows it'
expect "the checker drops a rule that .claude/rules/ holds, a linter enforces or one command checks" \
  bash -c 'grep -qF ".claude/rules/ already holds it" <<<"$1" && grep -qF "a linter or formatter config enforces it" <<<"$1" && grep -qF "one command can check it" <<<"$1"' _ "$check"

# Scenario 4: merge and route.
expect "the Route step merges related findings" has "$route" 'Merge findings that change the same code or give the same rule into one'
expect "the route fix needs the size test and a verify command that fails before the work" \
  bash -c 'grep -qF "**fix:**" <<<"$1" && grep -qF "passes the size test" <<<"$1" && grep -qF "a verify command that fails before the work" <<<"$1"' _ "$route"
expect "the route request is any other confirmed finding, every bold rewrite included" \
  has "$route" '**request:** any other confirmed finding, every bold rewrite included'
expect "the route drop is a refuted finding" has "$route" '**drop:** a refuted finding'

# Scenario 5: a request.
expect "a request is titled Anneal <date> · <area>: <title>" has "$requests" 'title="Anneal <date> · <area>: <title>"'
expect "a request has no ## Scenarios section" has "$requests" 'It has no `## Scenarios`'
expect "a request body holds the finding and its candidate rule" \
  bash -c 'grep -qF "## Finding" <<<"$1" && grep -qF "## Candidate rule" <<<"$1"' _ "$requests"

# Scenario 6: the umbrella issue, the feature branch and the sub-issues.
expect "the Umbrella step runs only when a finding is a fix" has "$umbrella" 'Only if at least one finding has the route fix'
expect "the umbrella is titled Anneal <date> and its Scenarios hold every fix's scenarios" \
  bash -c 'grep -qF "titled \`Anneal <date>\`" <<<"$1" && grep -qF "holding every fix'"'"'s scenarios" <<<"$1"' _ "$umbrella"
expect "the umbrella's Out of scope lists each request" has "$umbrella" '`## Out of scope` with a line `- #<n> <title>` for each request'
expect "the feature branch is <u>-anneal-<date>, created from origin/main and read back" \
  bash -c 'grep -qF "\`<u>-anneal-<date>\`" <<<"$1" && grep -qF "from \`origin/main\` as the rules say, and read it back" <<<"$1"' _ "$umbrella"
expect "the rules say how to create a branch with git push" grep -qF 'git push origin <sha>:refs/heads/<n>-<slug>' "$plugin/references/rules.md"
expect "a sub-issue is titled Anneal <date> · <area>: <title>" has "$subissues" 'titled `Anneal <date> · <area>: <title>`'
expect "the rules say how to set a sub-issue's parent" grep -qF 'sub_issues -F sub_issue_id=<id>' "$plugin/references/rules.md"
expect "a sub-issue's parent is set and read back as the rules say" \
  has "$subissues" 'set its parent to the umbrella `<u>` and read the parent back, as the rules say'
expect "a sub-issue gets no blocked-by link" has "$subissues" 'Set no "blocked by" link'
expect "a fix with a rule gets the rule scenario" \
  grep -qF 'WHEN .claude/rules/<area>.md is read THEN it holds <rule>' "$skill"

# Scenario 7: no fix, no umbrella and no branch.
expect "with no fix the run writes no umbrella issue and creates no branch" \
  has "$umbrella" 'write no umbrella issue and create no branch'

# Scenario 8: no question, no file change, and the report.
expect "the rules say the run asks no question before it writes and changes no file" \
  has "$rules" 'changes no file in the repo, and asks no question before it writes to GitHub'
expect "the skill file calls the AskUserQuestion tool nowhere" test "$(grep -c AskUserQuestion "$skill")" = 0
expect "the Report step shows each URL" has "$report" 'Show each URL that the run wrote'
expect "the Report step counts findings for each area and route" has "$report" 'one row for each area and a column for each route'
expect "the Report step names Autopilot or execute on the first sub-issue as the next step" \
  bash -c 'grep -qF "Autopilot builds the umbrella issue" <<<"$1" && grep -qF "/engineering:execute #<first sub-issue>" <<<"$1"' _ "$report"

# Scenario 9: typed only.
expect "the frontmatter has disable-model-invocation: true" has "$frontmatter" 'disable-model-invocation: true'

# Scenario 10: the README and the description in four places.
expect "the README's commands table lists /engineering:anneal" grep -qE '^\| `/engineering:anneal` \|' "$readme"
expect "the README has an Anneal section" grep -qxF '## Anneal' "$readme"
expect "the README's Anneal section says that you start it by hand" \
  bash -c 'awk "/^## Anneal/ { s = 1; next } /^## / { s = 0 } s" "$1" | grep -qF "You start each one by hand"' _ "$readme"
desc=$(jq -r .description "$plugin/.claude-plugin/plugin.json")
expect "plugin.json's description names anneal" has "$desc" 'anneal'
expect "marketplace.json has the same description" \
  test "$(jq -r '.plugins[] | select(.name == "engineering") | .description' "$root/.claude-plugin/marketplace.json")" = "$desc"
expect "the root README has the same description" grep -qF -- "(\`plugins/engineering\`): $desc" "$root/README.md"
expect "the plugin README has the same description" grep -qxF -- "$desc" "$readme"

# Decisions: the glossary, ADR-010 and ADR-008.
expect "the glossary defines Anneal" grep -qF '**Anneal**: A typed run of `/engineering:anneal`' "$glossary"
expect "the glossary's Anneal entry avoids sweep, simplifier, audit, job" \
  grep -qxF '_Avoid_: sweep, simplifier, audit, job' "$glossary"
expect "the glossary's Finding entry covers an anneal" \
  grep -qF '**Finding**: Something that setup or an anneal reports about an existing repo, with the action it needs.' "$glossary"
expect "ADR-010 exists with its title and its decision" \
  bash -c 'grep -qF "title: An anneal shapes behaviour-preserving fixes without discuss" "$1" && grep -qF "the final PR into \`main\` is the human review" "$1"' _ "$adr010"
expect "ADR-010 rejects six alternatives" \
  test "$(awk '/^## Rejected alternatives/ { s = 1; next } /^## / { s = 0 } s && /^- \*\*/' "$adr010" 2>/dev/null | wc -l)" = 6
expect "the ADR index has ADR-010's row" grep -qF '| [ADR-010](ADR-010-anneal-shapes-fixes-without-discuss.md) |' "$adr_index"
expect "ADR-008's shape detail names the exception for an anneal's fix sub-issues" \
  grep -qF 'The exception is the fix sub-issues of an anneal, which [ADR-010]' "$adr008"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
