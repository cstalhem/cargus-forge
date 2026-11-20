#!/usr/bin/env bash
set -u

lib=$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh
if [ ! -f "$lib" ]; then
  printf '%s error: cannot find %s\n' "$(basename "$0")" "$lib"
  exit 0
fi
. "$lib"

for tool in gh jq git; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

repo=$(gh api 'repos/{owner}/{repo}' --jq '.full_name' 2>&1) || fail "cannot read the current repo with gh api: $repo"

read_gql() {
  local conn=$1 query=$2 out
  shift 2
  out=$(gh api graphql --paginate --slurp -F owner='{owner}' -F name='{repo}' -f query="$query" "$@" 2>&1) \
    || fail "gh api graphql: $out"
  items=$(printf '%s' "$out" | jq --arg c "$conn" '[.[].data.repository[$c].nodes[]]' 2>/dev/null) \
    || fail "gh api graphql did not return a list: $out"
}

JQ_REF='def ref($r; $n): if $r == $repo then "#\($n)" else "\($r)#\($n)" end;'

read_gql issues 'query($owner: String!, $name: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, first: 100, after: $endCursor) {
      nodes {
        number title body authorAssociation
        author { login }
        labels(first: 100) { nodes { name } }
        parent { number repository { nameWithOwner } }
        blockedBy(first: 100) { nodes { number state repository { nameWithOwner } } }
        subIssues(first: 100) { nodes { number state } }
        linkedBranches(first: 100) { nodes { ref { name } } }
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}'
issues=$(printf '%s' "$items" | jq --arg repo "$repo" "$JQ_HAS_SECTION$JQ_TRUSTED$JQ_REF"'
  map({
    number, title,
    trusted: ({author_association: .authorAssociation} | trusted),
    author: (.author.login // "unknown"),
    shaped: (.labels.nodes | any(.name == "engineering:shaped")),
    sent_back: (.labels.nodes | any(.name == "engineering:needs-discussion")),
    goal: has_section("Goal"),
    scenarios: has_section("Scenarios"),
    branches: ([.linkedBranches.nodes[].ref.name // empty] | unique),
    parent: (.parent | if . then ref(.repository.nameWithOwner; .number) else null end),
    blockers: (if has_section("Scenarios") and (has_section("Goal") | not) then
                 [.blockedBy.nodes[] | select(.state == "OPEN") | {number, ref: ref(.repository.nameWithOwner; .number)}]
                 | sort_by(.number)
               else [] end),
    subs: (if has_section("Goal") then {
             total: (.subIssues.nodes | length),
             closed: ([.subIssues.nodes[] | select(.state == "CLOSED")] | length),
             open: [.subIssues.nodes[] | select(.state != "CLOSED") | .number]}
           else null end)
  })' 2>/dev/null) || fail "cannot read the open issues."

read_gql pullRequests 'query($owner: String!, $name: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, first: 100, after: $endCursor) {
      nodes { number isDraft body authorAssociation }
      pageInfo { hasNextPage endCursor }
    }
  }
}'
pulls=$(printf '%s' "$items" | jq "$JQ_TRUSTED"'
  map({
    number,
    draft: (.isDraft // false),
    issue: (if ({author_association: .authorAssociation} | trusted) then
              ((.body // "") | (split("\n")[0] // "") | rtrimstr("\r")
               | (capture("^(Sub-issue #(?<n>[0-9]+) of|Closes #(?<c>[0-9]+)([^0-9]|$))") // null)
               | if . == null then null else ((.n // .c) | tonumber) end)
            else null end)
  })' 2>/dev/null) || fail "cannot read the open PRs."

read_branches

merged_issues='[]'
for u in $(printf '%s' "$issues" | jq -r '.[] | select((.subs.open // []) | length > 0) | .number' 2>/dev/null); do
  for b in $(printf '%s' "$issues" | jq -r --argjson u "$u" '.[] | select(.number == $u) | .branches[]' 2>/dev/null); do
    read_gql pullRequests 'query($owner: String!, $name: String!, $branch: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(baseRefName: $branch, states: MERGED, first: 100, after: $endCursor) {
      nodes { body }
      pageInfo { hasNextPage endCursor }
    }
  }
}' -f branch="$b"
    list=$(printf '%s' "$items" | jq '
      [.[] | (.body // "") | (split("\n")[0] // "") | rtrimstr("\r")
       | capture("^Sub-issue #(?<n>[0-9]+) of") | .n | tonumber]' 2>/dev/null) \
      || fail "cannot read the PRs into branch $b."
    merged_issues=$(jq -n --argjson all "$merged_issues" --argjson l "$list" '$all + $l | unique' 2>/dev/null) \
      || fail "cannot read the PRs into branch $b."
  done
done

linked_branches=$(printf '%s' "$issues" | jq -r '.[].branches[]' 2>/dev/null) || fail "cannot list the linked branches."
branch_list=$({ { printf '%s\n' "$branches" | jq -r '.[]'; git worktree list --porcelain | sed -n 's|^branch refs/heads/||p'; } 2>/dev/null \
    | grep -E '^[0-9]+-'; printf '%s\n' "$linked_branches" | grep .; } | sort -u | jq -R . 2>/dev/null | jq -sc . 2>/dev/null) \
  || fail "cannot list the issue branches."
prs_of='{}'
if [ "$branch_list" != '[]' ]; then
  head_query=$(printf '%s' "$branch_list" | jq -r '
    "query($owner: String!, $name: String!" + (to_entries | map(", $b\(.key): String!") | join(""))
    + ") { repository(owner: $owner, name: $name) {"
    + (to_entries | map(" b\(.key): pullRequests(headRefName: $b\(.key), states: [OPEN, MERGED], first: 100) { nodes { number state mergedAt headRefOid isCrossRepository } }") | join(""))
    + " } }"' 2>/dev/null) || fail "cannot build the query for the issue branches."
  head_args=()
  i=0
  for b in $(printf '%s' "$branch_list" | jq -r '.[]' 2>/dev/null); do
    head_args+=(-f "b$i=$b")
    i=$((i + 1))
  done
  out=$(gh api graphql -F owner='{owner}' -F name='{repo}' -f query="$head_query" "${head_args[@]}" 2>&1) \
    || fail "gh api graphql: $out"
  prs_of=$(printf '%s' "$out" | jq -c --argjson list "$branch_list" '
    .data.repository as $r
    | $list | to_entries
    | map({key: .value, value: ($r["b\(.key)"].nodes | map(select(.isCrossRepository | not)) | {
        open: any(.[]; .state == "OPEN"),
        merged: ([.[] | select(.state == "MERGED")] | sort_by(.mergedAt) | last
                 | if . then {number, sha: .headRefOid} else null end)})})
    | from_entries' 2>/dev/null) || fail "cannot read the PRs of the issue branches: $out"
fi
branch_prs() {
  open_pr=$(printf '%s' "$prs_of" | jq -r --arg b "$1" '.[$b].open' 2>/dev/null) || fail "cannot read the PRs of branch $1."
  merged=$(printf '%s' "$prs_of" | jq -c --arg b "$1" '.[$b].merged' 2>/dev/null) || fail "cannot read the PRs of branch $1."
}

merged_branches='[]'
finished_branches='[]'
for b in $({ printf '%s\n' "$branches" | jq -r '.[] | select(test("^[0-9]+-"))'; printf '%s\n' "$linked_branches"; } 2>/dev/null | grep . | sort -u); do
  branch_prs "$b"
  [ "$merged" != null ] || continue
  finished_branches=$(jq -n --argjson all "$finished_branches" --arg b "$b" '$all + [$b]' 2>/dev/null) \
    || fail "cannot read the PRs of branch $b."
  [ "$open_pr" = false ] || continue
  [[ $b =~ ^[0-9]+- ]] || continue
  merged_branches=$(jq -n --argjson all "$merged_branches" --argjson m "$merged" --arg b "$b" \
    '$all + [{branch: $b, pr: $m.number}]' 2>/dev/null) || fail "cannot read the PRs of branch $b."
done

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
    out=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F number="$n" -f query='query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) { issue(number: $number) { state } }
}' 2>&1) || {
      case $out in *"Could not resolve to an Issue"*) return ;; esac
      fail "gh api graphql issue #$n: $out"
    }
    closed=$(printf '%s' "$out" | jq -r '.data.repository.issue.state' 2>/dev/null) \
      || fail "gh api graphql issue #$n did not return an issue: $out"
    [ "$closed" = CLOSED ] || return
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
  --argjson merged_issues "$merged_issues" \
  --argjson finished "$finished" \
  --argjson merged_branches "$merged_branches" \
  --argjson finished_branches "$finished_branches" '
  ($issues | map(
    . as $i
    | ([$pulls[] | select(.issue == $i.number and (.draft | not))] | first) as $ready_pr
    | ([$pulls[] | select(.issue == $i.number and .draft)] | first) as $draft_pr
    | [$i.branches[] | select(. as $b | $finished_branches | index($b) | not)] as $own_branches
    | ($i.blockers
       | map(select(. as $b | ($b.ref | startswith("#") | not) or ($merged_issues | index($b.number) | not))))
      as $open_blockers
    | $i + {
        status: (
          if ($i.trusted | not) then "request"
          elif ($i.shaped | not) or $i.sent_back then "request"
          elif $i.goal then "umbrella"
          elif $ready_pr then "needs-review"
          elif $draft_pr or ($own_branches | length) > 0 then "in-progress"
          elif $merged_issues | index($i.number) then "merged"
          elif $i.scenarios then (if ($open_blockers | length) > 0 then "blocked" else "ready" end)
          else "request"
          end),
        pr: ($ready_pr // $draft_pr // null | if . then .number else null end),
        blockers: $open_blockers,
        umbrella_of: $i.parent
      }
  ) | sort_by(.number)) as $all

  | ($all | map({key: "\(.number)", value: .}) | from_entries) as $by_number

  | def subs_of:
      (.subs // {total: 0, closed: 0, open: []}) as $s
      | {total: $s.total,
         done: ($s.closed + ([$s.open[] | select($by_number["\(.)"].status == "merged")] | length))};

    def suggestion:
      if .status == "needs-review" then "review and merge PR #\(.pr)"
      elif .status == "in-progress" then "/engineering:execute #\(.number)"
      elif .status == "ready" then "/engineering:execute #\(.number)"
      elif .status == "blocked" then "wait for \([.blockers[].ref] | join(", "))"
      elif .status == "umbrella" then
        subs_of as $s
        | if $s.total == 0 then "/engineering:discuss #\(.number)"
          elif $s.done == $s.total then "/engineering:ship #\(.number)"
          else "build its sub-issues" end
      else "/engineering:discuss #\(.number)"
      end;
    def label_of: {"needs-review": "needs review", "in-progress": "in progress", "ready": "ready",
                   "blocked": "blocked", "umbrella": "umbrella", "request": "request"}[.];
    def facts:
      (if .umbrella_of then ["umbrella \(.umbrella_of)"] else [] end)
      + (if .sent_back then ["sent back"] else [] end)
      + (if .trusted then [] else ["from \(.author), not a trusted author"] end)
      + (if .status == "umbrella" then
           subs_of as $s
           | .branches as $fb
           | [ (if $s.total == 0 then "not sliced" else "\($s.done) of \($s.total) sub-issues done" end),
               (if ($fb | length) == 0 then "no feature branch"
                elif ($fb | length) == 1 then "feature branch \($fb[0])"
                else "\($fb | length) feature branches: \($fb | join(", "))" end) ]
         elif .status == "needs-review" or .status == "in-progress" then
           (if .pr then ["PR #\(.pr)"] else [] end)
         else [] end);
    def blocker_lines:
      .blockers[] as $b
      | if ($b.ref | startswith("#")) | not then "  - blocked by \($b.ref)"
        elif $by_number["\($b.number)"] then
          $by_number["\($b.number)"] as $x
          | "  - blocked by #\($b.number) · \($x.status | label_of) · \($x | suggestion)"
        else "  - blocked by #\($b.number)"
        end;
    def entry:
      suggestion as $s
      | ($s | startswith("/engineering:")) as $command
      | ([ "**#\(.number)** \(.title)" ] + facts + (if $command then [] else [ $s ] end) | join(" · ")),
        (if $command then "```", $s, "```" else empty end),
        blocker_lines,
        "";

    [ {name: "Needs review", status: "needs-review"},
      {name: "In progress", status: "in-progress"},
      {name: "Ready to build", status: "ready"},
      {name: "Blocked", status: "blocked"},
      {name: "Umbrellas", status: "umbrella"},
      {name: "To shape", status: "request"} ]
    | map(. as $g | $g + {items: [$all[] | select(.status == $g.status)]}) as $groups

    | "## Report",
      "",
      ( $groups[] | select(.items | length > 0)
        | "### \(.name)", "", (.items[] | entry) ),
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
