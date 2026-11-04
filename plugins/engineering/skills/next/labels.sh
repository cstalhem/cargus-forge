#!/usr/bin/env bash
# labels.sh: keeps the shaped label on GitHub (#287, #353).
# Keeps the label `engineering:shaped` on each open issue whose status is not request, and
# removes it from each open request, so that a person browsing the repo's issues sees which
# ones /engineering:discuss has finished and are left to Build. It reads no closed issue and
# leaves a closed issue's label as it is. No skill or script reads the label to decide anything.
# It is the only writer of that label and touches no other label.
# It reads the statuses from `status.sh --statuses` and writes through `gh api` REST.
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
# An error prints exactly one line, `labels.sh error: <reason>`, and nothing else: the output
# is printed only once it is complete.
#
# Output: one line `- #<n> · +engineering:shaped` or `- #<n> · -engineering:shaped`
# per issue it changed, or `- none`.

set -u

label='engineering:shaped'
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf 'labels.sh error: %s\n' "$msg"
  exit 0
}

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

out=$(bash "$here/status.sh" --statuses 2>&1)
printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1 || fail "status.sh gave no statuses: $out"
open=$out

# Each change, lowest issue number first: `<n> <+ or ->`.
changes=$(jq -rn --argjson open "$open" --arg label "$label" '
  $open | map(select((.status != "request") != (.labels | index($label) != null))
              | {number, op: (if .status != "request" then "+" else "-" end)})
  | sort_by(.number)[] | "\(.number) \(.op)"' 2>/dev/null) || fail "cannot work out the changes."

# GitHub gives a label that POST issues/<n>/labels creates the grey default colour, so create
# it first, with its colour and description, and only when it is missing. An existing label
# keeps what the user set.
label_ready=false
ensure_label() {
  $label_ready && return
  out=$(gh api "repos/{owner}/{repo}/labels/$label" 2>&1) || {
    case $out in *"HTTP 404"*) ;; *) fail "gh api labels/$label: $out" ;; esac
    out=$(gh api -X POST 'repos/{owner}/{repo}/labels' -f name="$label" -f color=0e8a16 \
      -f description='Shaped by /engineering:discuss; leave it to Build. Set by labels.sh.' 2>&1) \
      || fail "gh api POST labels: $out"
  }
  label_ready=true
}

lines=''
while read -r n op; do
  [ -n "${n:-}" ] || continue
  if [ "$op" = + ]; then
    ensure_label
    out=$(gh api -X POST "repos/{owner}/{repo}/issues/$n/labels" -f "labels[]=$label" 2>&1) \
      || fail "gh api POST issues/$n/labels: $out"
  else
    out=$(gh api -X DELETE "repos/{owner}/{repo}/issues/$n/labels/$label" 2>&1) \
      || fail "gh api DELETE issues/$n/labels/$label: $out"
  fi
  # Read the issue's labels back.
  out=$(gh api "repos/{owner}/{repo}/issues/$n" 2>&1) || fail "gh api issues/$n: $out"
  has=$(printf '%s' "$out" | jq --arg label "$label" '(.labels // []) | map(.name) | index($label) != null' 2>/dev/null) \
    || fail "gh api issues/$n did not return an issue: $out"
  if [ "$op" = + ] && [ "$has" != true ]; then fail "#$n does not carry $label after the add."; fi
  if [ "$op" = - ] && [ "$has" != false ]; then fail "#$n still carries $label after the removal."; fi
  lines="$lines- #$n · $op$label
"
done <<EOF
$changes
EOF

if [ -z "$lines" ]; then
  echo '- none'
else
  printf '%s' "$lines"
fi
