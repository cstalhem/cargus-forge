#!/usr/bin/env bash
# Tests for #391: discuss, slice and anneal add the labels of each issue they write, with the label commands that
# references/rules.md holds once, and ADR-001 states the decision (#390 D1). They read the repo's files only and need no
# network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
plugin=$(CDPATH= cd -- "$here/../../.." && pwd)
root=$(CDPATH= cd -- "$plugin/../.." && pwd)
rules=$plugin/references/rules.md
discuss=$plugin/skills/discuss/SKILL.md
slice=$plugin/skills/slice/SKILL.md
anneal=$plugin/skills/anneal/SKILL.md
adr=$root/docs/adr/ADR-001-github-is-the-work-state-store.md
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

# step_text <file> <number>: the text of that numbered step, up to the next numbered step or `## ` heading.
step_text() { awk -v n="$2" '/^## / { s = 0 } /^[0-9]+\. \*\*/ { s = (index($0, n ". **") == 1) } s' "$1"; }

# frontmatter <file>: the lines between the first two `---` lines.
frontmatter() { awk '/^---$/ { n++; next } n == 1' "$1"; }

# section <file> <heading>: the text under a `## ` heading, up to the next one.
section() { awk -v h="## $2" '/^## / { s = ($0 == h) ; next } s' "$1"; }

for f in "$rules" "$discuss" "$slice" "$anneal" "$adr"; do
  expect "$(basename "$f") exists" test -f "$f"
done

# The label commands, once, in rules.md.
label_rule=$(grep -F 'Add a label to an issue' "$rules")
expect "rules.md: adds a label with POST issues/<n>/labels and a labels[] field" \
  has "$label_rule" "gh api -X POST repos/{owner}/{repo}/issues/<n>/labels -f 'labels[]=<label>'"
expect "rules.md: removes a label with DELETE issues/<n>/labels/<label>" \
  has "$label_rule" 'gh api -X DELETE repos/{owner}/{repo}/issues/<n>/labels/<label>'
expect "rules.md: never a labels field on a create or a rewrite, because a rewrite replaces every label" \
  bash -c 'grep -qF "never with a \`labels\` field on an issue'"'"'s create or rewrite" <<<"$1" && grep -qF "replaces every label on the issue" <<<"$1"' _ "$label_rule"
expect "rules.md: reads the labels back with the issue's label names" \
  has "$label_rule" "gh api repos/{owner}/{repo}/issues/<n> --jq '[.labels[].name]'"
expect "rules.md: removes a label only when the issue lists it" has "$label_rule" 'Remove a label only when'
expect "rules.md: at most one of shaped and needs-discussion, and a swap removes the old label first" \
  bash -c 'grep -qF "at most one of \`engineering:shaped\` and \`engineering:needs-discussion\`" <<<"$1" && grep -qF "a swap removes the old label first, then adds the new one" <<<"$1"' _ "$label_rule"
expect "rules.md: a failed write or a read-back without the label shows the error and goes on" \
  bash -c 'grep -qF "when one fails or its read-back lacks the label, show the error and go on" <<<"$1" && grep -qF "a label never stops a skill" <<<"$1"' _ "$label_rule"
expect "rules.md holds the label commands once" test "$(grep -cF 'issues/<n>/labels' "$rules")" -eq 1

# discuss: Write step.
d_write=$(step_text "$discuss" 4)
d_front=$(frontmatter "$discuss")
expect "discuss: the Write step adds engineering:shaped to the issue it wrote, and to no other" \
  bash -c 'grep -qF "add \`engineering:shaped\` to the issue that this step wrote" <<<"$1" && grep -qF "no other issue'"'"'s labels change" <<<"$1"' _ "$d_write"
expect "discuss: an umbrella issue also gets engineering:umbrella" \
  has "$d_write" 'an umbrella issue also gets `engineering:umbrella`'
expect "discuss: an issue that carries engineering:needs-discussion loses it first, then gets shaped" \
  bash -c 'grep -qF "carries \`engineering:needs-discussion\`" <<<"$1" && grep -qF "remove it first" <<<"$1"' _ "$d_write"
expect "discuss: the label calls follow the rules" has "$d_write" 'as the rules say'
expect "discuss: allowed-tools pre-approves the shaped add" \
  has "$d_front" "Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:shaped')"
expect "discuss: allowed-tools pre-approves the umbrella add" \
  has "$d_front" "Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:umbrella')"
