#!/usr/bin/env bash
# Tests for setup.sh against fixture repos built under mktemp -d. A stub `gh`, first on PATH,
# returns fixture JSON, and each fixture repo's `origin` is a local bare repo, so the tests
# need no network (#148 D1).
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

# The stub gh: logs each call, then fails with $GH_FAIL if it is set. For the repo it prints
# $GH_JSON. For the open issues, read with `--paginate --slurp`, it fails with $GH_FAIL_ISSUES
# if it is set, or prints the files $GH_PAGES/1, $GH_PAGES/2 and on as an array of pages, or
# `[[]]`. Any other call fails. The pages are files, not variables, because Linux limits one
# variable in the environment to 128 KiB, as it does one argument.
mkdir "$tmp/bin" "$tmp/pages"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >> "$GH_LOG"' \
  'if [ -n "${GH_FAIL:-}" ]; then printf "%s\n" "$GH_FAIL" >&2; exit 1; fi' \
  'case $2 in' \
  '  "repos/{owner}/{repo}") printf "%s\n" "$GH_JSON" ;;' \
  '  "--paginate")' \
  '    case ${!#} in "repos/{owner}/{repo}/issues?state=open&per_page=100") ;; *) printf "stub gh: unexpected call: %s\n" "$*" >&2; exit 1 ;; esac' \
  '    if [ -n "${GH_FAIL_ISSUES:-}" ]; then printf "%s\n" "$GH_FAIL_ISSUES" >&2; exit 1; fi' \
  '    printf "["; n=1' \
  '    while [ -f "$GH_PAGES/$n" ]; do [ "$n" -gt 1 ] && printf ","; cat "$GH_PAGES/$n"; n=$((n + 1)); done' \
  '    [ "$n" -eq 1 ] && printf "[]"' \
  '    printf "]\n" ;;' \
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
    | grep -vx 'api --paginate --slurp repos/{owner}/{repo}/issues?state=open&per_page=100')
  [ -z "$calls" ] || miss "unexpected gh calls: $calls"
  # The screen says once that setup changes none of the findings, so no finding says it. The
  # pattern is a regex, so that this file does not hold the sentences themselves.
  [[ "$out" =~ Setup[[:space:]]+(changes|renames|edits|moves)[[:space:]]+no ]] \
    && miss "a line of the output holds a Setup ... no ... sentence"
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
check "a new repo: prints the facts, every file missing, no commands or docs, and no findings"
run
[ "${out%%"$nl"*}" = '## Facts' ] || miss "the first line is not ## Facts"
has "### Repo$nl- repo: \`acme/widget\`$nl- allow_squash_merge: \`true\`$nl" \
  "### Files$nl- \`docs/agents/commands.md\` · missing$nl- \`.claude/rules/\` · missing$nl$nl" \
  '- close-sub-issue · `.github/workflows/close-sub-issue.yml` · missing' \
  "### Commands$nl- none$nl$nl### Stack$nl- none$nl$nl### Conversion issue" \
  "### Docs$nl- none$nl" \
  "## Findings$nl- none"
lacks 'issue-tracker' '- default branch:' '## Warnings'
grep -qx 'api --paginate --slurp repos/{owner}/{repo}/issues?state=open&per_page=100' "$GH_LOG" \
  || miss "the open issues were not read with gh api --paginate --slurp"
done_check

setup
check "a workflow copy of the template is current, and commands.md is present"
mkdir -p docs/agents
printf '# Commands\n' > docs/agents/commands.md
mkdir -p .github/workflows
cp "$templates/close-sub-issue.yml" .github/workflows/close-sub-issue.yml
git add -A && git commit -qm profile
run
has '- `docs/agents/commands.md` · present' \
  '- close-sub-issue · `.github/workflows/close-sub-issue.yml` · current'
lacks '```diff'
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
check "a default branch other than main gives a finding that ends with the action"
gh_repo develop
run
has 'The default branch is `develop`, not `main`. Rename the default branch to `main`, or expect the plugin'"'"'s skills to take `main`.'
lacks "## Findings$nl- none" '#85' '- default branch:'
done_check

setup
check "allow_squash_merge off gives a finding that ends with the action to turn it on"
gh_repo main false
run
has '- allow_squash_merge: `false`' \
  '- `allow_squash_merge` is off, but the plugin squash-merges every PR. Turn on squash merge under Settings, General, Pull Requests.'
done_check

setup
check "allow_squash_merge that the token cannot read is unknown, with a finding"
gh_repo main none
run
has '- allow_squash_merge: `unknown`' '- `allow_squash_merge` is unknown' \
  'Check under Settings, General, Pull Requests that squash merge is on.'
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
has '### Commands' '- package.json is not valid JSON, so its scripts were not read' \
  '- package.json: not valid JSON, so its dependencies were not read'
done_check

