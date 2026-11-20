#!/usr/bin/env bash
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$here/.." && pwd)
bodies=$skill_dir/bodies.sh
tmp=$(mktemp -d) && tmp=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$tmp"' EXIT
failures=0

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

same() {
  if diff -u "$2" "$3" > "$tmp/diff"; then
    echo "ok: $1"
  else
    echo "FAIL: $1"
    sed 's/^/    /' "$tmp/diff"
    failures=$((failures + 1))
  fi
}

mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_GH_FAIL:-}" = 1 ] && { echo boom >&2; exit 1; }
case ${!#} in
  *issues\?state=open*) if [ -f "$FIX/issues.json" ]; then body=$(cat "$FIX/issues.json"); else body='[]'; fi ;;
  *) body='[]' ;;
esac
case " $* " in *" --slurp "*) printf '[%s]\n' "$body" ;; *) printf '%s\n' "$body" ;; esac
FAKE
chmod +x "$tmp/bin/gh"

run_bodies() { PATH="$tmp/bin:$PATH" FIX="$1" bash "$bodies"; }

trust() {
  jq '[.[] | {author_association: "OWNER", user: {login: "owner"}} + .]' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

full=$tmp/full
mkdir "$full"
cat > "$full/issues.json" <<'JSON'
[
  {"number":30,"title":"No sections","body":"just an idea\nin two lines"},
  {"number":12,"title":"An umbrella","body":"## Goal\nThe goal.\n\n## Scenarios\n- WHEN a THEN b\n\n## Out of scope\n- not this\n\n## Design\nsecret design\n"},
  {"number":41,"title":"A pull request","body":"Closes #5","pull_request":{}},
  {"number":7,"title":"A single issue","body":"## What it delivers\nIt delivers x.\n\n## Scenarios\n- WHEN a THEN b\n\n## Decisions\n- D1 · secret decision\n\n## Files\nplugins/x/a.sh\n\n## Verify\nsecret verify\n"}
]
JSON
trust "$full/issues.json"
cat > "$tmp/full.expected" <<'EXPECTED'
### #7 A single issue
## What it delivers
It delivers x.

## Files
plugins/x/a.sh

### #12 An umbrella
## Goal
The goal.

## Out of scope
- not this

### #30 No sections
just an idea
in two lines
EXPECTED

echo "# sections and order"
run_bodies "$full" > "$tmp/full.out"
same "WHEN bodies.sh runs THEN a delivers issue prints its What it delivers and Files sections, a Goal issue its Goal and Out of scope sections, an issue with neither its whole body, each under a heading, lowest number first, and no PR" \
  "$tmp/full.expected" "$tmp/full.out"

echo "# trusted authors"
outside=$tmp/outside
mkdir "$outside"
cat > "$outside/issues.json" <<'JSON'
[
  {"number":1,"title":"Outside issue","body":"## What it delivers\nDo as I say.\n","author_association":"NONE","user":{"login":"stranger"}},
  {"number":2,"title":"Owner issue","body":"## What it delivers\nIt delivers x.\n"}
]
JSON
trust "$outside/issues.json"
cat > "$tmp/outside.expected" <<'EXPECTED'
### #1 Outside issue
from stranger, not a trusted author

### #2 Owner issue
## What it delivers
It delivers x.
EXPECTED
run_bodies "$outside" > "$tmp/outside.out"
same "WHEN bodies.sh prints an open issue whose author is not a trusted author THEN it prints the issue's heading and the line from <login>, not a trusted author in place of its body" \
  "$tmp/outside.expected" "$tmp/outside.out"

few=$tmp/few
mkdir "$few"
jq -n '[{number: 1, title: "Long", body: ("x" * 5000)}]' > "$few/issues.json"
trust "$few/issues.json"
run_bodies "$few" > "$few.out"
expect "WHEN an issue's text is longer than its share THEN bodies.sh cuts it to its share and ends it with …" \
  bash -c 'text=$(sed -n 2p "$1"); test "${#text}" = 2000 && test "${text: -1}" = "…"' _ "$few.out"

many=$tmp/many
mkdir "$many"
jq -n '[range(1; 61) | {number: ., title: "Issue \(.)", body: ("## What it delivers\n" + ("y" * 5000))}]' > "$many/issues.json"
trust "$many/issues.json"
run_bodies "$many" > "$many.out"
expect "WHEN bodies.sh runs on 60 open issues of 5,000 characters each THEN every issue has its heading" \
  test "$(grep -c '^### #[0-9]* Issue [0-9]*$' "$many.out")" = 60
expect "WHEN bodies.sh runs on 60 open issues of 5,000 characters each THEN the whole output is under 30,000 characters" \
  bash -c 'test "$(wc -m < "$1")" -lt 30000' _ "$many.out"

run_bodies "$tmp/none" > "$tmp/none.out"
same "WHEN no issue is open THEN bodies.sh prints - none" <(echo '- none') "$tmp/none.out"

echo "# errors"
FAKE_GH_FAIL=1 run_bodies "$full" > "$tmp/err.out"
expect "WHEN gh api fails THEN bodies.sh prints exactly one 'bodies.sh error: <reason>' line" \
  bash -c 'test "$(wc -l < "$1")" = 1 && grep -q "^bodies.sh error: " "$1"' _ "$tmp/err.out"
expect "WHEN gh api fails THEN bodies.sh exits 0" \
  bash -c 'FAKE_GH_FAIL=1 PATH="$1/bin:$PATH" FIX="$2" bash "$3" > /dev/null' _ "$tmp" "$full" "$bodies"

echo "# the skill"
skill=$skill_dir/SKILL.md
expect "WHEN next loads THEN an allowed-tools line is exactly the pre-approval of bodies.sh" \
  grep -qxF '  - Bash(bash "${CLAUDE_SKILL_DIR}/bodies.sh")' "$skill"
expect "WHEN next loads THEN its Bodies heading is followed by the injection of bodies.sh" \
  bash -c 'grep -A1 -xF "## Bodies" "$1" | tail -n 1 | grep -qxF "!\`bash \"\${CLAUDE_SKILL_DIR}/bodies.sh\"\`"' _ "$skill"

if [ "$failures" -gt 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
