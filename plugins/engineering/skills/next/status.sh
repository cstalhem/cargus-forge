#!/usr/bin/env bash
# status.sh: the facts for /engineering:next.
# Reads open issues, open PRs, blockers and sub-issues through `gh api` REST, and remote
# branches through git, for the repo in the current directory. It changes nothing.
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
#
# Output:
#   ## Report   one `### <group>` per status group, then a last line `Next: <suggestion>`

set -u

fail() {
  printf 'status.sh error: %s\n' "$*"
  exit 0
}

for tool in gh jq git; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

# Reads a list page by page, 100 items a page, without following GitHub's next-page link.
# $1 is the path. Prints one JSON array with every item.
read_list() {
  local path=$1 sep='?' page=1 out count all='[]'
  case $path in *\?*) sep='&' ;; esac
  while :; do
    out=$(gh api "$path${sep}per_page=100&page=$page" 2>&1) || fail "gh api $path: $out"
    count=$(printf '%s' "$out" | jq 'length' 2>/dev/null) || fail "gh api $path did not return a list: $out"
    all=$(jq -n --argjson a "$all" --argjson b "$out" '$a + $b') || fail "could not join the pages of $path."
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done
  printf '%s' "$all"
}

repo=$(gh api 'repos/{owner}/{repo}' --jq '.full_name' 2>&1) || fail "cannot read the current repo with gh api: $repo"

