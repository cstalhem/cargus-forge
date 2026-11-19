#!/usr/bin/env bash
# Tests for validate-plugins.sh with a stub `claude` on PATH that prints a canned validate report.
# Each report below is the output of a real `claude plugin validate --json` run (Claude Code 2.1.327) on a
# one-file plugin, cut down to the keys the script reads: `success`, the manifest's errors and warnings, and
# each `contents` entry's type, errors and warnings.
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

# The real reports, one for each plugin or marketplace that the run read.
report_versioned='{"success":true,"manifest":{"errors":[],"warnings":[]},"contents":[]}'
report_version_warning='{"success":true,"manifest":{"errors":[],"warnings":[{"path":"version","message":"No version specified. Consider adding a version following semver (e.g., \"1.0.0\")","code":null}]},"contents":[]}'
report_marketplace='{"success":true,"manifest":{"errors":[],"warnings":[{"path":"plugins[0] plugin.json → version","message":"No version specified. Consider adding a version following semver (e.g., \"1.0.0\")","code":null}]},"contents":[]}'
report_manifest_error='{"success":false,"manifest":{"errors":[{"path":"name","message":"Invalid input: expected string, received undefined","code":null}],"warnings":[]},"contents":[]}'
report_manifest_warning=$(cat <<'JSON'
{"success":true,"manifest":{"errors":[],"warnings":[{"path":"foo","message":"Unknown field 'foo'. Claude Code ignores it at load time.","code":null},{"path":"version","message":"No version specified. Consider adding a version following semver (e.g., \"1.0.0\")","code":null}]},"contents":[]}
JSON
)
report_agent_warning='{"success":true,"manifest":{"errors":[],"warnings":[{"path":"version","message":"No version specified. Consider adding a version following semver (e.g., \"1.0.0\")","code":null}]},"contents":[{"type":"agent","errors":[],"warnings":[{"path":"description","message":"No description in frontmatter. A description helps users and Claude understand when to use this agent.","code":null}]}]}'
report_skill_error='{"success":false,"manifest":{"errors":[],"warnings":[{"path":"version","message":"No version specified. Consider adding a version following semver (e.g., \"1.0.0\")","code":null}]},"contents":[{"type":"skill","errors":[{"path":"allowed-tools","message":"allowed-tools must be a string or array of strings, got number.","code":null}],"warnings":[]}]}'

# expect <description> <exit code> <report json> [text the output must contain...]
expect() {
  local desc=$1 want=$2 json=$3 out code text ok=1 cli=0
  shift 3
  # The real claude exits 1 when its report says "success":false.
  [[ "$json" == *'"success":false'* ]] && cli=1
  printf '%s\n' "$json" > "$stubdir/report.json"
  out=$(PATH="$stubdir:$PATH" STUB_JSON="$stubdir/report.json" STUB_EXIT="$cli" bash "$script" 2>&1) && code=0 || code=$?
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

# fixture <description> <exit code> <skill body> [text the output must contain...]
# Runs a copy of the script on a repo with one plugin `p` whose skill `demo` has this body.
# The plugin holds references/present.md and the skill folder holds present.sh.
fixture() {
  local desc=$1 want=$2 body=$3 root real=$script
  shift 3
  root=$(mktemp -d)
  mkdir -p "$root/scripts" "$root/plugins/p/skills/demo" "$root/plugins/p/references"
  cp "$script" "$root/scripts/validate-plugins.sh"
  touch "$root/plugins/p/references/present.md" "$root/plugins/p/skills/demo/present.sh"
  printf '%s\n' "$body" > "$root/plugins/p/skills/demo/SKILL.md"
  script="$root/scripts/validate-plugins.sh"
  expect "$desc" "$want" "$report_versioned" "$@"
  script=$real
  rm -rf "$root"
}

expect "no errors and no warnings passes" 0 "$report_versioned"

expect "only the version warning passes" 0 "$report_version_warning"

expect "the marketplace root's version warnings pass" 0 "$report_marketplace"

expect "a manifest error fails and is printed" 1 "$report_manifest_error" \
  "expected string, received undefined"

expect "a manifest warning on another path fails and is printed" 1 "$report_manifest_warning" \
  "Unknown field 'foo'"

expect "an agent with no description fails and its warning is printed" 1 "$report_agent_warning" \
  "No description in frontmatter"

expect "a skill with an invalid allowed-tools fails and its error is printed" 1 "$report_skill_error" \
  "allowed-tools must be a string or array of strings"

expect "output that is not JSON fails" 1 'not json'

fixture "an injected plugin file that is missing fails and names the skill and the path" 1 \
  '!`cat "${CLAUDE_PLUGIN_ROOT}/references/missing.md"`' \
  "plugins/p/skills/demo/SKILL.md" "references/missing.md"

fixture "an injected skill file that is missing fails and names the skill and the path" 1 \
  '!`bash "${CLAUDE_SKILL_DIR}/missing.sh"`' \
  "plugins/p/skills/demo/SKILL.md" "missing.sh"

fixture "injected files that exist, and a read of docs/glossary.md, pass" 0 \
  '!`cat "${CLAUDE_PLUGIN_ROOT}/references/present.md"`
!`bash "${CLAUDE_SKILL_DIR}/present.sh"`
!`cat docs/glossary.md 2>/dev/null || printf "x"`
!`date +%F`'

[ "$failures" -eq 0 ]
