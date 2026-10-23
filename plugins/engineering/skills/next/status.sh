#!/usr/bin/env bash
# status.sh: the facts for /engineering:next.
# Reads open issues, open PRs, blockers and sub-issues through `gh api` REST, and remote
# branches through git, for the repo in the current directory. It changes nothing.
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
# An error prints exactly one line, `status.sh error: <reason>`, and nothing else: each jq
# call sends its stderr to /dev/null, and the output is printed only once it is complete.
#
# Output:
#   ## Report   one `### <group>` per status group, then a last line `Next: <suggestion>`
#   ## Repairs  `- none`, or one entry per issue whose labels the facts contradict (#69 D5):
#               a line `- #<n> · <change> · <fact>`, then one indented `gh api` call per
#               line, then `  labels after: <labels>`, the labels the calls leave.

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
    all=$(jq -n --argjson a "$all" --argjson b "$out" '$a + $b' 2>/dev/null) || fail "could not join the pages of $path."
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done
  items=$all
}

repo=$(gh api 'repos/{owner}/{repo}' --jq '.full_name' 2>&1) || fail "cannot read the current repo with gh api: $repo"

# Open issues, without PRs: the issues endpoint lists PRs too.
read_list 'repos/{owner}/{repo}/issues?state=open'
issues=$(printf '%s' "$items" | jq '
  map(select(has("pull_request") | not) | {
    number, title,
    labels: [.labels[].name],
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

plugin_status='["status:ready","status:in-progress","status:needs-review"]'

# Open blockers of each issue that carries a status label and has a "blocked by" link.
# A blocker counts while its issue is open.
blockers='{}'
for n in $(printf '%s' "$issues" | jq -r --argjson s "$plugin_status" '
    .[] | select(.blocked_total > 0)
        | select((.labels | index("umbrella")) | not)
        | select([.labels[] | select(. as $l | $s | index($l))] | length > 0)
        | .number' 2>/dev/null); do
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

# Closed and total sub-issues of each umbrella that has any.
subs='{}'
for n in $(printf '%s' "$issues" | jq -r '.[] | select(.labels | index("umbrella")) | select(.sub_total > 0) | .number' 2>/dev/null); do
  read_list "repos/{owner}/{repo}/issues/$n/sub_issues"
  count=$(printf '%s' "$items" | jq '
    {total: length, closed: (map(select(.state == "closed")) | length)}' 2>/dev/null) \
    || fail "cannot read the sub-issues of #$n."
  subs=$(jq -n --argjson all "$subs" --argjson c "$count" --arg n "$n" '$all + {($n): $c}' 2>/dev/null) \
    || fail "cannot read the sub-issues of #$n."
done

out=$(jq -n -r \
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

  # The status from the facts (#69 D5), before any repair, and the repair of the labels.
  ($issues | map(
    . as $i
    | ($i.labels | map(select(rank > 0))) as $status_labels
    | ($i.labels | index("umbrella") != null) as $is_umbrella
    | ([$pulls[] | select(.issue == $i.number and (.draft | not))] | first) as $ready_pr
    | ([$pulls[] | select(.issue == $i.number and .draft)] | first) as $draft_pr
    | issue_branches($i.number) as $own_branches
    | ($blockers["\($i.number)"] // []) as $open_blockers
    # The status label that a fact gives. Only an issue with a status label gets one, and
    # never `status:ready` or `umbrella`. With no fact, the labels stay as they are.
    | (if $is_umbrella or ($status_labels | length) == 0 then null
       elif $ready_pr then {label: "status:needs-review", fact: "ready PR #\($ready_pr.number)"}
       elif $draft_pr then {label: "status:in-progress", fact: "draft PR #\($draft_pr.number)"}
       elif ($own_branches | length) > 0 then
         {label: "status:in-progress", fact: "branch \($own_branches | join(", "))"}
       else null end) as $target
    | (if $is_umbrella then {add: null, remove: $status_labels, fact: "umbrella"}
       elif $target then
         { add: (if ($i.labels | index($target.label)) != null then null else $target.label end),
           remove: ($status_labels - [$target.label]),
           fact: $target.fact }
       else null end) as $fix
    | $i + {
        status: (
          if $is_umbrella then "umbrella"
          elif ($status_labels | length) == 0 then "request"
          elif $target then ($target.label | ltrimstr("status:"))
          else ($status_labels | max_by(rank) | ltrimstr("status:"))
          end),
        no_facts: (($is_umbrella | not) and ($status_labels | length) > 0 and $target == null),
        pr: ($ready_pr // $draft_pr // null | if . then .number else null end),
        blockers: $open_blockers,
        umbrella_of: (if $i.parent then ref_of($i.parent) else null end),
        repair: (
          if $fix != null and ($fix.add != null or ($fix.remove | length) > 0) then
            $fix + {after: (($i.labels - $fix.remove) + (if $fix.add then [$fix.add] else [] end))}
          else null end)
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
           (if .pr then ["PR #\(.pr)"] elif .no_facts then ["no branch or PR"] else [] end)
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
    # One entry per repair: the change and its fact, the calls in order (add, then each
    # remove, as the label rule in rules.md says), then the labels they leave.
    def repair_lines:
      . as $x
      | $x.repair as $r
      | "- #\($x.number) · "
        + ([ (if $r.add then "adds \($r.add)" else empty end),
             (if ($r.remove | length) > 0 then "removes \($r.remove | join(", "))" else empty end),
             $r.fact ] | join(" · ")),
        (if $r.add then "  gh api -X POST repos/{owner}/{repo}/issues/\($x.number)/labels -f '\''labels[]=\($r.add)'\''"
         else empty end),
        ($r.remove[] | "  gh api -X DELETE repos/{owner}/{repo}/issues/\($x.number)/labels/\(.)"),
        "  labels after: \(if ($r.after | length) == 0 then "none" else ($r.after | join(", ")) end)";

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
    | [ $all[] | select(.repair) ] as $repairs

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
        end),
      "",
      "## Repairs",
      "",
      ( if ($repairs | length) == 0 then "- none" else ($repairs[] | repair_lines) end )
' 2>/dev/null) || fail "cannot build the report."

printf '%s\n' "$out"
