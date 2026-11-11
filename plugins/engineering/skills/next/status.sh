#!/usr/bin/env bash
# status.sh: the facts for /engineering:next.
# Reads open issues, with their parent, blockers, sub-issues and linked branches, and the PRs
# through `gh api graphql`, and remote branches through git, for the repo in the current
# directory. It changes nothing.
# Each status comes from facts only: the issue's body, its links, its linked branches and its PRs.
# An issue's branch is a branch linked to it; a `<n>-*` branch with no link gives no fact.
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
# An error prints exactly one line, `status.sh error: <reason>`, and nothing else: each jq
# call sends its stderr to /dev/null, and the output is printed only once it is complete.
#
# With no argument it prints the one report below, which /engineering:next shows and Autopilot
# reads as its Facts (#290 D1). Each issue is a bold line `**#<n>** <title> · <facts>`. A
# suggestion that is a slash command gets its own fenced code block, so that it can be copied,
# and any other suggestion ends the issue's line. A group with no issue has no heading, and no
# issue is left out. It names no next step: next picks one from the report and the bodies
# that bodies.sh prints (#344 D1).
#
# With `--statuses` it prints one JSON line instead, an array with the number, status and
# label names of each open issue, which labels.sh reads (#287 D4).
#
# Output:
#   ## Report   one `### <group>` per status group that has an issue
#   ## Cleanup  two lists, each `- none` when it is empty (#69 D8, D12):
#               `### Finished worktrees`: a line `- <path> · <branch> · <fact>` per finished
#               worktree, then its two indented calls, `git worktree remove '<path>'` and
#               `git branch -D '<branch>'`, which next runs only after the user's yes;
#               `### Merged remote branches`: a line `- <branch> · PR #<n> merged` per remote
#               issue branch whose PR has merged. These are listed, never deleted. They are read
#               by their `<n>-` name, because the list is for the user to clean up and is no
#               issue's branch (#378 D1).

set -u

statuses=false
[ "${1:-}" = "--statuses" ] && statuses=true

# `fail`, `read_branches`, `JQ_HAS_SECTION` and `JQ_TRUSTED` come from the plugin's shared file.
# `fail` does not exist until it is loaded, so a missing file prints its own error line.
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

# Reads the nodes of one connection with `gh api graphql --paginate --slurp`. $1 is the
# connection's name, $2 the query, and the rest are more `gh api` fields for its variables. The
# query holds `$endCursor` and, after its nodes, the connection's `pageInfo`, which `gh` pages with.
# Sets `items` to one JSON array with the nodes of every page. Call it in the main shell, so that its
# `fail` ends the script. A nested connection, such as `blockedBy`, reads its first 100 nodes.
read_gql() {
  local conn=$1 query=$2 out
  shift 2
  out=$(gh api graphql --paginate --slurp -F owner='{owner}' -F name='{repo}' -f query="$query" "$@" 2>&1) \
    || fail "gh api graphql: $out"
  items=$(printf '%s' "$out" | jq --arg c "$conn" '[.[].data.repository[$c].nodes[]]' 2>/dev/null) \
    || fail "gh api graphql did not return a list: $out"
}

# A jq definition, `ref($r; $n)`: how a report names issue $n of repo $r, `#<n>` in this repo.
JQ_REF='def ref($r; $n): if $r == $repo then "#\($n)" else "\($r)#\($n)" end;'

# Open issues, whose `parent`, `blockedBy`, `subIssues` and `linkedBranches` come with them. `goal`
# and `scenarios` say whether the body has a `## Goal` or a `## Scenarios` section (#181 D1, D11).
# `trusted` says whether the issue's author is a trusted author, and `author` is the login (#362
# D5). `parent` is the umbrella's name in the report. `branches` are the names of the branches
# linked to the issue, which are its branches (#368 D9).
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
    labels: (.labels.nodes | map(.name)),
    goal: has_section("Goal"),
    scenarios: has_section("Scenarios"),
    branches: ([.linkedBranches.nodes[].ref.name // empty] | unique),
    parent: (.parent | if . then ref(.repository.nameWithOwner; .number) else null end)
  })' 2>/dev/null) || fail "cannot read the open issues."

