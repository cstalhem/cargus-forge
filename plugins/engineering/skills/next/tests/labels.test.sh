#!/usr/bin/env bash
# Tests for labels.sh and the skills' use of it. labels.sh runs from a copy in a temporary folder,
# next to a fake status.sh that prints a fixture, with a fake `gh` first on PATH that logs each
# call and keeps each issue's labels as state. The tests need no network.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$here/.." && pwd)
plugin=$(CDPATH= cd -- "$skill_dir/../.." && pwd)
tmp=$(mktemp -d) && tmp=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$tmp"' EXIT
failures=0
label='engineering:needs-discussion'

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

# --- The script under test, next to a fake status.sh ---------------------------------------
mkdir "$tmp/skill" "$tmp/bin"
cp "$skill_dir/labels.sh" "$tmp/skill/labels.sh"
cat > "$tmp/skill/status.sh" <<'FAKE'
#!/usr/bin/env bash
[ "$1" = --statuses ] || { echo "status.sh was called with $*" >&2; exit 1; }
if [ -f "$FIX/status_error" ]; then cat "$FIX/status_error"; exit 0; fi
cat "$FIX/statuses.json"
FAKE

# --- The fake gh ---------------------------------------------------------------------------
# It logs each call as `<METHOD> <path> <fields>` to `$FIX/log`. The labels of issue <n> live in
# `$FIX/state/<n>`, taken from `statuses.json` or `closed.json` the first time. `$FIX/label_missing`
# makes `GET labels/<label>` answer 404. `FAKE_GH_NOEFFECT=1` makes a label write change nothing.
cat > "$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_GH_FAIL:-}" = 1 ] && { echo boom >&2; exit 1; }
shift
method=GET
if [ "$1" = -X ]; then method=$2; shift 2; fi
path=${1#repos/\{owner\}/\{repo\}/}
shift
echo "$method $path $*" >> "$FIX/log"
mkdir -p "$FIX/state"
state() { # state <n>: the labels file of issue <n>
  local f=$FIX/state/$1
  [ -f "$f" ] || jq -s -c --argjson n "$1" '
    add | (first(.[] | select(.number == $n) | .labels | map(if type == "object" then .name else . end)) // [])' \
    "$FIX/statuses.json" "$FIX/closed.json" > "$f"
  echo "$f"
}
case "$method $path" in
  "GET issues?state=closed&labels=$label&per_page=100&page=1") cat "$FIX/closed.json" ;;
  "GET labels/$label")
    if [ -f "$FIX/label_missing" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
    echo '{}' ;;
  "POST labels") rm -f "$FIX/label_missing"; echo '{}' ;;
  "POST issues/"*"/labels")
    n=${path#issues/}; n=${n%%/*}; f=$(state "$n")
    if [ "${FAKE_GH_NOEFFECT:-}" != 1 ]; then jq -c --arg l "$label" '. + [$l] | unique' "$f" > "$f.new" && mv "$f.new" "$f"; fi
    echo '[]' ;;
  "DELETE issues/"*"/labels/$label")
    n=${path#issues/}; n=${n%%/*}; f=$(state "$n")
    if [ "${FAKE_GH_NOEFFECT:-}" != 1 ]; then jq -c --arg l "$label" 'map(select(. != $l))' "$f" > "$f.new" && mv "$f.new" "$f"; fi
    echo '[]' ;;
  "GET issues/"*)
    n=${path#issues/}; jq -c '{labels: map({name: .})}' "$(state "$n")" ;;
  *) echo "fake gh: unexpected call $method $path" >&2; exit 1 ;;
esac
FAKE
sed -i "s|\$label|$label|g" "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"

# run_labels <fixtures>: labels.sh with the fake gh and those fixtures; its output on stdout.
run_labels() {
  FIX=$1 PATH="$tmp/bin:$PATH" bash "$tmp/skill/labels.sh"
}

