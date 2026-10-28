#!/usr/bin/env bash
# status.sh: the facts for /engineering:next.
# Reads open issues, open PRs, blockers and sub-issues through `gh api` REST, and remote
# branches through git, for the repo in the current directory. It changes nothing.
# Each status comes from facts only: the issue's body, its links, its branches and its PRs.
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
# An error prints exactly one line, `status.sh error: <reason>`, and nothing else: each jq
# call sends its stderr to /dev/null, and the output is printed only once it is complete.
#
# Output:
#   ## Report   one `### <group>` per status group, then a last line `Next: <suggestion>`
#   ## Cleanup  two lists, each `- none` when it is empty (#69 D8, D12):
#               `### Finished worktrees`: a line `- <path> · <branch> · <fact>` per finished
#               worktree, then its two indented calls, `git worktree remove '<path>'` and
#               `git branch -D '<branch>'`, which next runs only after the user's yes;
#               `### Merged remote branches`: a line `- <branch> · PR #<n> merged` per remote
#               issue branch whose PR has merged. These are listed, never deleted.

set -u

fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf 'status.sh error: %s\n' "$msg"
  exit 0
}

for tool in gh jq git; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

# Reads a list page by page, 100 items a page, without following GitHub's next-page link.
# $1 is the path. Sets `items` to one JSON array with every item. Call it in the main shell,
# not in a pipe or `$(…)`, so that its `fail` ends the script and its error text is printed.
read_list() {
  local path=$1 sep='?' page=1 out count all='[]'
  case $path in *\?*) sep='&' ;; esac
  while :; do
    out=$(gh api "$path${sep}per_page=100&page=$page" 2>&1) || fail "gh api $path: $out"
    count=$(printf '%s' "$out" | jq 'if type == "array" then length else error("not a list") end' 2>/dev/null) \
      || fail "gh api $path did not return a list: $out"
    # Through stdin, not `--argjson`: a page of issue bodies can pass the 128 KB limit of one
    # command-line argument.
    all=$(printf '%s\n%s\n' "$all" "$out" | jq -s '.[0] + .[1]' 2>/dev/null) || fail "could not join the pages of $path."
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done
  items=$all
}

repo=$(gh api 'repos/{owner}/{repo}' --jq '.full_name' 2>&1) || fail "cannot read the current repo with gh api: $repo"

