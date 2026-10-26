#!/usr/bin/env bash
# Tests for apply.sh in fixture repos built under mktemp -d. They need no network: a stub
# `git` and a stub `gh` come first on PATH, and each records its call and fails.
set -u

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
script="$here/../apply.sh"
templates=$(CDPATH= cd -- "$here/../../../templates" && pwd)
workflow_template="$templates/close-sub-issue.yml"
tracker_template="$templates/issue-tracker.md"
workflow=.github/workflows/close-sub-issue.yml
tracker=docs/agents/issue-tracker.md
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

# head_of <repo> <default branch>: the template with the facts, up to and including its
# `## Notes` line. Built with bash substitution, not with sed as apply.sh does.
head_of() {
  local line
  while IFS= read -r line; do
    line=${line//"{{repo}}"/"$1"}
    line=${line//"{{default_branch}}"/"$2"}
    printf '%s\n' "$line"
    [ "$line" = "## Notes" ] && break
  done < "$tracker_template"
}

# tracker_of <repo> <default branch> <notes>: a whole issue-tracker.md, written to stdout.
tracker_of() {
  head_of "$1" "$2"
  printf '%s' "$3"
}

# same <file> <repo> <default branch> <notes>: the file in $repo is that issue-tracker.md, byte for byte.
same() {
  tracker_of "$2" "$3" "$4" > "$root/expected"
  cmp -s "$root/expected" "$repo/$1"
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
expect "the workflow run writes no issue tracker" test ! -e "$repo/docs"

fixture
mkdir -p "$repo/.github/workflows"
printf 'name: an old copy\n' > "$repo/$workflow"
run --behaviour close-sub-issue --behaviour close-sub-issue
expect "a copy that differs is replaced by the template" cmp -s "$workflow_template" "$repo/$workflow"
expect "a behaviour named twice is written and printed once" printed "$workflow"

# An issue-tracker.md that setup wrote: the facts are rendered again, the notes kept.
notes_cases=(
  $'- one note\n\n- a `{{repo}}` and a `{{default_branch}}` that stay\n## Notes\n'
  $'- notes that end in blank lines\n\n\n'
  $'- a last line with no newline'
  $'\n'
  ''
)
notes_names=(
  "notes with placeholders and a second Notes heading"
  "notes that end in blank lines"
  "notes with no final newline"
  "notes of one blank line"
  "empty notes"
)
for i in "${!notes_cases[@]}"; do
  fixture
  mkdir -p "$repo/docs/agents"
  tracker_of old/name old-branch "${notes_cases[$i]}" > "$repo/$tracker"
  run --issue-tracker --repo new/name --default-branch trunk
  expect "re-render, ${notes_names[$i]}: new facts and the same notes" \
    same "$tracker" new/name trunk "${notes_cases[$i]}"
  expect "re-render, ${notes_names[$i]}: prints the issue tracker's path" printed "$tracker"
done

fixture
mkdir -p "$repo/docs/agents"
head_of old/name main | sed '$d' > "$repo/$tracker"
printf -- '- a line someone added above the notes\n## Notes\n- kept\n' >> "$repo/$tracker"
run --issue-tracker --repo new/name --default-branch main
expect "re-render replaces text above ## Notes, which setup owns" same "$tracker" new/name main $'- kept\n'

fixture
mkdir -p "$repo/docs/agents"
head_of old/name main > "$repo/$tracker"
printf '%s' "$(cat "$repo/$tracker")" > "$root/no-newline"
cp "$root/no-newline" "$repo/$tracker"
run --issue-tracker --repo new/name --default-branch main
expect "re-render of a file that ends at ## Notes with no newline" same "$tracker" new/name main ''

# An issue-tracker.md that setup did not write: with --adopt, its whole text moves under
# ## Notes, byte for byte, and the facts are rendered above it (#151 D2).
adopt_cases=(
  $'# Issue tracker\n\n- Branches are named `feature/<slug>`.\n- Rebase-merge every PR.\n'
  $'# Tracker\n\n## Notes\n- a Notes heading of its own\n'
  $'- a last line with no newline'
  $'# Tracker\r\n\r\n- CRLF lines\r\n'
  $'<!-- Written by hand. -->\n- a comment that is not the marker\n'
  ''
)
adopt_names=(
  "a hand-written file"
  "a file with its own ## Notes line"
  "a file with no final newline"
  "a file with CRLF lines"
  "a file whose first line is another comment"
  "an empty file"
)
for i in "${!adopt_cases[@]}"; do
  fixture
  mkdir -p "$repo/docs/agents"
  printf '%s' "${adopt_cases[$i]}" > "$repo/$tracker"
  run --issue-tracker --adopt --repo owner/name --default-branch main
  expect "adopt, ${adopt_names[$i]}: the facts, then the whole old text under ## Notes" \
    same "$tracker" owner/name main "${adopt_cases[$i]}"
  expect "adopt, ${adopt_names[$i]}: prints the issue tracker's path" printed "$tracker"
done

fixture
mkdir -p "$repo/docs/agents"
printf '# Issue tracker\n\nWritten by hand.\n' > "$repo/$tracker"
run --issue-tracker --adopt --repo owner/name --default-branch main
cp "$repo/$tracker" "$root/adopted"
run --issue-tracker --repo owner/name --default-branch main
expect "an adopted file is then one that setup wrote: a re-render without --adopt changes no byte" \
  cmp -s "$root/adopted" "$repo/$tracker"

# No issue-tracker.md yet.
fixture
run --issue-tracker --repo owner/name --default-branch main
expect "no docs/agents: writes the template with the facts and empty notes" same "$tracker" owner/name main ''
expect "no docs/agents: prints the issue tracker's path" printed "$tracker"
expect "no docs/agents: writes no workflow" test ! -e "$repo/.github"

fixture
mkdir -p "$repo/docs/agents"
run --issue-tracker --repo owner/name --default-branch main
expect "docs/agents with no issue-tracker.md: writes the template with empty notes" same "$tracker" owner/name main ''

# Values that sed would read as syntax.
fixture
run --issue-tracker --repo 'a#b/c&d' --default-branch 'x/y&z#w\v|u'
expect "a value with #, &, /, \\ or | is written as it is" same "$tracker" 'a#b/c&d' 'x/y&z#w\v|u' ''

# Both at once: each path printed, only the named paths written, commands.md never written.
fixture
mkdir -p "$repo/docs/agents"
printf '# Commands\n\nkept\n' > "$repo/docs/agents/commands.md"
printf 'other\n' > "$repo/other.txt"
before=$(tree)
run --issue-tracker --repo owner/name --default-branch main --behaviour close-sub-issue
expect "both: prints each path it wrote" printed "$workflow" "$tracker"
expect "both: commands.md and other files are unchanged, only the named paths are added" \
  test "$(tree | grep -v -e " ./$workflow\$" -e " ./$tracker\$")" = "$before"
expect "both: the files are the ones named" \
  test "$(cd "$repo" && find . -type f | sort | tr '\n' ' ')" \
    = "./.github/workflows/close-sub-issue.yml ./docs/agents/commands.md ./docs/agents/issue-tracker.md ./other.txt "

fixture
run --issue-tracker --repo owner/name --default-branch main --behaviour close-sub-issue
expect "both: no commands.md is created" test ! -e "$repo/docs/agents/commands.md"

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
unmarked() {
  mkdir -p "$repo/docs/agents"
  printf '# Issue tracker\n\nWritten by hand.\n\n## Notes\n- mine\n' > "$repo/$tracker"
}
no_notes() {
  mkdir -p "$repo/docs/agents"
  head_of owner/name main | sed '$d' > "$repo/$tracker"
}
fails "no arguments" nothing
fails "an unknown argument" nothing --verbose
fails "an unknown behaviour" nothing --behaviour auto-merge
fails "--behaviour with no value" nothing --behaviour
fails "--issue-tracker with no --repo" nothing --issue-tracker --default-branch main --behaviour close-sub-issue
fails "--issue-tracker with no --default-branch" nothing --issue-tracker --repo owner/name
fails "--repo followed by another option" nothing --repo --issue-tracker --default-branch main
fails "a value with a newline" nothing --issue-tracker --repo owner/name --default-branch $'main\nx'
fails "an issue-tracker.md with no marker line" unmarked \
  --issue-tracker --repo owner/name --default-branch main --behaviour close-sub-issue
fails "an issue-tracker.md with no ## Notes line" no_notes \
  --issue-tracker --repo owner/name --default-branch main
marked() {
  mkdir -p "$repo/docs/agents"
  tracker_of owner/name main $'- mine\n' > "$repo/$tracker"
}
fails "--adopt on an issue-tracker.md that setup wrote" marked \
  --issue-tracker --adopt --repo owner/name --default-branch main --behaviour close-sub-issue
fails "--adopt with no issue-tracker.md" nothing \
  --issue-tracker --adopt --repo owner/name --default-branch main --behaviour close-sub-issue
fails "--adopt with no --issue-tracker" unmarked --adopt --behaviour close-sub-issue

# No run above called git or gh.
code=0 out="$calls" err=/dev/null
expect "no run called git or gh" test ! -s "$calls"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