# fixture <name> <statuses json> [closed json]: a fresh folder of fixtures, printed by name.
fixture() {
  mkdir "$tmp/$1"
  printf '%s\n' "$2" > "$tmp/$1/statuses.json"
  printf '%s\n' "${3:-[]}" > "$tmp/$1/closed.json"
}

# writes <fixtures>: the write calls that labels.sh made, one per line.
writes() { grep -E '^(POST|DELETE|PATCH|PUT) ' "$1/log" 2>/dev/null; }

# --- The scenarios -------------------------------------------------------------------------
echo "# add"
# #1 is a request with no label, #2 is ready and has none, #3 is a request and has it.
fixture add '[{"number":1,"status":"request","labels":["bug"]},{"number":2,"status":"ready","labels":[]},{"number":3,"status":"request","labels":["engineering:needs-discussion"]}]'
run_labels "$tmp/add" > "$tmp/add.out"
same "WHEN an open issue's status is request and it lacks the label THEN labels.sh adds it and prints its line" \
  <(printf -- '- #1 · +%s\n' "$label") "$tmp/add.out"
expect "WHEN labels.sh adds the label THEN it uses POST issues/<n>/labels" \
  grep -qxF "POST issues/1/labels -f labels[]=$label" "$tmp/add/log"
expect "WHEN labels.sh adds the label and the label exists THEN it makes no POST labels and no PATCH call" \
  bash -c '! grep -qE "^(POST labels|PATCH) " "$1/log"' _ "$tmp/add"
expect "WHEN an issue carries other labels THEN labels.sh keeps them" \
  test "$(cat "$tmp/add/state/1")" = "[\"bug\",\"$label\"]"
expect "WHEN an issue already matches its status THEN labels.sh makes no call for it" \
  bash -c '! grep -qE "issues/(2|3)" "$1/log"' _ "$tmp/add"

echo "# create"
fixture create '[{"number":1,"status":"request","labels":[]}]'
touch "$tmp/create/label_missing"
run_labels "$tmp/create" > "$tmp/create.out"
expect "WHEN the label is missing THEN labels.sh creates it with POST labels, colour fbca04 and the description" \
  grep -qxF "POST labels -f name=$label -f color=fbca04 -f description=Open issue that /engineering:discuss has not shaped yet. Set by labels.sh." "$tmp/create/log"
expect "WHEN the label is missing THEN labels.sh creates it before it adds it" \
  test "$(writes "$tmp/create" | cut -d' ' -f1-2 | paste -sd,)" = "POST labels,POST issues/1/labels"
same "WHEN the label is missing THEN labels.sh still prints the add line" \
  <(printf -- '- #1 · +%s\n' "$label") "$tmp/create.out"

echo "# remove"
fixture remove \
  '[{"number":4,"status":"ready","labels":["engineering:needs-discussion","bug"]},{"number":5,"status":"in-progress","labels":[]}]' \
  '[{"number":9,"labels":[{"name":"engineering:needs-discussion"}]},{"number":10,"pull_request":{},"labels":[{"name":"engineering:needs-discussion"}]}]'
run_labels "$tmp/remove" > "$tmp/remove.out"
same "WHEN an open issue that carries the label has another status, or a closed issue carries it THEN labels.sh removes it and prints each line, lowest number first" \
  <(printf -- '- #4 · -%s\n- #9 · -%s\n' "$label" "$label") "$tmp/remove.out"
expect "WHEN labels.sh removes the label THEN it uses DELETE issues/<n>/labels/<label>" \
  grep -qxF "DELETE issues/4/labels/$label " "$tmp/remove/log"
expect "WHEN an issue carries other labels THEN labels.sh removes none of them" \
  test "$(cat "$tmp/remove/state/4")" = '["bug"]'
expect "WHEN a closed pull request carries the label THEN labels.sh leaves it alone" \
  bash -c '! grep -q "issues/10" "$1/log"' _ "$tmp/remove"