# Open issues, without PRs: the issues endpoint lists PRs too. `goal` and `scenarios` say
# whether the body has a `## Goal` or a `## Scenarios` section (#181 D1, D11).
read_list 'repos/{owner}/{repo}/issues?state=open'
issues=$(printf '%s' "$items" | jq '
  def has_section($name): (.body // "") | test("(^|\n)## \($name)[ \t]*\r?(\n|$)");
  map(select(has("pull_request") | not) | {
    number, title,
    goal: has_section("Goal"),
    scenarios: has_section("Scenarios"),
    parent: (.parent_issue_url // null),
    blocked_total: (.issue_dependencies_summary.total_blocked_by // 0),
    sub_total: (.sub_issues_summary.total // 0)
  })' 2>/dev/null) || fail "cannot read the open issues."

# Open PRs, with the issue that the first line of the body names:
# "Sub-issue #<n> of" (a sub-issue PR) or "Closes #<n>" (a single-issue PR).
read_list 'repos/{owner}/{repo}/pulls?state=open'
pulls=$(printf '%s' "$items" | jq '
  map({
    number,
    draft: (.draft // false),
    issue: ((.body // "") | (split("\n")[0] // "") | rtrimstr("\r")
            | (capture("^(Sub-issue #(?<n>[0-9]+) of|Closes #(?<c>[0-9]+)([^0-9]|$))") // null)
            | if . == null then null else ((.n // .c) | tonumber) end)
  })' 2>/dev/null) || fail "cannot read the open PRs."

remote=$(git ls-remote --heads origin 2>&1) || fail "git ls-remote --heads origin: $remote"
branches=$(printf '%s\n' "$remote" | sed -n 's|^[0-9a-f]*[[:space:]]*refs/heads/||p' | jq -R . 2>/dev/null | jq -s . 2>/dev/null) \
  || fail "cannot read the remote branches."

# Open blockers of each issue that has a `## Scenarios` section, is no umbrella and has a
# "blocked by" link. A blocker counts while its issue is open.
blockers='{}'
for n in $(printf '%s' "$issues" | jq -r '
    .[] | select(.blocked_total > 0 and .scenarios and (.goal | not)) | .number' 2>/dev/null); do
  read_list "repos/{owner}/{repo}/issues/$n/dependencies/blocked_by"
  list=$(printf '%s' "$items" | jq --arg repo "$repo" '
    map(select(.state == "open") | {
      number,
      repo: (.repository_url | sub("^.*/repos/"; ""))
    } | .ref = (if .repo == $repo then "#\(.number)" else "\(.repo)#\(.number)" end))' 2>/dev/null) \
    || fail "cannot read the blockers of #$n."
  blockers=$(jq -n --argjson all "$blockers" --argjson l "$list" --arg n "$n" '$all + {($n): $l}' 2>/dev/null) \
    || fail "cannot read the blockers of #$n."
done

# Closed and total sub-issues of each umbrella that has any, and the numbers of its open ones.
subs='{}'
for n in $(printf '%s' "$issues" | jq -r '.[] | select(.goal and .sub_total > 0) | .number' 2>/dev/null); do
  read_list "repos/{owner}/{repo}/issues/$n/sub_issues"
  count=$(printf '%s' "$items" | jq '
    {total: length, closed: (map(select(.state == "closed")) | length),
     open: [.[] | select(.state != "closed") | .number]}' 2>/dev/null) \
    || fail "cannot read the sub-issues of #$n."
  subs=$(jq -n --argjson all "$subs" --argjson c "$count" --arg n "$n" '$all + {($n): $c}' 2>/dev/null) \
    || fail "cannot read the sub-issues of #$n."
done

# Merged sub-issues (#212 D1): for each umbrella with open sub-issues, the closed PRs into
# each of its `<u>-*` remote branches, its feature branch. A merged PR whose first line is
# "Sub-issue #<n> of" marks open issue #<n> as merged. The repo may leave a merged sub-issue
# open until ship's final PR closes it, and GitHub may delete its branch, so this fact rests
# on the PR alone.
merged_issues='[]'
for u in $(printf '%s' "$subs" | jq -r 'to_entries[] | select(.value.open | length > 0) | .key' 2>/dev/null); do
  for b in $(printf '%s' "$branches" | jq -r --arg p "$u-" '.[] | select(startswith($p))' 2>/dev/null); do
    enc=$(jq -rn --arg b "$b" '$b | @uri' 2>/dev/null) || fail "cannot read the PRs into branch $b."
    read_list "repos/{owner}/{repo}/pulls?base=$enc&state=closed"
    list=$(printf '%s' "$items" | jq '
      [.[] | select(.merged_at)
       | (.body // "") | (split("\n")[0] // "") | rtrimstr("\r")
       | capture("^Sub-issue #(?<n>[0-9]+) of") | .n | tonumber]' 2>/dev/null) \
      || fail "cannot read the PRs into branch $b."
    merged_issues=$(jq -n --argjson all "$merged_issues" --argjson l "$list" '$all + $l | unique' 2>/dev/null) \
      || fail "cannot read the PRs into branch $b."
  done
done

# Cleanup (#69 D8, D12). An issue branch is a branch whose name starts with `<n>-`, as above,
# so a `worktree-*` branch is never one.
#
# The PRs of branch $1, open and closed. Sets `open_pr` to true or false, and `merged` to
# null, or to {number, sha} of the branch's last merged PR, with the PR's head SHA. Caches
# each branch's result in `prs_of`, because a worktree's branch can also be a remote one.
prs_of='{}'
branch_prs() {
  local enc prs
  prs=$(printf '%s' "$prs_of" | jq -c --arg b "$1" '.[$b]' 2>/dev/null) || fail "cannot read the PRs of branch $1."
  if [ "$prs" = null ]; then
    enc=$(jq -rn --arg b "$1" '$b | @uri' 2>/dev/null) || fail "cannot read the PRs of branch $1."
    read_list "repos/{owner}/{repo}/pulls?state=all&head={owner}:$enc"
    prs=$(printf '%s' "$items" | jq -c '{
      open: any(.[]; .state == "open"),
      merged: ([.[] | select(.merged_at)] | sort_by(.merged_at) | last
               | if . then {number, sha: .head.sha} else null end)
    }' 2>/dev/null) || fail "cannot read the PRs of branch $1."
    prs_of=$(jq -n --argjson all "$prs_of" --argjson p "$prs" --arg b "$1" '$all + {($b): $p}' 2>/dev/null) \
      || fail "cannot read the PRs of branch $1."
  fi
  open_pr=$(printf '%s' "$prs" | jq -r '.open' 2>/dev/null) || fail "cannot read the PRs of branch $1."
  merged=$(printf '%s' "$prs" | jq -c '.merged' 2>/dev/null) || fail "cannot read the PRs of branch $1."
}

# Merged remote branches: each remote issue branch with a merged PR and no open one. A remote
# issue branch with any merged PR is finished work, so it gives no in-progress fact (#69 D5):
# `finished_branches` lists each one, open PR or not.
merged_branches='[]'
finished_branches='[]'
for b in $(printf '%s' "$branches" | jq -r '.[] | select(test("^[0-9]+-"))' 2>/dev/null); do
  branch_prs "$b"
  [ "$merged" != null ] || continue
  finished_branches=$(jq -n --argjson all "$finished_branches" --arg b "$b" '$all + [$b]' 2>/dev/null) \
    || fail "cannot read the PRs of branch $b."
  [ "$open_pr" = false ] || continue
  merged_branches=$(jq -n --argjson all "$merged_branches" --argjson m "$merged" --arg b "$b" \
    '$all + [{branch: $b, pr: $m.number}]' 2>/dev/null) || fail "cannot read the PRs of branch $b."
done

# Finished worktrees: every local worktree except the main one, a bare one, a detached one,
# a locked one, a prunable one (its directory is gone) and the one this script runs in. Its
# branch is an issue branch whose PR has merged, with no open PR, or whose issue is closed.
# It has no uncommitted work: `git status --porcelain` lists no tracked change and no
# untracked file, the same check `git worktree remove` makes without `--force`. It has no
# unpushed work: every commit is on a remote branch or in the merged PR's head, which the
# squash merge keeps after GitHub deletes the remote branch.
here=$(git rev-parse --show-toplevel 2>&1) || fail "git rev-parse --show-toplevel: $here"
here=$(cd "$here" 2>/dev/null && pwd -P) || fail "cannot read the current worktree's path."
open_numbers=$(printf '%s' "$issues" | jq -c '[.[].number]' 2>/dev/null) || fail "cannot read the open issues."
err=$(git worktree list --porcelain -z 2>&1 >/dev/null) || fail "git worktree list: $err"

finished='[]'
check_worktree() {
  local real n st ahead out closed fact=''
  [ "$wt_main" = 1 ] && return
  [ "$wt_bare$wt_locked$wt_prunable" = 000 ] || return
  [ -n "$wt_branch" ] || return
  case $wt_branch in [0-9]*-*) ;; *) return ;; esac
  n=${wt_branch%%-*}
  case $n in *[!0-9]*) return ;; esac
  real=$(cd "$wt_path" 2>/dev/null && pwd -P) || return
  [ "$real" = "$here" ] && return
  st=$(git -C "$wt_path" status --porcelain 2>/dev/null) || return
  [ -z "$st" ] || return

  branch_prs "$wt_branch"
  [ "$open_pr" = false ] || return
  if [ "$merged" != null ]; then
    fact="PR #$(printf '%s' "$merged" | jq -r '.number' 2>/dev/null) merged"
  elif printf '%s' "$open_numbers" | jq -e --argjson n "$n" 'index($n) == null' >/dev/null 2>&1; then
    # Not among the open issues: read the issue, which may be closed or may not exist.
    out=$(gh api "repos/{owner}/{repo}/issues/$n" 2>&1) || {
      case $out in *"HTTP 404"*|*"HTTP 410"*) return ;; esac
      fail "gh api repos/{owner}/{repo}/issues/$n: $out"
    }
    closed=$(printf '%s' "$out" | jq -r 'if has("pull_request") then "no" elif .state == "closed" then "yes" else "no" end' 2>/dev/null) \
      || fail "gh api repos/{owner}/{repo}/issues/$n did not return an issue: $out"
    [ "$closed" = yes ] || return
    fact="issue #$n closed"
  fi
  [ -n "$fact" ] || return

  ahead=$(git rev-list --count "$wt_head" --not --remotes 2>/dev/null) || return
  if [ "$ahead" != 0 ]; then
    [ "$merged" != null ] || return
    git merge-base --is-ancestor "$wt_head" "$(printf '%s' "$merged" | jq -r '.sha' 2>/dev/null)" >/dev/null 2>&1 || return
  fi

  finished=$(jq -n --argjson all "$finished" --arg p "$wt_path" --arg b "$wt_branch" --arg f "$fact" \
    '$all + [{path: $p, branch: $b, fact: $f}]' 2>/dev/null) || fail "cannot list the worktree $wt_path."
}

# `git worktree list --porcelain -z` ends each field with a NUL and each worktree with an
# empty field; the first worktree is the main one.
wt_main=1 wt_path='' wt_head='' wt_branch='' wt_bare=0 wt_locked=0 wt_prunable=0
while IFS= read -r -d '' field; do
  case $field in
    'worktree '*) wt_path=${field#worktree } ;;
    'HEAD '*) wt_head=${field#HEAD } ;;
    'branch refs/heads/'*) wt_branch=${field#branch refs/heads/} ;;
    bare) wt_bare=1 ;;
    locked|'locked '*) wt_locked=1 ;;
    prunable|'prunable '*) wt_prunable=1 ;;
    '')
      [ -n "$wt_path" ] && check_worktree
      wt_main=0 wt_path='' wt_head='' wt_branch='' wt_bare=0 wt_locked=0 wt_prunable=0
      ;;
  esac
done < <(git worktree list --porcelain -z 2>/dev/null)
[ -n "$wt_path" ] && check_worktree

out=$(jq -n -r \
  --arg repo "$repo" \
  --argjson issues "$issues" \
  --argjson pulls "$pulls" \
  --argjson branches "$branches" \
  --argjson blockers "$blockers" \
  --argjson subs "$subs" \
  --argjson merged_issues "$merged_issues" \
  --argjson finished "$finished" \
  --argjson merged_branches "$merged_branches" \
  --argjson finished_branches "$finished_branches" '
  def ref_of($url): ($url | sub("^.*/repos/"; "") | capture("^(?<r>.*)/issues/(?<n>[0-9]+)$")
                     | if .r == $repo then "#\(.n)" else "\(.r)#\(.n)" end);
  def issue_branches($n): [$branches[] | select(startswith("\($n)-"))];

  # The status from the facts (#181 D1), the first that applies:
  # - umbrella: the body has a `## Goal` section. Its feature branch is a `<n>-*` branch, so
  #   this comes before the branch fact;
  # - needs review: an open ready PR whose first line names the issue;
  # - in progress: an open draft PR that names it, or a remote `<n>-*` branch with no merged
  #   PR. A branch whose PR merged is finished work, so it gives nothing;
  # - merged: a merged PR into the feature branch of its umbrella names it (#212 D1). No
  #   group lists it and no `Next:` step picks it, because the final PR of ship closes it;
  # - ready, or blocked with an open "blocked by" link: the body has a `## Scenarios` section;
  # - request: anything else.
  ($issues | map(
    . as $i
    | ([$pulls[] | select(.issue == $i.number and (.draft | not))] | first) as $ready_pr
    | ([$pulls[] | select(.issue == $i.number and .draft)] | first) as $draft_pr
    | [issue_branches($i.number)[] | select(. as $b | $finished_branches | index($b) | not)] as $own_branches
    | ($blockers["\($i.number)"] // []) as $open_blockers
    | $i + {
        status: (
          if $i.goal then "umbrella"
          elif $ready_pr then "needs-review"
          elif $draft_pr or ($own_branches | length) > 0 then "in-progress"
          elif $merged_issues | index($i.number) then "merged"
          elif $i.scenarios then (if ($open_blockers | length) > 0 then "blocked" else "ready" end)
          else "request"
          end),
        pr: ($ready_pr // $draft_pr // null | if . then .number else null end),
        blockers: $open_blockers,
        umbrella_of: (if $i.parent then ref_of($i.parent) else null end)
      }
  ) | sort_by(.number)) as $all

  | ($all | map({key: "\(.number)", value: .}) | from_entries) as $by_number

  # The sub-issues of umbrella $u: the total, and the done ones: the closed ones plus the
  # open ones whose status is merged (#212 D1).
  | def subs_of($u):
      ($subs["\($u)"] // {total: 0, closed: 0, open: []}) as $s
      | {total: $s.total,
         done: ($s.closed + ([$s.open[] | select($by_number["\(.)"].status == "merged")] | length))};

    # One suggestion for each status.
    def suggestion:
      if .status == "needs-review" then "review and merge PR #\(.pr)"
      elif .status == "in-progress" then "/engineering:execute #\(.number)"
      elif .status == "ready" then "/engineering:execute #\(.number)"
      elif .status == "blocked" then "wait for \([.blockers[].ref] | join(", "))"
      elif .status == "merged" then "merged, the final PR of its umbrella closes it"
      elif .status == "umbrella" then
        subs_of(.number) as $s
        | if $s.total == 0 then "/engineering:discuss #\(.number)"
          elif $s.done == $s.total then "/engineering:ship #\(.number)"
          else "build its sub-issues" end
      else "/engineering:discuss #\(.number)"
      end;
    def label_of: {"needs-review": "needs review", "in-progress": "in progress", "ready": "ready",
                   "blocked": "blocked", "umbrella": "umbrella", "request": "request",
                   "merged": "merged"}[.];
    def line:
      [ "- #\(.number) \(.title)" ]
      + (if .umbrella_of then ["umbrella \(.umbrella_of)"] else [] end)
      + (if .status == "umbrella" then
           subs_of(.number) as $s
           | issue_branches(.number) as $fb
           | [ (if $s.total == 0 then "not sliced" else "\($s.done) of \($s.total) sub-issues done" end),
               (if ($fb | length) == 0 then "no feature branch"
                elif ($fb | length) == 1 then "feature branch \($fb[0])"
                else "\($fb | length) feature branches: \($fb | join(", "))" end) ]
         elif .status == "needs-review" or .status == "in-progress" then
           (if .pr then ["PR #\(.pr)"] else [] end)
         else [] end)
      + [ suggestion ]
      | join(" · ");
    def blocker_lines:
      .blockers[] as $b
      | if ($b.ref | startswith("#")) | not then "  - blocked by \($b.ref)"
        elif $by_number["\($b.number)"] then
          $by_number["\($b.number)"] as $x
          | "  - blocked by #\($b.number) · \($x.status | label_of) · \($x | suggestion)"
        else "  - blocked by #\($b.number)"
        end;

    [ {name: "Needs review", status: "needs-review"},
      {name: "In progress", status: "in-progress"},
      {name: "Ready to build", status: "ready"},
      {name: "Blocked", status: "blocked"},
      {name: "Umbrellas", status: "umbrella"},
      {name: "To shape", status: "request"} ]
    | map(. as $g | $g + {items: [$all[] | select(.status == $g.status)]}) as $groups

    # At most 20 issues, in group order. Each group that is cut gets one "and N more" line.
    | (reduce $groups[] as $g ({left: 20, out: []};
        ([($g.items | length), .left] | min) as $k
        | .out += [$g + {shown: $g.items[0:$k], more: (($g.items | length) - $k)}]
        | .left -= $k)
      | .out) as $cut

    # The `Next:` line, the first step that applies (#69).
    | ( [ $all[] | select(.status == "needs-review") ][0] ) as $review
    | ( [ $all[] | select(.status == "in-progress") ][0] ) as $doing
    | ( [ $all[] | select(.status == "umbrella")
          | select(subs_of(.number) | .total > 0 and .done == .total) ][0] ) as $to_ship
    | ( [ $all[] | select(.status == "ready") ][0] ) as $ready
    | ( [ $all[] | select(.status == "request") ][0] ) as $request

    | "## Report",
      "",
      ( $cut[]
        | "### \(.name)",
          ( if (.items | length) == 0 then "- none"
            else (.shown[] | line, blocker_lines),
                 (if .more > 0 then "- and \(.more) more" else empty end)
            end ),
          "" ),
      "Next: " + (
        if $review then
          "review and merge PR #\($review.pr), for #\($review.number)"
        elif $doing then "/engineering:execute #\($doing.number)"
        elif $to_ship then "/engineering:ship #\($to_ship.number)"
        elif $ready then "/engineering:execute #\($ready.number)"
        elif $request then "/engineering:discuss #\($request.number)"
        else "nothing: no open issue waits for a step"
        end),
      "",
      "## Cleanup",
      "",
      "### Finished worktrees",
      ( if ($finished | length) == 0 then "- none"
        else ($finished | sort_by((.branch | capture("^(?<n>[0-9]+)").n | tonumber), .path)[]
              | "- \(.path) · \(.branch) · \(.fact)",
                "  " + @sh "git worktree remove \(.path)",
                "  " + @sh "git branch -D \(.branch)")
        end ),
      "",
      "### Merged remote branches",
      ( if ($merged_branches | length) == 0 then "- none"
        else ($merged_branches | sort_by((.branch | capture("^(?<n>[0-9]+)").n | tonumber), .branch)[]
              | "- \(.branch) · PR #\(.pr) merged")
        end )
' 2>/dev/null) || fail "cannot build the report."

printf '%s\n' "$out"
