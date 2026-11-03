#!/usr/bin/env bash
# Tests for validate-plugins.sh with a stub `claude` on PATH that prints canned validate JSON.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/validate-plugins.sh"
failures=0

stubdir=$(mktemp -d)
trap 'rm -rf "$stubdir"' EXIT
cat > "$stubdir/claude" <<'STUB'
#!/usr/bin/env bash
cat "$STUB_JSON"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$stubdir/claude"

# expect <description> <exit code> <report json> [text the output must contain...]
expect() {
  local desc=$1 want=$2 json=$3 out code text ok=1
  shift 3
  printf '%s\n' "$json" > "$stubdir/report.json"
  out=$(PATH="$stubdir:$PATH" STUB_JSON="$stubdir/report.json" bash "$script" 2>&1) && code=0 || code=$?
  [ "$code" -eq "$want" ] || ok=0
  for text in "$@"; do [[ "$out" == *"$text"* ]] || ok=0; done
  if [ "$ok" -eq 1 ]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc (exit $code, want $want)"
    printf '%s\n' "$out" | sed 's/^/  /'
    failures=$((failures + 1))
  fi
}

expect "no errors and no warnings passes" 0 \
  '{"success":true,"manifest":{"errors":[],"warnings":[]}}'

expect "only the version warning passes" 0 \
  '{"success":true,"manifest":{"errors":[],"warnings":[{"path":"version","message":"No version specified"}]}}'

expect "the marketplace root's version warnings pass" 0 \
  '{"success":true,"manifest":{"errors":[],"warnings":[{"path":"plugins[0] plugin.json → version","message":"No version specified"}]}}'

expect "an error fails and is printed" 1 \
  '{"success":false,"manifest":{"errors":[{"path":"name","message":"name is required"}],"warnings":[]}}' \
  "name is required"

expect "a warning on another path fails and is printed" 1 \
  '{"success":true,"manifest":{"errors":[],"warnings":[{"path":"version","message":"No version specified"},{"path":"foo","message":"Unrecognized field foo"}]}}' \
  "Unrecognized field foo"

expect "a version warning beside an error still fails" 1 \
  '{"success":false,"manifest":{"errors":[{"path":"author","message":"author must be an object"}],"warnings":[{"path":"version","message":"No version specified"}]}}' \
  "author must be an object"

expect "output that is not JSON fails" 1 'not json'

[ "$failures" -eq 0 ]