# Open blockers of each issue that has a `## Scenarios` section, is no umbrella and has a
# "blocked by" link. A blocker counts while its issue is open and, in this repo, not merged:
# the report leaves out each one in `merged_issues` below (#214 D1).
blockers=$(printf '%s' "$items" | jq --arg repo "$repo" "$JQ_HAS_SECTION$JQ_REF"'
  map(select(has_section("Scenarios") and (has_section("Goal") | not) and (.blockedBy.nodes | length) > 0)
    | {key: "\(.number)", value: [.blockedBy.nodes[] | select(.state == "OPEN") | {
        number,
        repo: .repository.nameWithOwner,
        ref: ref(.repository.nameWithOwner; .number)}] | sort_by(.number)})
  | from_entries' 2>/dev/null) || fail "cannot read the blockers."

# Closed and total sub-issues of each umbrella that has any, and the numbers of its open ones.
subs=$(printf '%s' "$items" | jq "$JQ_HAS_SECTION"'
  map(select(has_section("Goal") and (.subIssues.nodes | length) > 0)
    | {key: "\(.number)", value: {
        total: (.subIssues.nodes | length),
        closed: ([.subIssues.nodes[] | select(.state == "CLOSED")] | length),
        open: [.subIssues.nodes[] | select(.state != "CLOSED") | .number]}})
  | from_entries' 2>/dev/null) || fail "cannot read the sub-issues."

# Open PRs, with the issue that the first line of the body names:
# "Sub-issue #<n> of" (a sub-issue PR) or "Closes #<n>" (a single-issue PR). A PR whose author
# is not a trusted author names none, so it gives no fact (#362 D4).
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

# Merged sub-issues (#212 D1): for each umbrella with open sub-issues, the merged PRs into
# each branch linked to it, its feature branch. A merged PR whose first line is
# "Sub-issue #<n> of" marks open issue #<n> as merged. The repo may leave a merged sub-issue
# open until ship's final PR closes it, and GitHub may delete its branch, so this fact rests
# on the PR alone.
merged_issues='[]'
for u in $(printf '%s' "$subs" | jq -r 'to_entries[] | select(.value.open | length > 0) | .key' 2>/dev/null); do
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

# Cleanup (#69 D8, D12). In a worktree or on the remote, an issue branch is a branch whose name
# starts with `<n>-`, so a `worktree-*` branch is never one. A branch linked to an issue is one too.
#
# The PRs of every issue branch, remote or in a worktree, from one query: each branch is an alias
# `b<i>` of `pullRequests(headRefName: …)`, so a worktree adds no call. Sets `prs_of` to an object
# from each branch to {open, merged}: `open` is true or false for the branch's open PRs, and `merged`
# is null, or {number, sha} of its last merged PR, with the PR's head SHA. A PR from a fork is no PR of
# the branch. A branch reads its first 100 PRs.
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
# Sets `open_pr` and `merged` for branch $1, an issue branch.
branch_prs() {
  open_pr=$(printf '%s' "$prs_of" | jq -r --arg b "$1" '.[$b].open' 2>/dev/null) || fail "cannot read the PRs of branch $1."
  merged=$(printf '%s' "$prs_of" | jq -c --arg b "$1" '.[$b].merged' 2>/dev/null) || fail "cannot read the PRs of branch $1."
}

# Merged remote branches: each remote issue branch with a merged PR and no open one, read by its
# `<n>-` name (#378 D1). An issue branch with any merged PR, remote by its name or linked, is
# finished work, so it gives no in-progress fact (#69 D5): `finished_branches` lists each one, open
# PR or not.
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
    out=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F number="$n" -f query='query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) { issue(number: $number) { state } }
}' 2>&1) || {
      # A number that is no issue, such as a PR's, is not found.
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
  --argjson statuses "$statuses" \
  --argjson issues "$issues" \
  --argjson pulls "$pulls" \
  --argjson blockers "$blockers" \
  --argjson subs "$subs" \
  --argjson merged_issues "$merged_issues" \
  --argjson finished "$finished" \
  --argjson merged_branches "$merged_branches" \
  --argjson finished_branches "$finished_branches" '
  # The status from the facts (#181 D1), the first that applies:
  # - request: the author of the issue is not a trusted author, whatever its body says (#362 D4);
  # - umbrella: the body has a `## Goal` section. Its feature branch is a branch linked to it,
  #   so this comes before the branch fact;
  # - needs review: an open ready PR whose first line names the issue;
  # - in progress: an open draft PR that names it, or a branch linked to it with no merged
  #   PR. A branch whose PR merged is finished work, so it gives nothing, and a `<n>-*` branch
  #   with no link gives nothing either;
  # - merged: a merged PR into the feature branch of its umbrella names it (#212 D1). No
  #   group lists it and no blocker line names it, because the final PR of ship closes it;
  # - ready, or blocked with an open "blocked by" link whose blocker is not merged: the body
  #   has a `## Scenarios` section;
  # - request: anything else.
  ($issues | map(
    . as $i
    | ([$pulls[] | select(.issue == $i.number and (.draft | not))] | first) as $ready_pr
    | ([$pulls[] | select(.issue == $i.number and .draft)] | first) as $draft_pr
    | [$i.branches[] | select(. as $b | $finished_branches | index($b) | not)] as $own_branches
    # A merged blocker does not block (#214 D1): leave out each blocker in this repo whose
    # number is in $merged_issues. A blocker in another repo stays.
    | ($blockers["\($i.number)"] // []
       | map(select(. as $b | ($b.ref | startswith("#") | not) or ($merged_issues | index($b.number) | not))))
      as $open_blockers
    | $i + {
        status: (
          if ($i.trusted | not) then "request"
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
      elif .status == "umbrella" then
        subs_of(.number) as $s
        | if $s.total == 0 then "/engineering:discuss #\(.number)"
          elif $s.done == $s.total then "/engineering:ship #\(.number)"
          else "build its sub-issues" end
      else "/engineering:discuss #\(.number)"
      end;
    def label_of: {"needs-review": "needs review", "in-progress": "in progress", "ready": "ready",
                   "blocked": "blocked", "umbrella": "umbrella", "request": "request"}[.];
    # The facts of an issue, between its title and its suggestion.
    def facts:
      (if .umbrella_of then ["umbrella \(.umbrella_of)"] else [] end)
      + (if .trusted then [] else ["from \(.author), not a trusted author"] end)
      + (if .status == "umbrella" then
           subs_of(.number) as $s
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
    # An issue in the report (#283 D3): a suggestion gets a code block only when it is a slash
    # command. A blocker line keeps its command inline.
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

    | if $statuses then ($all | map({number, status, labels}) | tojson) else
      "## Report",
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
    end
' 2>/dev/null) || fail "cannot build the report."

printf '%s\n' "$out"
