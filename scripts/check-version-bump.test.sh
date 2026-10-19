#!/usr/bin/env bash
# Tests for check-version-bump.sh against fixture git repos built under mktemp -d.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-version-bump.sh"
failures=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# manifest <name> <version>: write plugins/<name>/.claude-plugin/plugin.json.
manifest() {
  mkdir -p "plugins/$1/.claude-plugin"
  printf '{ "name": "%s", "version": "%s" }\n' "$1" "$2" > "plugins/$1/.claude-plugin/plugin.json"
}

commit() { git add -A && git commit -qm "$1"; }

# setup [version]: a repo on main with plugin "alpha" at <version>, then switch to branch "feature".
setup() {
  repo=$(mktemp -d)
  cd "$repo"
  git init -q -b main
  manifest alpha "${1:-1.0.0}"
  echo one > plugins/alpha/file.md
  commit base
  git switch -qc feature
}

# expect <description> <exit code> [text the output must contain...]: run the script on feature against main.
expect() {
  local desc=$1 want=$2 out code text ok=1
  shift 2
  out=$(cd / && bash "$script" main "$repo" 2>&1) && code=0 || code=$?
  [ "$code" -eq "$want" ] || ok=0
  for text in "$@"; do [[ "$out" == *"$text"* ]] || ok=0; done
  if [ "$ok" -eq 1 ]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc (exit $code, want $want)"
    printf '%s\n' "$out" | sed 's/^/  /'
    failures=$((failures + 1))
  fi
  rm -rf "$repo"
}

setup
echo two > plugins/alpha/file.md; commit change
expect "changed plugin without a bump fails" 1 alpha 1.0.0

setup
echo two > plugins/alpha/file.md; manifest alpha 0.9.0; commit change
expect "changed plugin with a lower version fails" 1 alpha 1.0.0 0.9.0

setup
echo two > plugins/alpha/file.md; manifest alpha 1.0.1; commit change
expect "changed plugin with a greater version passes" 0

setup 1.9.0
echo two > plugins/alpha/file.md; manifest alpha 1.10.0; commit change
expect "versions compare as numbers, not text" 0

setup
manifest beta 0.1.0; commit add
expect "new plugin passes" 0

setup
git rm -rq plugins/alpha; commit delete
expect "deleted plugin passes" 0

setup
echo x > README.md; commit readme
expect "change outside plugins passes" 0

setup
git switch -q main; echo two > plugins/alpha/file.md; commit main-change; git switch -q feature
expect "changes only on the base do not count" 0

setup
echo two > plugins/alpha/file.md; manifest alpha 1.0.1; commit change
git switch -q main; manifest alpha 1.1.0; commit main-bump; git switch -q feature
expect "compares against the merge-base, not the base tip" 0

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