# Open issues, without PRs: the issues endpoint lists PRs too.
issues=$(read_list 'repos/{owner}/{repo}/issues?state=open' | jq '
  map(select(has("pull_request") | not) | {
    number, title,
    labels: [.labels[].name],
    parent: (.parent_issue_url // null),
    blocked_total: (.issue_dependencies_summary.total_blocked_by // 0),
    sub_total: (.sub_issues_summary.total // 0)
  })') || fail "cannot read the open issues."

# Open PRs, with the issue that the first line of the body names:
# "Sub-issue #<n> of" (a sub-issue PR) or "Closes #<n>" (a single-issue PR).
pulls=$(read_list 'repos/{owner}/{repo}/pulls?state=open' | jq '
  map({
    number,
    draft: (.draft // false),
    issue: ((.body // "") | (split("\n")[0] // "") | rtrimstr("\r")
            | (capture("^(Sub-issue #(?<n>[0-9]+) of|Closes #(?<c>[0-9]+)([^0-9]|$))") // null)
            | if . == null then null else ((.n // .c) | tonumber) end)
  })') || fail "cannot read the open PRs."

remote=$(git ls-remote --heads origin 2>&1) || fail "git ls-remote --heads origin: $remote"
branches=$(printf '%s\n' "$remote" | sed -n 's|^[0-9a-f]*[[:space:]]*refs/heads/||p' | jq -R . | jq -s .) \
  || fail "cannot read the remote branches."

plugin_status='["status:ready","status:in-progress","status:needs-review"]'

# Open blockers of each issue that carries a status label and has a "blocked by" link.
# A blocker counts while its issue is open.
blockers='{}'
for n in $(printf '%s' "$issues" | jq -r --argjson s "$plugin_status" '
    .[] | select(.blocked_total > 0)
        | select((.labels | index("umbrella")) | not)
        | select([.labels[] | select(. as $l | $s | index($l))] | length > 0)
        | .number'); do
  list=$(read_list "repos/{owner}/{repo}/issues/$n/dependencies/blocked_by" | jq --arg repo "$repo" '
    map(select(.state == "open") | {
      number,
      repo: (.repository_url | sub("^.*/repos/"; ""))
    } | .ref = (if .repo == $repo then "#\(.number)" else "\(.repo)#\(.number)" end))') \
    || fail "cannot read the blockers of #$n."
  blockers=$(jq -n --argjson all "$blockers" --argjson l "$list" --arg n "$n" '$all + {($n): $l}')
done

# Closed and total sub-issues of each umbrella that has any.
subs='{}'
for n in $(printf '%s' "$issues" | jq -r '.[] | select(.labels | index("umbrella")) | select(.sub_total > 0) | .number'); do
  count=$(read_list "repos/{owner}/{repo}/issues/$n/sub_issues" | jq '
    {total: length, closed: (map(select(.state == "closed")) | length)}') \
    || fail "cannot read the sub-issues of #$n."
  subs=$(jq -n --argjson all "$subs" --argjson c "$count" --arg n "$n" '$all + {($n): $c}')
done

jq -n -r \
  --arg repo "$repo" \
  --argjson issues "$issues" \
  --argjson pulls "$pulls" \
  --argjson branches "$branches" \
  --argjson blockers "$blockers" \
  --argjson subs "$subs" '
  def rank: {"status:ready": 1, "status:in-progress": 2, "status:needs-review": 3}[.] // 0;
  def ref_of($url): ($url | sub("^.*/repos/"; "") | capture("^(?<r>.*)/issues/(?<n>[0-9]+)$")
                     | if .r == $repo then "#\(.n)" else "\(.r)#\(.n)" end);
  def issue_branches($n): [$branches[] | select(startswith("\($n)-"))];

  # The status from the facts (#69 D5), before any repair.
  ($issues | map(
    . as $i
    | ($i.labels | map(select(rank > 0))) as $status_labels
    | ([$pulls[] | select(.issue == $i.number and (.draft | not))] | first) as $ready_pr
    | ([$pulls[] | select(.issue == $i.number and .draft)] | first) as $draft_pr
    | ($blockers["\($i.number)"] // []) as $open_blockers
    | $i + {
        status: (
          if ($i.labels | index("umbrella")) then "umbrella"
          elif ($status_labels | length) == 0 then "request"
          elif $ready_pr then "needs-review"
          elif $draft_pr or (issue_branches($i.number) | length > 0) then "in-progress"
          else ($status_labels | max_by(rank) | ltrimstr("status:"))
          end),
        pr: ($ready_pr // $draft_pr // null | if . then .number else null end),
        blockers: $open_blockers,
        umbrella_of: (if $i.parent then ref_of($i.parent) else null end)
      }
    | if .status == "ready" and (.blockers | length > 0) then .status = "blocked" else . end
  ) | sort_by(.number)) as $all

  | ($all | map({key: "\(.number)", value: .}) | from_entries) as $by_number

  # One suggestion for each status.
  | def suggestion:
      if .status == "needs-review" then
        (if .pr then "review and merge PR #\(.pr)" else "review and merge its PR" end)
      elif .status == "in-progress" or .status == "ready" then "/engineering:execute #\(.number)"
      elif .status == "blocked" then "wait for \([.blockers[].ref] | join(", "))"
      elif .status == "umbrella" then
        ($subs["\(.number)"] // {total: 0, closed: 0}) as $s
        | if $s.total == 0 then "/engineering:discuss #\(.number)"
          elif $s.closed == $s.total then "/engineering:ship #\(.number)"
          else "build its sub-issues" end
      else "/engineering:discuss #\(.number)"
      end;
    def label_of: {"needs-review": "needs review", "in-progress": "in progress", "ready": "ready",
                   "blocked": "blocked", "umbrella": "umbrella", "request": "request"}[.];
    def line:
      [ "- #\(.number) \(.title)" ]
      + (if .umbrella_of then ["umbrella \(.umbrella_of)"] else [] end)
      + (if .status == "umbrella" then
           ($subs["\(.number)"] // {total: 0, closed: 0}) as $s
           | issue_branches(.number) as $fb
           | [ (if $s.total == 0 then "not sliced" else "\($s.closed) of \($s.total) sub-issues closed" end),
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

    | ( [ $all[] | select(.status == "needs-review") ][0] ) as $review
    | ( [ $all[] | select(.status == "in-progress") ][0] ) as $doing
    | ( [ $all[] | select(.status == "umbrella")
          | select(($subs["\(.number)"] // {total: 0}) | .total > 0 and .closed == .total) ][0] ) as $to_ship
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
          (if $review.pr then "review and merge PR #\($review.pr), for #\($review.number)"
           else "review and merge the PR of #\($review.number)" end)
        elif $doing then "/engineering:execute #\($doing.number)"
        elif $to_ship then "/engineering:ship #\($to_ship.number)"
        elif $ready then "/engineering:execute #\($ready.number)"
        elif $request then "/engineering:discuss #\($request.number)"
        else "nothing: no open issue waits for a step"
        end)
' || fail "cannot build the report."