setup
check "stack: languages are counted by extension, sorted by count then name, and an unknown extension counts for no language (#217 D3)"
mkdir -p lib sub
touch a.py lib/b.py LEGACY.PY c.ts sub/d.tsx main.go lib.rs data.xyz notes.md Makefile .gitignore
run
want=$(printf '%s\n' '- language: Python · 3 files' '- language: TypeScript · 2 files' '- language: Go · 1 files' '- language: Rust · 1 files')
[ "$(printf '%s\n' "$out" | grep '^- language:')" = "$want" ] || miss "the language lines are not $want"
has "### Commands$nl- none$nl$nl### Stack$nl- language: Python"
lacks 'xyz' 'Markdown' "### Stack$nl- none" '- Makefile' '- config:'
done_check

setup
check "stack: each manifest kind gives a line with its sorted dependency names and no versions (#217 D2)"
printf '%s\n' '{ "name": "w", "dependencies": { "react": "^18", "express": "4" }, "devDependencies": { "vitest": "1", "typescript": "5" } }' > package.json
printf '%s\n' \
  '[project]' \
  'name = "widget"' \
  'dependencies = [' \
  '  "requests>=2",' \
  "  \"fastapi[all]>=0.1; python_version > '3.8'\"," \
  ']' \
  '' \
  '[project.optional-dependencies]' \
  'dev = ["pytest>=7", "requests"]' \
  '' \
  '[dependency-groups]' \
  'lint = ["flake8-bugbear", {include-group = "dev"}]' \
  '' \
  '[tool.poetry.dependencies]' \
  'python = "^3.11"' \
  'django = { version = "^4" }' > pyproject.toml
printf '%s\n' \
  'module example.com/widget' \
  '' \
  'go 1.22' \
  '' \
  'require (' \
  '	github.com/gin-gonic/gin v1.9.0' \
  '	golang.org/x/text v0.3.0 // indirect' \
  ')' \
  '' \
  'require github.com/stretchr/testify v1.8.0' > go.mod
printf '%s\n' \
  '[package]' \
  'name = "widget"' \
  'version = "0.1.0"' \
  '' \
  '[dependencies]' \
  'serde = "1"' \
  'tokio = { version = "1", features = ["full"] }' \
  'anyhow.workspace = true' \
  '' \
  '[dev-dependencies]' \
  'criterion = "0.5"' \
  '' \
  '[dependencies.clap]' \
  'version = "4"' > Cargo.toml
printf '%s\n' \
  "source 'https://rubygems.org'" \
  "gem 'rails', '~> 7.0'" \
  '  gem "rspec"' \
  "# gem 'commented'" > Gemfile
run
has "### Stack$nl- package.json: express, react, typescript, vitest$nl" \
  '- pyproject.toml: django, fastapi, flake8-bugbear, pytest, requests'"$nl" \
  '- go.mod: github.com/gin-gonic/gin, github.com/stretchr/testify'"$nl" \
  '- Cargo.toml: anyhow, clap, criterion, serde, tokio'"$nl" \
  "- Gemfile: rails, rspec$nl"
lacks '^18' 'x/text' 'commented' 'dev,' 'include-group' '- language:' "### Stack$nl- none"
done_check

setup
check "stack: a manifest with no dependencies gives its line with none"
printf '%s\n' '{ "name": "w" }' > package.json
run
has "### Stack$nl- package.json: none$nl$nl"
done_check

setup
check "stack: each linter and formatter config present gives a config line (#217 D3)"
mkdir -p docs
touch .eslintrc.json prettier.config.js biome.json ruff.toml .flake8 mypy.ini .golangci.yml rustfmt.toml .rubocop.yml .editorconfig
printf '%s\n' '[tool.black]' 'line-length = 88' '' '[tool.ruff.lint]' 'select = ["E"]' '' '[tool.ruff.format]' > pyproject.toml
run
has '- config: .eslintrc.json' '- config: prettier.config.js' '- config: biome.json' '- config: ruff.toml' \
  '- config: .flake8' '- config: mypy.ini' '- config: .golangci.yml' '- config: rustfmt.toml' \
  '- config: .rubocop.yml' '- config: .editorconfig' '- config: pyproject.toml [tool.black]' \
  '- config: pyproject.toml [tool.ruff]'
lacks '[tool.mypy]' '- config: .prettierrc' "### Stack$nl- none"
[ "$(printf '%s\n' "$out" | grep -c 'tool.ruff')" = 1 ] || miss "[tool.ruff] is not one line"
done_check

setup
check ".claude/rules/ holding a .md file, in a subfolder too, is present with the count of .md files (#217 D1)"
mkdir -p .claude/rules/deep
printf 'x\n' > .claude/rules/a.md
printf 'x\n' > .claude/rules/deep/b.md
printf 'x\n' > .claude/rules/notes.txt
run
has '- `docs/agents/commands.md` · missing'"$nl"'- `.claude/rules/` · present (2 files)'"$nl$nl"
lacks '`.claude/rules/` · missing'
done_check

