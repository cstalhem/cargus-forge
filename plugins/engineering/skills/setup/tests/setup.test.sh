#!/usr/bin/env bash
# Tests for setup.sh against fixture repos built under mktemp -d. A stub `gh`, first on PATH,
# returns fixture JSON, so the tests need no network (#148 D1).
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script=$here/../setup.sh
templates=$(cd "$here/../../../templates" && pwd)
failures=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# git looks for no repo above $tmp, so a directory under it that is not a fixture repo is in
# no repo at all.
export GIT_CEILING_DIRECTORIES=$tmp

# The stub gh: logs each call, then fails with $GH_FAIL if it is set, or prints $GH_JSON.
mkdir "$tmp/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >> "$GH_LOG"' \
  'if [ -n "${GH_FAIL:-}" ]; then printf "%s\n" "$GH_FAIL" >&2; exit 1; fi' \
  'printf "%s\n" "$GH_JSON"' > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" GH_LOG=$tmp/gh.log

# gh_repo [default branch] [allow_squash_merge]: the JSON that the stub returns for the repo.
# An allow_squash_merge of "none" leaves the field out, as GitHub does for a read-only token.
gh_repo() {
  GH_JSON=$(jq -nc --arg b "${1:-main}" --arg s "${2:-true}" '
    {full_name: "acme/widget", default_branch: $b}
    + (if $s == "none" then {} else {allow_squash_merge: ($s == "true")} end)')
  export GH_JSON
  unset GH_FAIL
}

# setup: a new fixture repo with one commit, on main, with the stub's default answer.
setup() {
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  cd "$repo" || exit 1
  git init -q -b main
  echo widget > README.md
  git add -A && git commit -qm base
  gh_repo
}

# issue_tracker <default branch>: write docs/agents/issue-tracker.md as setup renders it, with
# the same sed as the #147 check, and a note.
issue_tracker() {
  mkdir -p docs/agents
  sed -e 's#{{repo}}#acme/widget#' -e "s#{{default_branch}}#$1#" "$templates/issue-tracker.md" \
    > docs/agents/issue-tracker.md
  printf '%s\n' '- A note that setup never reads.' >> docs/agents/issue-tracker.md
}

# A listing of every path under the repo, .git included, with each file's checksum.
snapshot() {
  (cd "$repo" && find . | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort)
}

# check <description>: start a test.
check() { desc=$1; ok=1; why=''; }
miss() { ok=0; why+="  $1"$'\n'; }

# run [dir]: run setup.sh in <dir>, the fixture repo by default, and set `out`. Checks that it
# exits 0, changes no file in the repo, and calls gh only to read the repo.
run() {
  local dir=${1:-$repo} before after code calls
  before=$(snapshot)
  : > "$GH_LOG"
  out=$(cd "$dir" && bash "$script" 2>&1) && code=0 || code=$?
  after=$(snapshot)
  [ "$code" -eq 0 ] || miss "exit $code, want 0"
  [ "$before" = "$after" ] || miss "the run changed a file in the repo"
  calls=$(grep -vxF 'api repos/{owner}/{repo}' "$GH_LOG")
  [ -z "$calls" ] || miss "unexpected gh calls: $calls"
}

has() { local t; for t in "$@"; do [[ "$out" == *"$t"* ]] || miss "missing: $t"; done; }
lacks() { local t; for t in "$@"; do [[ "$out" != *"$t"* ]] || miss "unexpected: $t"; done; }

# error <text>: the output is one `setup.sh error:` line that holds <text>, and nothing else.
error() {
  [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] || miss "not one line"
  [[ "$out" == "setup.sh error: "* ]] || miss "does not start with setup.sh error:"
  has "$1"
}

done_check() {
  if [ "$ok" -eq 1 ]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc"
    printf '%s' "$why"
    printf '%s\n' "$out" | sed 's/^/  | /'
    failures=$((failures + 1))
  fi
}

nl=$'\n'

setup
check "a new repo: prints the facts, every file missing, no commands and no warnings"
run
[ "${out%%"$nl"*}" = '## Facts' ] || miss "the first line is not ## Facts"
has '### Repo' \
  '- repo: `acme/widget`' \
  '- default branch: `main`' \
  '- allow_squash_merge: `true`' \
  '- `docs/agents/issue-tracker.md` · missing' \
  '- `docs/agents/commands.md` · missing' \
  '- close-sub-issue · `.github/workflows/close-sub-issue.yml` · missing' \
  "### Commands$nl- none" \
  "## Warnings$nl- none"
done_check

setup
check "files that setup wrote are current, whatever the notes hold, and commands.md is present"
issue_tracker main
printf '# Commands\n' > docs/agents/commands.md
mkdir -p .github/workflows
cp "$templates/close-sub-issue.yml" .github/workflows/close-sub-issue.yml
git add -A && git commit -qm profile
run
has '- `docs/agents/issue-tracker.md` · current' \
  '- `docs/agents/commands.md` · present' \
  '- close-sub-issue · `.github/workflows/close-sub-issue.yml` · current'
lacks '```diff'
done_check

setup
check "files that are not committed are read from the working tree"
issue_tracker main
run
has '- `docs/agents/issue-tracker.md` · current'
done_check

setup
check "an issue-tracker.md with other facts differs, with a diff of the part up to ## Notes"
issue_tracker develop
run
has '- `docs/agents/issue-tracker.md` · differs' \
  '```diff' \
  '-- **Default branch:** `develop`.' \
  '+- **Default branch:** `main`.'
lacks 'A note that setup never reads'
done_check

setup
check "an issue-tracker.md without a ## Notes line differs"
mkdir -p docs/agents
printf '# Issue tracker\n\nWe use GitHub.\n' > docs/agents/issue-tracker.md
run
has '- `docs/agents/issue-tracker.md` · differs' '-We use GitHub.'
done_check

setup
check "a workflow copy that differs from the template is printed as differs, with the diff"
mkdir -p .github/workflows
sed 's/^name: .*/name: our own name/' "$templates/close-sub-issue.yml" > .github/workflows/close-sub-issue.yml
cmp -s "$templates/close-sub-issue.yml" .github/workflows/close-sub-issue.yml && miss "the fixture copy does not differ"
run
has '- close-sub-issue · `.github/workflows/close-sub-issue.yml` · differs' \
  '```diff' \
  '--- .github/workflows/close-sub-issue.yml' \
  '+++ templates/close-sub-issue.yml' \
  '-name: our own name'
done_check

setup
check "a default branch other than main gives a warning"
gh_repo develop
issue_tracker develop
run
has '- default branch: `develop`' \
  '- `docs/agents/issue-tracker.md` · current' \
  'The default branch is `develop`, not `main`. ship and the final PR still assume `main`.'
lacks "## Warnings$nl- none" '#85'
done_check

setup
check "a default branch with & and # renders literally, so the file apply.sh writes is current"
branch='fix&it#2'
gh_repo "$branch"
mkdir -p docs/agents
text=$(cat "$templates/issue-tracker.md"; printf x)
text=${text%x}
text=${text//'{{repo}}'/'acme/widget'}
text=${text//'{{default_branch}}'/"$branch"}
printf '%s' "$text" > docs/agents/issue-tracker.md
[[ "$text" == *'`fix&it#2`'* ]] || miss "the fixture does not hold the branch name"
run
has '- `docs/agents/issue-tracker.md` · current'
done_check

setup
check "allow_squash_merge off gives a warning"
gh_repo main false
run
has '- allow_squash_merge: `false`' '- `allow_squash_merge` is off'
done_check

setup
check "allow_squash_merge that the token cannot read is unknown, with a warning"
gh_repo main none
run
has '- allow_squash_merge: `unknown`' '- `allow_squash_merge` is unknown'
done_check

setup
check "each command is printed with its source"
printf '%s\n' '{ "scripts": { "test": "jest --ci", "lint": "eslint ." } }' > package.json
: > pnpm-lock.yaml
printf '%s\n' \
  '.PHONY: build test' \
  'VERSION := 1.0' \
  'CC ?= cc' \
  'build test: deps' \
  '	$(CC) -o app main.c' \
  '%.o: %.c' \
  'lint:' > Makefile
printf '%s\n' \
  '[project]' \
  'name = "widget"' \
  '' \
  '[tool.poe.tasks]' \
  'check = "ruff check ."' \
  '' \
  '[tool.hatch.envs.default.scripts]' \
  'cov = "pytest --cov"' \
  '' \
  '[tool.pytest.ini_options]' \
  'addopts = "-q"' > pyproject.toml
mkdir -p .github/workflows
printf '%s\n' \
  'jobs:' \
  '  test:' \
  '    steps:' \
  '      - run: npm ci' \
  '      - name: Test' \
  '        run: |' \
  '          npm test' \
  '          npm run lint \' \
  '            --fix' \
  '          if true; then' \
  '          fi' \
  '        shell: bash' \
  "      - run: 'make build'" > .github/workflows/ci.yml
cp "$templates/close-sub-issue.yml" .github/workflows/close-sub-issue.yml
run
has '- pnpm run test · package.json: jest --ci' \
  '- pnpm run lint · package.json: eslint .' \
  '- make build · Makefile:4' \
  '- make test · Makefile:4' \
  '- make lint · Makefile:7' \
  '- poe check · pyproject.toml [tool.poe.tasks]' \
  '- hatch run cov · pyproject.toml [tool.hatch.envs.default.scripts]' \
  '- pytest · pyproject.toml [tool.pytest.ini_options]' \
  '- npm ci · .github/workflows/ci.yml:4' \
  '- npm test · .github/workflows/ci.yml:7' \
  '- npm run lint --fix · .github/workflows/ci.yml:8' \
  '- if true; then · .github/workflows/ci.yml:10' \
  '- make build · .github/workflows/ci.yml:13'
lacks 'make .PHONY' 'make VERSION' 'make CC' 'make %.o' '- name =' '- fi ·' 'shell: bash' \
  'first_line=' 'close-sub-issue.yml:'
done_check

setup
check "a package.json that is not valid JSON is reported among the commands, not as an error"
printf '{ "scripts": \n' > package.json
run
has '### Commands' '- package.json is not valid JSON, so its scripts were not read'
done_check

setup
check "run from a subdirectory, it reads the files at the top of the repo"
issue_tracker main
mkdir -p sub/dir
run "$repo/sub/dir"
has '- `docs/agents/issue-tracker.md` · current'
done_check

setup
check "a failing gh call prints one setup.sh error line and exits 0"
export GH_FAIL="HTTP 401: Bad credentials${nl}second line"
run
error 'gh api repos/{owner}/{repo}: HTTP 401: Bad credentials second line'
done_check

setup
check "a gh call that returns no repo prints one setup.sh error line and exits 0"
export GH_JSON='{"message": "Not Found"}'
run
error 'did not return a repo'
done_check

setup
check "a failing git call, outside a git repo, prints one setup.sh error line and exits 0"
repo=$(mktemp -d "$tmp/norepo.XXXXXX")
run
error 'git rev-parse --show-toplevel:'
done_check

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
