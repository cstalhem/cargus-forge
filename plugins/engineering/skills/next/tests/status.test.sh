#!/usr/bin/env bash
# Tests for status.sh and the next skill's use of it. status.sh runs in a temporary git repo whose
# origin is a local bare repo, with a fake `gh` first on PATH that answers each REST path from
# fixtures. The tests need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$here/.." && pwd)
plugin=$(CDPATH= cd -- "$skill_dir/../.." && pwd)
status=$skill_dir/status.sh
tmp=$(mktemp -d) && tmp=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$tmp"' EXIT
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

# same <description> <expected file> <actual file>: the two files must be identical.
same() {
  if diff -u "$2" "$3" > "$tmp/diff"; then
    echo "ok: $1"
  else
    echo "FAIL: $1"
    sed 's/^/    /' "$tmp/diff"
    failures=$((failures + 1))
  fi
}

# --- The fake gh ---------------------------------------------------------------------------
# It reads `$FIX`, a folder of fixtures, and answers `gh api <path>` from the file that names
# the path: `issues`, `issues_3_dependencies_blocked_by`, `issues_6_sub_issues`, `pulls_open`
# and, for a branch's PRs, `head_<branch>`. A path with no file is an empty list.
mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_GH_FAIL:-}" = 1 ] && { echo boom >&2; exit 1; }
path=$2
pre='repos/{owner}/{repo}'
if [ "$path" = "$pre" ]; then echo o/r; exit 0; fi
p=${path#"$pre"/}
case $p in
  pulls\?state=open*) name=pulls_open ;;
  pulls\?state=all\&head=*) b=${p#*head='{owner}':}; name=head_${b%%&*} ;;
  pulls\?base=*) name=none ;;
  *) name=${p%%\?*}; name=${name//\//_} ;;
esac
if [ -f "$FIX/$name.json" ]; then cat "$FIX/$name.json"; else echo '[]'; fi
FAKE
chmod +x "$tmp/bin/gh"

# --- The repo ------------------------------------------------------------------------------
# `origin` holds main, an umbrella's feature branch, a branch with a draft PR, and two issue
# branches whose PR has merged. One of them has a clean local worktree, so it is finished.
git init -q --bare "$tmp/origin.git"
git init -q -b main "$tmp/work"
git -C "$tmp/work" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$tmp/work" remote add origin "$tmp/origin.git"
for b in 4-in-progress 6-feature 20-done 21-gone; do git -C "$tmp/work" branch -q "$b"; done
git -C "$tmp/work" push -q origin main 4-in-progress 6-feature 20-done 21-gone
git -C "$tmp/work" worktree add -q "$tmp/wt" 21-gone

# run_status <fixtures> [args...]: status.sh in the repo, with the fake gh and those fixtures.
run_status() {
  local fix=$1
  shift
  (cd "$tmp/work" && PATH="$tmp/bin:$PATH" FIX="$fix" bash "$status" "$@" | sed "s|$tmp|<tmp>|g")
}

# --- The fixtures --------------------------------------------------------------------------
# full: one issue in each status group, an umbrella with sub-issues, a PR in the issues list,
# a merged remote branch and a finished worktree.
full=$tmp/full
mkdir "$full"
cat > "$full/issues.json" <<'JSON'
[
  {"number":1,"title":"A request","body":"just an idea"},
  {"number":2,"title":"Ready issue","body":"## Scenarios\n- WHEN a THEN b\n"},
  {"number":3,"title":"Blocked issue","body":"## Scenarios\n- WHEN a THEN b\n","issue_dependencies_summary":{"total_blocked_by":1}},
  {"number":4,"title":"In progress issue","body":"## Scenarios\n- WHEN a THEN b\n"},
  {"number":5,"title":"Needs review issue","body":"## Scenarios\n- WHEN a THEN b\n"},
  {"number":6,"title":"Umbrella with sub-issues","body":"## Goal\nx\n","sub_issues_summary":{"total":2,"completed":1}},
  {"number":7,"title":"Sub-issue","body":"## Scenarios\n- WHEN a THEN b\n","parent_issue_url":"https://api.github.com/repos/o/r/issues/6"},
  {"number":8,"title":"Umbrella not sliced","body":"## Goal\nx\n"},
  {"number":41,"title":"A pull request","body":"Closes #5","pull_request":{}}
]
JSON
cat > "$full/issues_3_dependencies_blocked_by.json" <<'JSON'
[{"number":2,"state":"open","repository_url":"https://api.github.com/repos/o/r"}]
JSON
cat > "$full/issues_6_sub_issues.json" <<'JSON'
[{"number":7,"state":"open"},{"number":9,"state":"closed"}]
JSON
cat > "$full/pulls_open.json" <<'JSON'
[
  {"number":40,"draft":true,"body":"Closes #4\n\nrewritten later"},
  {"number":41,"draft":false,"body":"Closes #5\n\n## What it delivers"}
]
JSON

# ready: one request and one ready issue, so that most groups are empty and the next step is a
# slash command.
ready=$tmp/ready
mkdir "$ready"
cat > "$ready/issues.json" <<'JSON'
[
  {"number":1,"title":"A request","body":"just an idea"},
  {"number":2,"title":"Ready issue","body":"## Scenarios\n- WHEN a THEN b\n"}
]
JSON

# none: no open issue.
none=$tmp/none
mkdir "$none"

# many: 25 ready issues.
many=$tmp/many
mkdir "$many"
jq -n '[range(100; 125) | {number: ., title: "Issue \(.)", body: "## Scenarios\n- WHEN a THEN b\n"}]' > "$many/issues.json"

# Every set has the merged PRs of the two finished issue branches, for the Cleanup part.
for dir in "$full" "$ready" "$none" "$many"; do
  for b in 20-done 21-gone; do
    n=${b%%-*}
    echo "[{\"number\":5$n,\"state\":\"closed\",\"merged_at\":\"2026-01-01T00:00:00Z\",\"head\":{\"sha\":\"abc\"}}]" > "$dir/head_$b.json"
  done
done

# --- The expected output of status.sh with no argument -------------------------------------
# The same text that status.sh printed before --human existed, which Autopilot reads.
cat > "$tmp/full.plain" <<'EXPECTED'
## Report

### Needs review
- #5 Needs review issue · PR #41 · review and merge PR #41

### In progress
- #4 In progress issue · PR #40 · /engineering:execute #4

### Ready to build
- #2 Ready issue · /engineering:execute #2
- #7 Sub-issue · umbrella #6 · /engineering:execute #7

### Blocked
- #3 Blocked issue · wait for #2
  - blocked by #2 · ready · /engineering:execute #2

### Umbrellas
- #6 Umbrella with sub-issues · 1 of 2 sub-issues done · feature branch 6-feature · build its sub-issues
- #8 Umbrella not sliced · not sliced · no feature branch · /engineering:discuss #8

### To shape
- #1 A request · /engineering:discuss #1

Next: review and merge PR #41, for #5

## Cleanup

### Finished worktrees
- <tmp>/wt · 21-gone · PR #521 merged
  git worktree remove '<tmp>/wt'
  git branch -D '21-gone'

### Merged remote branches
- 20-done · PR #520 merged
- 21-gone · PR #521 merged
EXPECTED

cleanup_of() { awk '/^## Cleanup/ { s = 1 } s' "$1"; }

echo "# no argument"
run_status "$full" > "$tmp/full.plain.out"
same "WHEN status.sh runs with no argument THEN its output is byte for byte what it printed before" \
  "$tmp/full.plain" "$tmp/full.plain.out"

run_status "$many" > "$tmp/many.plain.out"
expect "WHEN status.sh runs with no argument and more than 20 issues are open THEN it lists 20 and prints an 'and N more' line" \
  grep -qxF -- '- and 5 more' "$tmp/many.plain.out"

echo "# --human"
# The expected report, written for the fixtures above: each issue is a bold line, a command
# that is a slash command gets its own code block, and a group with no issue has no heading.
cat > "$tmp/full.human" <<'EXPECTED'
## Report

### Needs review

**#5** Needs review issue · PR #41 · review and merge PR #41

### In progress

**#4** In progress issue · PR #40
```
/engineering:execute #4
```

### Ready to build

**#2** Ready issue
```
/engineering:execute #2
```

**#7** Sub-issue · umbrella #6
```
/engineering:execute #7
```

### Blocked

**#3** Blocked issue · wait for #2
  - blocked by #2 · ready · /engineering:execute #2

### Umbrellas

**#6** Umbrella with sub-issues · 1 of 2 sub-issues done · feature branch 6-feature · build its sub-issues

**#8** Umbrella not sliced · not sliced · no feature branch
```
/engineering:discuss #8
```

### To shape

**#1** A request
```
/engineering:discuss #1
```

**Next:** review and merge PR #41, for #5

EXPECTED
{ cat "$tmp/full.human"; cleanup_of "$tmp/full.plain"; } > "$tmp/full.human.expected"

run_status "$full" --human > "$tmp/full.human.out"
same "WHEN status.sh --human runs THEN each issue is a bold line, a slash command gets its own code block, a blocker keeps its command inline, and the report ends with a Next line" \
  "$tmp/full.human.expected" "$tmp/full.human.out"
same "WHEN status.sh --human runs THEN its Cleanup part is identical to the one printed with no argument" \
  <(cleanup_of "$tmp/full.plain.out") <(cleanup_of "$tmp/full.human.out")

run_status "$ready" --human > "$tmp/ready.human.out"
expect "WHEN status.sh --human runs and a status group has no issues THEN the view prints no heading for that group" \
  bash -c '! grep -qE "^### (Needs review|In progress|Blocked|Umbrellas)" "$1" && grep -qxF "### Ready to build" "$1" && grep -qxF "### To shape" "$1"' _ "$tmp/ready.human.out"
run_status "$ready" > "$tmp/ready.plain.out"
expect "WHEN status.sh runs with no argument and a group has no issues THEN it still prints its heading and '- none'" \
  grep -qxF '### Needs review' "$tmp/ready.plain.out"

run_status "$many" --human > "$tmp/many.human.out"
expect "WHEN status.sh --human runs with more than 20 open issues THEN it lists every issue" \
  test "$(grep -c '^\*\*#1[0-9][0-9]\*\* ' "$tmp/many.human.out")" = 25
expect "WHEN status.sh --human runs with more than 20 open issues THEN it prints no 'and N more' line" \
  bash -c '! grep -q "and [0-9]* more" "$1"' _ "$tmp/many.human.out"

expect "WHEN status.sh --human runs and the next step is a slash command THEN the report ends with a Next line and a code block that holds only that command" \
  bash -c 'tail -n 20 "$1" | grep -A3 -x -F "**Next:**" | tr "\n" "|" | grep -qxF "**Next:**|\`\`\`|/engineering:execute #2|\`\`\`|"' _ "$tmp/ready.human.out"

run_status "$none" --human > "$tmp/none.human.out"
expect "WHEN status.sh --human runs and the next step is not a slash command THEN the Next line holds the suggestion and no code block follows" \
  grep -qxF '**Next:** nothing: no open issue waits for a step' "$tmp/none.human.out"
expect "WHEN status.sh --human runs and the next step is not a slash command THEN no code block follows the Next line" \
  bash -c '! sed -n "/^\*\*Next:\*\*/,/^## Cleanup/p" "$1" | grep -q "^\`\`\`"' _ "$tmp/none.human.out"

echo "# errors"
FAKE_GH_FAIL=1 run_status "$full" > "$tmp/err.plain.out"
FAKE_GH_FAIL=1 run_status "$full" --human > "$tmp/err.human.out"
expect "WHEN status.sh runs with no argument and fails THEN it prints the one line 'status.sh error: <reason>'" \
  bash -c 'test "$(wc -l < "$1")" = 1 && grep -q "^status.sh error: " "$1"' _ "$tmp/err.plain.out"
same "WHEN status.sh --human fails THEN it prints the same one line as with no argument" \
  "$tmp/err.plain.out" "$tmp/err.human.out"

echo "# the skills"
skill=$skill_dir/SKILL.md
expect "WHEN next loads THEN its Facts section injects status.sh --human" \
  grep -qxF '!`bash "${CLAUDE_SKILL_DIR}/status.sh" --human`' "$skill"
expect "WHEN next loads THEN an allowed-tools line that matches the injection exactly pre-approves it" \
  grep -qxF '  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh" --human)' "$skill"
expect "WHEN next loads THEN no allowed-tools line pre-approves status.sh with no argument" \
  bash -c '! grep -qF "status.sh\")" "$1"' _ "$skill"
for variant in autopilot autopilot-t3; do
  expect "$variant: the skill still injects status.sh with no argument" \
    bash -c 'grep -qF "skills/next/status.sh\"" "$1" && ! grep -qF -- "--human" "$1"' _ "$plugin/skills/$variant/SKILL.md"
done

if [ "$failures" -gt 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