setup
check ".claude/rules/ that is absent or holds no .md file is missing, an empty folder too (#217 D1)"
run
has '- `.claude/rules/` · missing'
mkdir -p .claude/rules/empty
touch .claude/rules/.gitkeep .claude/rules/notes.txt
run
has '- `.claude/rules/` · missing'
lacks '· present ('
done_check

setup
check "run from a subdirectory, it reads the files at the top of the repo"
mkdir -p docs/agents sub/dir
printf '# Commands\n' > docs/agents/commands.md
run "$repo/sub/dir"
has '- `docs/agents/commands.md` · present'
done_check

setup
check "a repo with <n>-* branches and branches with other names: the facts have no ### Branches part and the findings name no branch (#379)"
branches 7-login 70-other 12-closed feature/a feature/b fix/c dependabot/npm/x
issues 7 12
run
lacks '### Branches' '- branches:' '- convention:' '- #7 ·' '`7-login`' 'feature/' 'dependabot/' '-*`'
has "### Stack$nl- none$nl$nl### Conversion issue$nl- none$nl$nl### Docs" "## Findings$nl- none"
grep -q 'ls-remote' "$script" && miss "setup.sh still reads the remote branches"
done_check

setup
check "the open issues are read with one paginated call, and a PR on a page is not an issue"
page 1 "$(jq -nc '[range(1000; 1099) | {number: .}] + [{number: 5, title: "convert plugin", pull_request: {}}]')"
page 2 '[{"number": 6, "title": "convert plugin"}]'
run
has '- #6 · convert plugin · by title'
lacks '- #5 ·'
[ "$(grep -c 'issues?state=open' "$GH_LOG")" -eq 1 ] || miss "the open issues were not read with one call"
done_check

setup
check "open issues over 128 KiB of JSON, the limit of one argument, give the facts (#179)"
page 1 "$(jq -nc '[range(1000; 1099) | {number: ., body: ("x" * 2000)}] + [{number: 7, title: "convert plugin", body: ("y" * 2000)}]')"
[ "$(wc -c < "$GH_PAGES/1")" -gt 131072 ] || miss "the fixture's page 1 is not over 128 KiB"
run
[ "${out%%"$nl"*}" = '## Facts' ] || miss "the first line is not ## Facts"
has '- #7 · convert plugin · by title'
lacks 'setup.sh error:'
done_check

setup
check "an open issue whose body holds the marker line is the conversion issue, even when its title says nothing (#164)"
page 1 '[{"number":3,"title":"Setup items","body":"<!-- engineering:setup conversion issue -->\n/engineering:setup found"},{"number":4,"title":"convert plugin","body":"x"},{"number":5,"title":"Other","body":"a marker <!-- engineering:setup conversion issue --> inside a line"}]'
run
has "### Conversion issue$nl- #3 · Setup items · by marker$nl"
lacks '#4 ·' '#5 ·' 'by title'
done_check

setup
check "with no marker, a title with convert and plugin or engineering names the conversion issue (#164)"
page 1 '[{"number":4,"title":"Engineering: Convert this repo","body":"x"},{"number":5,"title":"convert the build","body":"x"},{"number":6,"title":"Plugin notes","body":null}]'
run
has "### Conversion issue$nl- #4 · Engineering: Convert this repo · by title$nl"
lacks '#5 ·' '#6 ·'
done_check

setup
check "more than one match names each one (#164)"
page 1 '[{"number":4,"title":"convert to plugin"},{"number":5,"title":"convert to engineering"}]'
run
has '- #4 · convert to plugin · by title' '- #5 · convert to engineering · by title'
done_check

setup
check "with no open issue that matches, the conversion issue is none, and a PR does not count (#164)"
page 1 '[{"number":4,"title":"convert plugin","pull_request":{}},{"number":5,"title":"Fix a bug"}]'
run
has "### Conversion issue$nl- none$nl"
done_check

check "SKILL.md writes the marker as the first line of the issue it creates (#164)"
ok=1; why=''; out=''
grep -qF 'Its first line is `<!-- engineering:setup conversion issue -->`' "$here/../SKILL.md" || miss "SKILL.md does not put the marker first"
done_check

setup
check "docs: ADR folders and glossaries the plugin cannot see give findings with the action to move them, rule docs are listed, and none is changed"
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
  '- `doc/decisions/` looks like an ADR folder (2 files), which the plugin cannot see: it reads ADRs only in `docs/adr/`. Move its ADRs into `docs/adr/`.' \
  '- `wiki/Glossary.md` looks like a glossary, which the plugin cannot see: it reads terms only in `docs/glossary.md`. Move its terms into `docs/glossary.md`.'
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
