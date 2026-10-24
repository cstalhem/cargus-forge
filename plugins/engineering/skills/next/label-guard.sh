#!/usr/bin/env bash
# label-guard.sh: a PreToolUse hook for Bash that next registers (#69 D5).
# next's `allowed-tools` pre-approve the label calls that status.sh prints and the read-back
# in SKILL.md, with `*` for the issue number. A `*` in a Bash rule matches any text, flags and
# spaces included, so those rules alone would also approve, for example, a PATCH of the issue
# with `/labels/status:ready` at the end of a field. This hook asks for permission for any
# command that one of those rules could match, unless the whole command is exactly one of the
# three forms, with a number for the issue:
#   gh api -X POST repos/{owner}/{repo}/issues/<n>/labels -f 'labels[]=<status:in-progress|status:needs-review>'
#   gh api -X DELETE repos/{owner}/{repo}/issues/<n>/labels/<status:ready|status:in-progress|status:needs-review>
#   gh api 'repos/{owner}/{repo}/issues/<n>/labels?per_page=100' --jq '[.[].name] | sort | tojson'
# It decides nothing for any other command, so the usual permission rules apply to it.
# Claude Code keeps a skill's hooks for the rest of the session, so this stays narrow.

ask() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"next pre-approves only the exact label calls that status.sh prints and the exact labels read-back."}}'
  exit 0
}

input=$(cat)
# Without jq, ask for every command that mentions an issue's labels.
command -v jq >/dev/null 2>&1 || { case $input in *labels*) ask ;; *) exit 0 ;; esac; }

decision=$(printf '%s' "$input" | jq -r '
  (.tool_input.command // "") as $raw
  # Compare without quotes, backslashes, line continuations or repeated blanks, so that no
  # spelling of a command that a rule could match escapes the check.
  | ($raw | gsub("\\\\\n"; "") | gsub("[\"'\''\\\\]"; "") | gsub("\\s+"; " ")) as $flat
  # The fixed text before and after the `*` of each rule in allowed-tools, without quotes.
  | [ ["gh api -X POST repos/{owner}/{repo}/issues/", "/labels -f labels[]=status:in-progress"],
      ["gh api -X POST repos/{owner}/{repo}/issues/", "/labels -f labels[]=status:needs-review"],
      ["gh api -X DELETE repos/{owner}/{repo}/issues/", "/labels/status:ready"],
      ["gh api -X DELETE repos/{owner}/{repo}/issues/", "/labels/status:in-progress"],
      ["gh api -X DELETE repos/{owner}/{repo}/issues/", "/labels/status:needs-review"],
      ["gh api repos/{owner}/{repo}/issues/", "/labels?per_page=100 --jq [.[].name] | sort | tojson"] ]
  | any(.[]; .[0] as $head | .[1] as $tail
           | ($flat | index($head)) as $i
           | $i != null and (($flat[($i + ($head | length)):] | index($tail)) != null)) as $covered
  | ($raw | sub("^\\s+"; "") | sub("\\s+$"; "")
      | test("^gh api (-X POST repos/\\{owner\\}/\\{repo\\}/issues/[1-9][0-9]*/labels -f '\''labels\\[\\]=status:(in-progress|needs-review)'\''|-X DELETE repos/\\{owner\\}/\\{repo\\}/issues/[1-9][0-9]*/labels/status:(ready|in-progress|needs-review)|'\''repos/\\{owner\\}/\\{repo\\}/issues/[1-9][0-9]*/labels\\?per_page=100'\'' --jq '\''\\[\\.\\[\\]\\.name\\] \\| sort \\| tojson'\'')$")) as $exact
  | if $covered and ($exact | not) then "ask" else "pass" end' 2>/dev/null) || ask
[ "$decision" = pass ] || ask
exit 0
