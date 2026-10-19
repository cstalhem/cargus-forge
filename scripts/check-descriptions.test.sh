#!/usr/bin/env bash
# Tests for check-descriptions.sh, run against fixture repos built under mktemp -d.
# Usage: bash scripts/check-descriptions.test.sh
set -u

script="$(cd "$(dirname "$0")" && pwd)/check-descriptions.sh"
failures=0
tmp=$(mktemp -d "${TMPDIR:-/tmp}/check-descriptions.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

# Prints the root of a new repo with plugins alpha and beta, whose listings all match.
fixture() {
  local root name
  root=$(mktemp -d "$tmp/repo.XXXXXX") || exit 1
  mkdir -p "$root/.claude-plugin"
  for name in alpha beta; do
    mkdir -p "$root/plugins/$name/.claude-plugin"
    printf '{"name":"%s","description":"The %s plugin."}\n' "$name" "$name" \
      > "$root/plugins/$name/.claude-plugin/plugin.json"
  done
  cat > "$root/.claude-plugin/marketplace.json" <<'EOF'
{"plugins":[
  {"name":"alpha","source":"./plugins/alpha","description":"The alpha plugin."},
  {"name":"beta","source":"./plugins/beta","description":"The beta plugin."}
]}
EOF
  cat > "$root/README.md" <<'EOF'
# Fixture

## Plugin Index
- **Alpha** (`plugins/alpha`): The alpha plugin.
- **Beta** (`plugins/beta`): The beta plugin.
EOF
  echo "$root"
}

# Rewrites a file in place with a sed expression (portable across BSD and GNU sed).
edit() {
  sed "$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# check <test name> <root> <expected exit code> <expected output>
check() {
  local name=$1 root=$2 want_code=$3 want_out=$4 out code
  out=$(bash "$script" "$root" 2>&1)
  code=$?
  if [[ $code -ne $want_code || $out != "$want_out" ]]; then
    printf 'FAIL %s\n  want exit %s: %q\n  got  exit %s: %q\n' "$name" "$want_code" "$want_out" "$code" "$out"
    failures=$((failures + 1))
  else
    echo "ok   $name"
  fi
}

root=$(fixture)
check "all listings match" "$root" 0 ""

root=$(fixture)
edit "$root/.claude-plugin/marketplace.json" 's/The alpha plugin\./Another alpha./'
check "marketplace.json differs" "$root" 1 "alpha: marketplace.json differs from plugin.json"

root=$(fixture)
edit "$root/README.md" 's/The beta plugin\./Another beta./'
check "README differs" "$root" 1 "beta: README.md differs from plugin.json"

root=$(fixture)
edit "$root/plugins/alpha/.claude-plugin/plugin.json" 's/The alpha plugin\./Another alpha./'
check "plugin.json differs from both" "$root" 1 "alpha: marketplace.json differs from plugin.json
alpha: README.md differs from plugin.json"

root=$(fixture)
printf '\n## Other\n- **Beta** (`plugins/beta`): Something else.\n' >> "$root/README.md"
check "README lines outside the Plugin Index are ignored" "$root" 0 ""

[[ $failures -eq 0 ]] || { echo "$failures failed"; exit 1; }
