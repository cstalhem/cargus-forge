#!/usr/bin/env bash
# Tests for setup.sh against fixture repos built under mktemp -d. A stub `gh`, first on PATH,
# returns fixture JSON, and each fixture repo's `origin` is a local bare repo, so the tests
# need no network (#148 D1).
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script=$here/../setup.sh
apply=$here/../apply.sh
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

# The stub gh: logs each call, then fails with $GH_FAIL if it is set. For the repo it prints
# $GH_JSON. For page <p> of the open issues it fails with $GH_FAIL_ISSUES if it is set, or
# prints the file $GH_PAGES/<p>, or `[]`. Any other call fails. The pages are files, not
# variables, because Linux limits one variable in the environment to 128 KiB, as it does one
# argument.
mkdir "$tmp/bin" "$tmp/pages"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >> "$GH_LOG"' \
  'if [ -n "${GH_FAIL:-}" ]; then printf "%s\n" "$GH_FAIL" >&2; exit 1; fi' \
  'case $2 in' \
  '  "repos/{owner}/{repo}") printf "%s\n" "$GH_JSON" ;;' \
  '  "repos/{owner}/{repo}/issues?state=open&per_page=100&page="*)' \
  '    if [ -n "${GH_FAIL_ISSUES:-}" ]; then printf "%s\n" "$GH_FAIL_ISSUES" >&2; exit 1; fi' \
  '    page=$GH_PAGES/${2##*page=}' \
  '    if [ -f "$page" ]; then cat "$page"; else printf "[]\n"; fi ;;' \
  '  *) printf "stub gh: unexpected call: %s\n" "$*" >&2; exit 1 ;;' \
  'esac' > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" GH_LOG=$tmp/gh.log GH_PAGES=$tmp/pages

# gh_repo [default branch] [allow_squash_merge]: the JSON that the stub returns for the repo,
# and no open issues. An allow_squash_merge of "none" leaves the field out, as GitHub does for
# a read-only token.
gh_repo() {
  GH_JSON=$(jq -nc --arg b "${1:-main}" --arg s "${2:-true}" '
    {full_name: "acme/widget", default_branch: $b}
    + (if $s == "none" then {} else {allow_squash_merge: ($s == "true")} end)')
  export GH_JSON
  unset GH_FAIL GH_FAIL_ISSUES
  rm -f "$GH_PAGES"/*
}

# page <p> <json>: page <p> of the open issues.
page() { printf '%s\n' "$2" > "$GH_PAGES/$1"; }

# issues <n>...: page 1 of the open issues. `pr:<n>` is a PR, which the endpoint lists too.
issues() {
  printf '%s\n' "$@" | jq -R 'if startswith("pr:") then {number: (.[3:] | tonumber), pull_request: {}} else {number: tonumber} end' \
    | jq -sc . > "$GH_PAGES/1"
}

# setup: a new fixture repo with one commit, on main, with a local bare repo as `origin` that
# holds main, and the stub's default answer.
setup() {
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  remote=$repo.remote
  git init -q --bare "$remote"
  cd "$repo" || exit 1
  git init -q -b main
  echo widget > README.md
  git add -A && git commit -qm base
  git remote add origin "$remote"
  git push -q origin main
  gh_repo
}

# branches <name>...: push each branch to origin, at main.
branches() {
  local b
  for b in "$@"; do git push -q origin "main:refs/heads/$b" || exit 1; done
}

# issue_tracker <default branch>: write docs/agents/issue-tracker.md as setup renders it, with
# the same sed as the #147 check, and a note.
issue_tracker() {
  mkdir -p docs/agents
  sed -e 's#{{repo}}#acme/widget#' -e "s#{{default_branch}}#$1#" "$templates/issue-tracker.md" \
    > docs/agents/issue-tracker.md
  printf '%s\n' '- A note that setup never reads.' >> docs/agents/issue-tracker.md
}

# A listing of every path under the repo, .git included, and under its origin, with each
# file's checksum.
snapshot() {
  local d
  for d in "$repo" "$remote"; do
    [ -d "$d" ] || continue
    (cd "$d" && find . | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort)
  done
}

# check <description>: start a test.
check() { desc=$1; ok=1; why=''; }
miss() { ok=0; why+="  $1"$'\n'; }

# run [dir]: run setup.sh in <dir>, the fixture repo by default, and set `out`. Checks that it
# exits 0, changes no file or branch in the repo or its origin, and calls gh only to read the
# repo and its open issues.
run() {
  local dir=${1:-$repo} before after code calls
  before=$(snapshot)
  : > "$GH_LOG"
  out=$(cd "$dir" && bash "$script" 2>&1) && code=0 || code=$?
  after=$(snapshot)
  [ "$code" -eq 0 ] || miss "exit $code, want 0"
  [ "$before" = "$after" ] || miss "the run changed a file or a branch in the repo or its origin"
  calls=$(grep -vxF 'api repos/{owner}/{repo}' "$GH_LOG" \
    | grep -vx 'api repos/{owner}/{repo}/issues?state=open&per_page=100&page=[0-9]*')
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
check "a new repo: prints the facts, every file missing, no commands, branches or docs, and no warnings"
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
  "### Branches$nl- branches: none other than the default branch, \`dependabot/*\` and \`renovate/*\`$nl" \
  "### Docs$nl- none$nl" \
  "## Warnings$nl- none"
grep -qx 'api repos/{owner}/{repo}/issues?state=open&per_page=100&page=1' "$GH_LOG" \
  || miss "the open issues were not read with gh api REST"
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
check "an issue-tracker.md with the marker line but no ## Notes line differs"
mkdir -p docs/agents
sed '/^## Notes$/d' "$templates/issue-tracker.md" | sed 's#{{repo}}#acme/widget#; s#{{default_branch}}#main#' \
  > docs/agents/issue-tracker.md
printf 'We use GitHub.\n' >> docs/agents/issue-tracker.md
run
has '- `docs/agents/issue-tracker.md` · differs' '-We use GitHub.'
lacks 'not written by setup'
done_check

setup
check "an issue-tracker.md that setup did not write is printed whole, in a fence that no line of it closes"
mkdir -p docs/agents
printf '%s\n' '# Issue tracker' '' '- Branches are named `feature/<slug>`.' '- Rebase-merge every PR.' \
  '```sh' 'git rebase main' '```' '## Notes' '- a note' > docs/agents/issue-tracker.md
run
has "- \`docs/agents/issue-tracker.md\` · not written by setup$nl\`\`\`\`markdown$nl# Issue tracker$nl" \
  '- Branches are named `feature/<slug>`.' \
  "- Rebase-merge every PR.$nl\`\`\`sh${nl}git rebase main$nl\`\`\`$nl## Notes$nl- a note$nl\`\`\`\`$nl"
lacks '```diff' '· differs'
done_check

setup
check "a file whose first line is another comment, or that has the marker text later, is not written by setup"
mkdir -p docs/agents
printf '%s\n' '<!-- Written by hand. -->' '<!-- Written by /engineering:setup. Edit only under ## Notes. -->' \
  > docs/agents/issue-tracker.md
run
has '- `docs/agents/issue-tracker.md` · not written by setup' "$nl\`\`\`markdown$nl<!-- Written by hand. -->$nl"
done_check

setup
check "after apply.sh --adopt moves the text under ## Notes, the file is current"
mkdir -p docs/agents
printf '%s\n' '# Issue tracker' '' '- Squash-merge every PR.' > docs/agents/issue-tracker.md
cp docs/agents/issue-tracker.md "$tmp/old-tracker"
bash "$apply" --issue-tracker --adopt --repo acme/widget --default-branch main > /dev/null \
  || miss "apply.sh --adopt failed"
tail -n 3 docs/agents/issue-tracker.md | cmp -s - "$tmp/old-tracker" || miss "the old text is not at the end"
run
has '- `docs/agents/issue-tracker.md` · current'
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
check "an open issue with one <n>-* branch gives a warning with a suggested action, and no branch changes"
branches 7-login 70-other 9-a-pr 12-closed
issues 7 pr:9
run
has '- branches: 4 of 4 match `<n>-*`, leaving out the default branch, `dependabot/*` and `renovate/*`' \
  '- convention: `<n>-<slug>`' \
  '- #7 · `7-login`' \
  '- Open issue #7 has a branch that matches `7-*`: `7-login`. The plugin'"'"'s skills take it as the branch of #7 and build on it. If it holds other work, rename it so that its name does not start with `7-`. Setup changes no branch.'
lacks '`70-other`' '#9' '#12' 'another one'
[ "$(git ls-remote --heads origin | wc -l | tr -d ' ')" = 5 ] || miss "the remote does not hold its 5 branches"
done_check

setup
check "an open issue with more than one <n>-* branch gives a warning with a suggested action"
branches 12-a 12-b 3-only
issues 12 3
run
has '- #3 · `3-only`' \
  '- #12 · `12-a`, `12-b`' \
  '- Open issue #12 has 2 branches that match `12-*`: `12-a`, `12-b`. The plugin'"'"'s skills stop when more than one branch matches. Keep the one that holds the work for #12, and rename the others. Setup changes no branch.' \
  '- Open issue #3 has a branch that matches `3-*`'
[[ "$out" == *'- #3 · '*'- #12 · '* ]] || miss "the issues are not in number order"
done_check

setup
check "most branches follow another convention: setup names the most common prefix and states <n>-<slug>"
branches feature/a feature/b fix/c 12-x dependabot/npm/x renovate/y renovate/z
run
has '- branches: 1 of 4 match `<n>-*`' \
  '- convention: another one, most common prefix `feature/` (2 of 4 branches)' \
  '- 3 of 4 branches do not match `<n>-*`, and their most common prefix is `feature/` (2 branches). The plugin uses `<n>-<slug>`'
lacks 'dependabot/npm/x' 'renovate/y' 'renovate/z'
done_check

setup
check "branches without a slash give a prefix up to their first - or _"
branches jira-1-a jira-2-b dev_x main2 1-a
run
has '- convention: another one, most common prefix `jira-` (2 of 5 branches)'
done_check

setup
check "exactly half of the branches not matching is not another convention"
branches 1-a 2-b feature/a feature/b
run
has '- branches: 2 of 4 match `<n>-*`' '- convention: `<n>-<slug>`'
lacks 'another one' 'The plugin uses'
done_check

setup
check "the default branch and the bots' branches are left out of the count"
gh_repo trunk
branches trunk 1-a dependabot/a dependabot/b renovate/c
run
has '- branches: 1 of 2 match `<n>-*`' '- convention: `<n>-<slug>`'
lacks 'another one'
done_check

setup
check "the open issues are read page by page, and a PR on a page is not an issue"
page 1 "$(jq -nc '[range(1000; 1099) | {number: .}] + [{number: 5, pull_request: {}}]')"
page 2 '[{"number": 6}]'
branches 5-pr 6-second-page
run
has '- #6 · `6-second-page`'
lacks '- #5 ·'
grep -qx 'api repos/{owner}/{repo}/issues?state=open&per_page=100&page=2' "$GH_LOG" || miss "page 2 was not read"
grep -q 'page=3' "$GH_LOG" && miss "page 3 was read after a short page 2"
done_check

setup
check "open issues over 128 KiB of JSON, the limit of one argument, give the facts and their branches (#179)"
page 1 "$(jq -nc '[range(1000; 1099) | {number: ., body: ("x" * 2000)}] + [{number: 7, body: ("y" * 2000)}]')"
page 2 '[{"number": 6}]'
[ "$(wc -c < "$GH_PAGES/1")" -gt 131072 ] || miss "the fixture's page 1 is not over 128 KiB"
branches 7-login 6-second-page
run
[ "${out%%"$nl"*}" = '## Facts' ] || miss "the first line is not ## Facts"
has '### Branches' '- #6 · `6-second-page`' '- #7 · `7-login`'
lacks 'setup.sh error:'
done_check

setup
check "docs: ADR folders and glossaries the plugin cannot see give warnings, rule docs are listed, and none is changed"
mkdir -p docs/adr doc/decisions architecture/records wiki .github/PULL_REQUEST_TEMPLATE src/decisions notes vendor
printf '# x\n' | tee docs/adr/0001-a.md doc/decisions/0001-a.md doc/decisions/0002-b.md \
  architecture/records/first.md notes/ADR-007-c.md docs/glossary.md CONTEXT.md wiki/Glossary.md \
  CLAUDE.md AGENTS.md .github/CONTRIBUTING.md .github/pull_request_template.md \
  .github/PULL_REQUEST_TEMPLATE/feature.md vendor/glossary.md README.md > /dev/null
printf 'x\n' > src/decisions/engine.ts
printf 'architecture/records/\n' > .adr-dir
printf 'vendor/\n' > .gitignore
git add -A && git commit -qm docs
printf '# x\n' > CONTRIBUTING.md
run
has "### Docs$nl- adr · \`architecture/records/\` · 1 file$nl- adr · \`doc/decisions/\` · 2 files$nl- adr · \`notes/\` · 1 file$nl" \
  "- glossary · \`CONTEXT.md\`$nl- glossary · \`wiki/Glossary.md\`$nl" \
  '- rules · `.github/CONTRIBUTING.md`' \
  '- rules · `.github/PULL_REQUEST_TEMPLATE/feature.md`' \
  '- rules · `.github/pull_request_template.md`' \
  '- rules · `AGENTS.md`' \
  '- rules · `CLAUDE.md`' \
  '- rules · `CONTRIBUTING.md`' \
  '- `doc/decisions/` looks like an ADR folder (2 files), which the plugin cannot see: it reads ADRs only in `docs/adr/`. Setup moves no file.' \
  '- `wiki/Glossary.md` looks like a glossary, which the plugin cannot see: it reads terms only in `docs/glossary.md`. Setup edits no file.'
lacks 'adr · `docs/adr/`' 'glossary · `docs/glossary.md`' 'src/decisions' 'vendor/' 'README.md'
done_check

setup
check "a failing gh call for the open issues prints one setup.sh error line and exits 0"
export GH_FAIL_ISSUES="HTTP 403: Forbidden"
run
error 'gh api repos/{owner}/{repo}/issues?state=open: HTTP 403: Forbidden'
done_check

setup
check "open issues that are not a list print one setup.sh error line and exits 0"
page 1 '{"message": "Not Found"}'
run
error 'did not return a list'
done_check

setup
check "a failing git ls-remote, with no origin, prints one setup.sh error line and exits 0"
git remote remove origin
run
error 'git ls-remote --heads origin:'
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