expect "WHEN labels.sh changes labels THEN it makes no PATCH call and no POST labels call" \
  bash -c '! grep -qE "^(PATCH|POST labels )" "$1/log"' _ "$tmp/remove"

echo "# nothing to do"
fixture none '[{"number":1,"status":"request","labels":["engineering:needs-discussion"]},{"number":2,"status":"ready","labels":["bug"]}]'
run_labels "$tmp/none" > "$tmp/none.out"
same "WHEN every issue's label already matches its status THEN labels.sh prints '- none'" \
  <(echo '- none') "$tmp/none.out"
expect "WHEN every issue's label already matches its status THEN labels.sh makes no write" \
  test -z "$(writes "$tmp/none")"

echo "# read-back"
fixture back '[{"number":1,"status":"request","labels":[]}]'
FAKE_GH_NOEFFECT=1 run_labels "$tmp/back" > "$tmp/back.out"
expect "WHEN labels.sh changes an issue's label THEN it reads the issue back" \
  grep -qxF 'GET issues/1 ' "$tmp/back/log"
expect "WHEN the read-back lacks the change THEN labels.sh prints the one line 'labels.sh error: <reason>'" \
  bash -c 'test "$(wc -l < "$1")" = 1 && grep -q "^labels.sh error: " "$1"' _ "$tmp/back.out"

echo "# errors"
fixture err '[{"number":1,"status":"request","labels":[]}]'
echo 'status.sh error: boom' > "$tmp/err/status_error"
run_labels "$tmp/err" > "$tmp/err.status.out"
expect "WHEN status.sh fails THEN labels.sh prints exactly one line 'labels.sh error: <reason>'" \
  bash -c 'test "$(wc -l < "$1")" = 1 && grep -q "^labels.sh error: .*status.sh error: boom" "$1"' _ "$tmp/err.status.out"
expect "WHEN status.sh fails THEN labels.sh makes no gh call" \
  test ! -e "$tmp/err/log"
rm "$tmp/err/status_error"
FAKE_GH_FAIL=1 run_labels "$tmp/err" > "$tmp/err.gh.out"; code=$?
expect "WHEN a gh api call fails THEN labels.sh prints exactly one line 'labels.sh error: <reason>'" \
  bash -c 'test "$(wc -l < "$1")" = 1 && grep -q "^labels.sh error: " "$1"' _ "$tmp/err.gh.out"
expect "WHEN a gh api call fails THEN labels.sh exits 0" test "$code" = 0

echo "# the skills"
next=$skill_dir/SKILL.md
call='bash "${CLAUDE_SKILL_DIR}/labels.sh"'
expect "WHEN next loads THEN an allowed-tools line that matches the labels.sh call exactly pre-approves it" \
  grep -qxF "  - Bash($call)" "$next"
expect "WHEN next runs THEN its Labels step comes after its Check step and runs labels.sh" \
  bash -c 'n=$(grep -nE "^[0-9]+\. \*\*Check\.\*\*" "$1" | cut -d: -f1); l=$(grep -nE "^[0-9]+\. \*\*Labels\.\*\*.*labels\.sh" "$1" | cut -d: -f1); [ -n "$n" ] && [ -n "$l" ] && [ "$l" -gt "$n" ]' _ "$next"
expect "WHEN next runs THEN its reply shows a ## Labels part after the ## Report part" \
  grep -qF '`## Labels`' "$next"
for variant in autopilot autopilot-t3; do
  skill=$plugin/skills/$variant/SKILL.md
  expect "$variant: an allowed-tools line that matches the labels.sh call exactly pre-approves it" \
    grep -qxF '  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/next/labels.sh")' "$skill"
  expect "$variant: the Facts step runs labels.sh once, after its status.sh error check" \
    bash -c 'awk "/^[0-9]+\. \*\*/ { s = (\$0 ~ /\\*\\*Facts\\.\\*\\*/) } s" "$1" | grep -q "labels.sh"' _ "$skill"
done

if [ "$failures" -gt 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