expect "discuss: allowed-tools pre-approves the needs-discussion removal" \
  has "$d_front" 'Bash(gh api -X DELETE repos/{owner}/{repo}/issues/*/labels/engineering:needs-discussion)'
expect "discuss: allowed-tools pre-approves the label read-back" \
  has "$d_front" "Bash(gh api repos/{owner}/{repo}/issues/* --jq '[.labels[].name]')"

# slice: Write step.
s_write=$(step_text "$slice" 4)
s_front=$(frontmatter "$slice")
expect "slice: each sub-issue it creates gets engineering:shaped, in a re-split too" \
  bash -c 'grep -qF "add \`engineering:shaped\` to it, as the rules say" <<<"$1" && grep -qF "Each new part" <<<"$1"' _ "$s_write"
expect "slice: allowed-tools pre-approves the shaped add" \
  has "$s_front" "Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:shaped')"
expect "slice: allowed-tools pre-approves the label read-back" \
  has "$s_front" "Bash(gh api repos/{owner}/{repo}/issues/* --jq '[.labels[].name]')"

# anneal: umbrella, sub-issues and requests.
a_requests=$(step_text "$anneal" 6)
a_umbrella=$(step_text "$anneal" 7)
a_sub=$(step_text "$anneal" 8)
a_front=$(frontmatter "$anneal")
a_rules=$(section "$anneal" Rules)
expect "anneal: the umbrella issue gets engineering:shaped and engineering:umbrella" \
  bash -c 'grep -qF "add \`engineering:shaped\` and \`engineering:umbrella\` to it, as the rules say" <<<"$1"' _ "$a_umbrella"
expect "anneal: each fix sub-issue gets engineering:shaped" \
  has "$a_sub" 'add `engineering:shaped` to it, as the rules say'
expect "anneal: a request gets no label" has "$a_requests" 'Add no label to a request.'
expect "anneal: the rules list labels among its writes" has "$a_rules" 'Its writes are issues, labels, sub-issue links and one feature branch.'
expect "anneal: allowed-tools pre-approves the shaped add" \
  has "$a_front" "Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:shaped')"
expect "anneal: allowed-tools pre-approves the umbrella add" \
  has "$a_front" "Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:umbrella')"
expect "anneal: allowed-tools pre-approves the label read-back" \
  has "$a_front" "Bash(gh api repos/{owner}/{repo}/issues/* --jq '[.labels[].name]')"

# ADR-001 states #390 D1.
a_decision=$(grep -F -- '- **Decision:**' "$adr")
a_rejected=$(section "$adr" 'Rejected alternatives')
expect "ADR-001's Decision: an issue is shaped only while it carries engineering:shaped, which discuss, slice and anneal add and status.sh reads" \
  bash -c 'grep -qF "shaped only while it carries \`engineering:shaped\`" <<<"$1" && grep -qF "discuss, slice and anneal add" <<<"$1" && grep -qF "\`status.sh\` reads" <<<"$1"' _ "$a_decision"
expect "ADR-001's Decision: needs-discussion marks a sent-back issue, umbrella is a display label, build states stay derived" \
  bash -c 'grep -qF "\`engineering:needs-discussion\` marks a shaped issue that was sent back" <<<"$1" && grep -qF "\`engineering:umbrella\` is a display label" <<<"$1" && grep -qF "build states stay derived from links, branches and PRs" <<<"$1"' _ "$a_decision"
expect "ADR-001's Decision no longer names labels.sh" bash -c '! grep -qF "labels.sh" <<<"$1"' _ "$a_decision"
expect "ADR-001 rejects the body's sections deciding shaped" has "$a_rejected" "**The body's sections decide \"shaped\":**"
expect "ADR-001 rejects one display label kept by a sweep" has "$a_rejected" '**One display label kept by a sweep (`labels.sh`):**'
expect "ADR-001 rejects labels for build states" has "$a_rejected" '**Labels for build states:**'
expect "ADR-001 rejects slice adding the umbrella label" has "$a_rejected" '**Slice adds the umbrella label:**'
expect "ADR-001 no longer rejects scripts that read labels" bash -c '! grep -qF "**Scripts that read labels:**" <<<"$1"' _ "$a_rejected"
expect "ADR-001 cites #390 as a source" grep -qF '[#390](https://github.com/cstalhem/cargus-forge/issues/390)' "$adr"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
