#!/usr/bin/env bash
# Tests for apply.sh in fixture repos built under mktemp -d. They need no network: a stub
# `git` and a stub `gh` come first on PATH, and each records its call and fails.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
script="$here/../apply.sh"
templates=$(CDPATH= cd -- "$here/../../../templates" && pwd)
workflow_template="$templates/close-sub-issue.yml"
workflow=.github/workflows/close-sub-issue.yml
failures=0

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir "$root/stubs"
calls="$root/calls"
: > "$calls"
for tool in git gh; do
  printf '%s\n' '#!/bin/sh' "echo \"$tool \$*\" >> '$calls'" 'exit 1' > "$root/stubs/$tool"
  chmod +x "$root/stubs/$tool"
done
export PATH="$root/stubs:$PATH"

# fixture: a new empty repo directory in $repo.
fixture() {
  repo=$(mktemp -d "$root/repo.XXXXXX")
}

# run [args...]: run apply.sh from the root of $repo. Sets $code, and $out and $err to the
# files that hold its stdout and stderr.
run() {
  out="$root/out" err="$root/err"
  (cd "$repo" && bash "$script" "$@") > "$out" 2> "$err" && code=0 || code=$?
}

# expect <description> <command...>: the command must succeed.
expect() {
  local desc=$1
  shift
  if "$@"; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc (exit $code)"
    sed 's/^/  stdout: /' "$out"
    sed 's/^/  stderr: /' "$err"
    failures=$((failures + 1))
  fi
}

# printed <line...>: stdout holds exactly these lines.
printed() {
  [ "$(cat "$out"; echo x)" = "$(printf '%s\n' "$@"; echo x)" ]
}

# tree: each file in $repo with its checksum, to see that a run changed nothing.
tree() {
  (cd "$repo" && find . -type f -exec cksum {} + | sort)
}

code=0 out=/dev/null err=/dev/null
expect "the git and gh stubs come first on PATH" \
  test "$(command -v git) $(command -v gh)" = "$root/stubs/git $root/stubs/gh"

# The close-sub-issue workflow.
fixture
run --behaviour close-sub-issue
expect "the workflow is byte-identical to the template" cmp -s "$workflow_template" "$repo/$workflow"
expect "the workflow run prints only the workflow's path" printed "$workflow"
expect "the workflow run writes nothing under docs/" test ! -e "$repo/docs"

fixture
mkdir -p "$repo/.github/workflows"
printf 'name: an old copy\n' > "$repo/$workflow"
run --behaviour close-sub-issue --behaviour close-sub-issue
expect "a copy that differs is replaced by the template" cmp -s "$workflow_template" "$repo/$workflow"
expect "a behaviour named twice is written and printed once" printed "$workflow"

# Only the named paths are written, and commands.md never is.
fixture
mkdir -p "$repo/docs/agents"
printf '# Commands\n\nkept\n' > "$repo/docs/agents/commands.md"
printf 'other\n' > "$repo/other.txt"
before=$(tree)
run --behaviour close-sub-issue
expect "commands.md and other files are unchanged, only the named path is added" \
  test "$(tree | grep -v -e " ./$workflow\$")" = "$before"
expect "the files are the ones named" \
  test "$(cd "$repo" && find . -type f | sort | tr '\n' ' ')" \
    = "./.github/workflows/close-sub-issue.yml ./docs/agents/commands.md ./other.txt "

# Errors: one `apply.sh error:` line, exit 1, and nothing written.
# fails <description> <setup command> <args...>: the setup command prepares $repo.
fails() {
  local desc=$1 prepare=$2 before
  shift 2
  fixture
  $prepare
  before=$(tree)
  run "$@"
  expect "$desc: exits 1" test "$code" = 1
  expect "$desc: prints one apply.sh error line" \
    test "$(wc -l < "$err" | tr -d ' ')" = 1 -a "$(grep -c '^apply\.sh error: ' "$err")" = 1
  expect "$desc: prints no path" test ! -s "$out"
  expect "$desc: writes nothing" test "$(tree)" = "$before"
}
nothing() { :; }
fails "no arguments" nothing
fails "an unknown argument" nothing --verbose
fails "an unknown argument after a behaviour" nothing --behaviour close-sub-issue --repo owner/name
fails "an unknown behaviour" nothing --behaviour auto-merge
fails "--behaviour with no value" nothing --behaviour
fails "--behaviour followed by another option" nothing --behaviour --behaviour close-sub-issue

# No run above called git or gh.
code=0 out="$calls" err=/dev/null
expect "no run called git or gh" test ! -s "$calls"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
