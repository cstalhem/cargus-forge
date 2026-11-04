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
# A call with a flag before the path, such as `-X POST`, is a write: leave a mark.
case $2 in -*) echo write > "$FIX/.wrote" ;; esac
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
  {"number":1,"title":"A request","body":"just an idea","labels":[{"name":"engineering:needs-discussion"},{"name":"bug"}]},
  {"number":2,"title":"Ready issue","body":"## Scenarios\n- WHEN a THEN b\n","labels":[{"name":"status:ready"}]},
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
# The report, written for the fixtures above: each issue is a bold line, a command that is a
# slash command gets its own code block, and a group with no issue has no heading. The
# Cleanup part follows it.
cat > "$tmp/full.report" <<'EXPECTED'
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
cat > "$tmp/full.cleanup" <<'EXPECTED'
## Cleanup

### Finished worktrees
- <tmp>/wt · 21-gone · PR #521 merged
  git worktree remove '<tmp>/wt'
  git branch -D '21-gone'

### Merged remote branches
- 20-done · PR #520 merged
- 21-gone · PR #521 merged
EXPECTED
cat "$tmp/full.report" "$tmp/full.cleanup" > "$tmp/full.expected"

echo "# no argument"
run_status "$full" > "$tmp/full.out"
same "WHEN status.sh runs with no argument THEN each issue is a bold line, a slash command gets its own code block, a blocker keeps its command inline, the report ends with a Next line, and the Cleanup part follows unchanged" \
  "$tmp/full.expected" "$tmp/full.out"

run_status "$ready" > "$tmp/ready.out"
expect "WHEN status.sh runs and a status group has no issues THEN it prints no heading for that group" \
  bash -c '! grep -qE "^### (Needs review|In progress|Blocked|Umbrellas)" "$1" && grep -qxF "### Ready to build" "$1" && grep -qxF "### To shape" "$1"' _ "$tmp/ready.out"

run_status "$many" > "$tmp/many.out"
expect "WHEN status.sh runs with more than 20 open issues THEN it lists every issue" \
  test "$(grep -c '^\*\*#1[0-9][0-9]\*\* ' "$tmp/many.out")" = 25
expect "WHEN status.sh runs with more than 20 open issues THEN it prints no 'and N more' line" \
  bash -c '! grep -q "and [0-9]* more" "$1"' _ "$tmp/many.out"

expect "WHEN status.sh runs and the next step is a slash command THEN the report ends with a Next line and a code block that holds only that command" \
  bash -c 'tail -n 20 "$1" | grep -A3 -x -F "**Next:**" | tr "\n" "|" | grep -qxF "**Next:**|\`\`\`|/engineering:execute #2|\`\`\`|"' _ "$tmp/ready.out"

run_status "$none" > "$tmp/none.out"
expect "WHEN status.sh runs and the next step is not a slash command THEN the Next line holds the suggestion" \
  grep -qxF '**Next:** nothing: no open issue waits for a step' "$tmp/none.out"
expect "WHEN status.sh runs and the next step is not a slash command THEN no code block follows the Next line" \
  bash -c '! sed -n "/^\*\*Next:\*\*/,/^## Cleanup/p" "$1" | grep -q "^\`\`\`"' _ "$tmp/none.out"

expect "WHEN grep searches status.sh for --human, 'def line:' and \$cut THEN they are gone" \
  bash -c '! grep -qF -e "--human" -e "def line:" -e "\$cut" "$1"' _ "$status"

echo "# --statuses"
cat > "$tmp/full.statuses" <<'EXPECTED'
[{"number":1,"status":"request","labels":["engineering:needs-discussion","bug"]},
 {"number":2,"status":"ready","labels":["status:ready"]},
 {"number":3,"status":"blocked","labels":[]},
 {"number":4,"status":"in-progress","labels":[]},
 {"number":5,"status":"needs-review","labels":[]},
 {"number":6,"status":"umbrella","labels":[]},
 {"number":7,"status":"ready","labels":[]},
 {"number":8,"status":"umbrella","labels":[]}]
EXPECTED
jq -c . "$tmp/full.statuses" > "$tmp/full.statuses.expected"
run_status "$full" --statuses > "$tmp/full.statuses.out"
same "WHEN status.sh --statuses runs THEN it prints a JSON array with the number, status and label names of each open issue, and no pull request"   "$tmp/full.statuses.expected" "$tmp/full.statuses.out"
expect "WHEN status.sh --statuses runs THEN it makes no write call"   test ! -e "$full/.wrote"

echo "# errors"
FAKE_GH_FAIL=1 run_status "$full" > "$tmp/err.out"
expect "WHEN status.sh runs with no argument and fails THEN it prints the one line 'status.sh error: <reason>'" \
  bash -c 'test "$(wc -l < "$1")" = 1 && grep -q "^status.sh error: " "$1"' _ "$tmp/err.out"
FAKE_GH_FAIL=1 run_status "$full" --statuses > "$tmp/err.statuses.out"
same "WHEN status.sh --statuses fails THEN it prints the same one line as with no argument" \
  "$tmp/err.out" "$tmp/err.statuses.out"

echo "# the skills"
skill=$skill_dir/SKILL.md
expect "WHEN next loads THEN its Facts line is exactly the injection of status.sh with no argument" \
  grep -qxF '!`bash "${CLAUDE_SKILL_DIR}/status.sh"`' "$skill"
expect "WHEN next loads THEN an allowed-tools line is exactly the pre-approval of that call" \
  grep -qxF '  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh")' "$skill"
for variant in autopilot autopilot-t3; do
  autopilot=$plugin/skills/$variant/SKILL.md
  expect "$variant: the skill injects status.sh with no argument" \
    bash -c 'grep -qxF "!\`bash \"\${CLAUDE_PLUGIN_ROOT}/skills/next/status.sh\"\`" "$1" && ! grep -qF -- "--human" "$1"' _ "$autopilot"
  expect "$variant: its Review and Ship steps name an umbrella issue whose code block is the ship command" \
    test "$(grep -oF 'whose code block is `/engineering:ship #<u>`' "$autopilot" | wc -l)" = 2
  expect "$variant: its Execute step goes on when there is no '### Ready to build' group" \
    bash -c 'grep -qF "If there is no \`### Ready to build\` group" "$1" && ! grep -qF "If the group is \`- none\`" "$1"' _ "$autopilot"
done

echo "# the rule"
expect "WHEN .claude/rules/engineering-scripts.md is read THEN it holds the one-report rule" \
  grep -qxF -- '- A plugin script renders its facts one way for every skill that reads them; a second output exists only for another script, such as status.sh --statuses for labels.sh.' "$plugin/../../.claude/rules/engineering-scripts.md"

if [ "$failures" -gt 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
