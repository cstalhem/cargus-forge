#!/usr/bin/env bash
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
export GIT_CEILING_DIRECTORIES=$tmp

mkdir "$tmp/bin" "$tmp/pages"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [ -n "${GH_FAIL:-}" ]; then printf "%s\n" "$GH_FAIL" >&2; exit 1; fi' \
  'case $2 in' \
  '  "repos/{owner}/{repo}") printf "%s\n" "$GH_JSON" ;;' \
  '  "repos/{owner}/{repo}/branches/main") printf "%s" "$GH_MAIN_OUT"; if [ -n "$GH_MAIN_ERR" ]; then printf "%s\n" "$GH_MAIN_ERR" >&2; exit 1; fi; printf "\n" ;;' \
  '  "repos/{owner}/{repo}/actions/permissions") printf "%s" "$GH_ACTIONS_OUT"; if [ -n "$GH_ACTIONS_ERR" ]; then printf "%s\n" "$GH_ACTIONS_ERR" >&2; exit 1; fi; printf "\n" ;;' \
  '  "--paginate")' \
  '    case "$3 ${!#}" in "--slurp repos/{owner}/{repo}/issues?state=open&per_page=100") ;; *) printf "stub gh: unexpected call: %s\n" "$*" >&2; exit 1 ;; esac' \
  '    [ -e "$GH_READ" ] && { printf "stub gh: the open issues were read twice\n" >&2; exit 1; }; : > "$GH_READ"' \
  '    if [ -n "${GH_FAIL_ISSUES:-}" ]; then printf "%s\n" "$GH_FAIL_ISSUES" >&2; exit 1; fi' \
  '    printf "["; n=1' \
  '    while [ -f "$GH_PAGES/$n" ]; do [ "$n" -gt 1 ] && printf ","; cat "$GH_PAGES/$n"; n=$((n + 1)); done' \
  '    [ "$n" -eq 1 ] && printf "[]"' \
  '    printf "]\n" ;;' \
  '  *) printf "stub gh: unexpected call: %s\n" "$*" >&2; exit 1 ;;' \
  'esac' > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" GH_PAGES=$tmp/pages GH_READ=$tmp/issues.read

gh_repo() {
  GH_JSON=$(jq -nc --arg b "${1:-main}" --arg s "${2:-true}" '
    {full_name: "acme/widget", default_branch: $b}
    + (if $s == "none" then {} else {allow_squash_merge: ($s == "true")} end)')
  export GH_JSON
  export GH_MAIN_OUT=main GH_MAIN_ERR='' GH_ACTIONS_OUT=true GH_ACTIONS_ERR=''
  unset GH_FAIL GH_FAIL_ISSUES
  rm -f "$GH_PAGES"/*
}

page() { printf '%s\n' "$2" > "$GH_PAGES/$1"; }

setup() {
  repo=$(mktemp -d "$tmp/repo.XXXXXX")
  cd "$repo" || exit 1
  git init -q -b main
  echo widget > README.md
  git add -A && git commit -qm base
  gh_repo
}

snapshot() {
  (cd "$repo" && find . | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort)
}

check() { desc=$1; ok=1; why=''; }
miss() { ok=0; why+="  $1"$'\n'; }

run() {
  local dir=${1:-$repo} before after code
  before=$(snapshot)
  rm -f "$GH_READ"
  out=$(cd "$dir" && bash "$script" 2>&1) && code=0 || code=$?
  after=$(snapshot)
  [ "$code" -eq 0 ] || miss "exit $code, want 0"
  [ "$before" = "$after" ] || miss "the run changed a file or a branch in the repo"
}

has() { local t; for t in "$@"; do [[ "$out" == *"$t"* ]] || miss "missing: $t"; done; }
lacks() { local t; for t in "$@"; do [[ "$out" != *"$t"* ]] || miss "unexpected: $t"; done; }

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
check "a new repo: prints the facts, every file missing, no setup umbrella, workflows or docs, and no findings"
run
[ "${out%%"$nl"*}" = '## Facts' ] || miss "the first line is not ## Facts"
has "### Repo$nl- repo: \`acme/widget\`$nl- allow_squash_merge: \`true\`$nl- actions_enabled: \`true\`$nl" \
  "### Files$nl- \`docs/agents/commands.md\` · missing$nl- \`.claude/rules/\` · missing$nl$nl" \
  '- close-sub-issue · `.github/workflows/close-sub-issue.yml` · missing' \
  "### Stack$nl- none$nl$nl### Setup umbrella$nl- none$nl$nl### Workflows$nl- none$nl$nl### Docs$nl- none$nl" \
  "## Findings$nl- none"
done_check

setup
check "the remote has no main branch: one setup.sh error line that says so"
export GH_MAIN_OUT='{"message":"Branch not found","documentation_url":"https://docs.github.com/rest/branches/branches#get-a-branch","status":"404"}'
export GH_MAIN_ERR='gh: Branch not found (HTTP 404)'
run
error 'the remote has no `main` branch'
done_check

setup
check "Actions off gives a finding that the close-sub-issue workflow will not run"
GH_ACTIONS_OUT=false
run
has '- actions_enabled: `false`' \
  '- Actions is off for the repo, so the close-sub-issue workflow will not run.'
done_check

setup
check "Actions that the token cannot read is unknown, with a finding"
export GH_ACTIONS_OUT='{"message":"You must have repository read permissions or have the repository Actions policies fine-grained permission.","documentation_url":"https://docs.github.com/rest/actions/permissions#get-github-actions-permissions-for-a-repository","status":"403"}'
export GH_ACTIONS_ERR='gh: You must have repository read permissions or have the repository Actions policies fine-grained permission. (HTTP 403)'
run
has '- actions_enabled: `unknown`' '- Whether Actions is on is unknown'
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
lacks "## Findings$nl- none" '#85'
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
setup
setup
check "stack: languages are counted by extension, sorted by count then name, and an unknown extension counts for no language (#217 D3)"
mkdir -p lib sub
touch a.py lib/b.py LEGACY.PY c.ts sub/d.tsx main.go lib.rs data.xyz notes.md Makefile .gitignore
run
want=$(printf '%s\n' '- language: Python · 3 files' '- language: TypeScript · 2 files' '- language: Go · 1 files' '- language: Rust · 1 files')
[ "$(printf '%s\n' "$out" | grep '^- language:')" = "$want" ] || miss "the language lines are not $want"
has "### Stack$nl- language: Python"
lacks 'xyz' 'Markdown' "### Stack$nl- none"
done_check

setup
setup
setup
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
check "run from a subdirectory, it prints one setup.sh error line that says to start at the top of the repo"
mkdir -p docs/agents sub/dir
printf '# Commands\n' > docs/agents/commands.md
export GH_FAIL_ISSUES='HTTP 500: issues were read'
run "$repo/sub/dir"
error 'start the session at the top of the repo'
lacks 'issues were read'
done_check

setup
check "the open issues are read with one paginated call, and a PR on a page is not an issue"
page 1 "$(jq -nc '[range(1000; 1099) | {number: .}] + [{number: 5, title: "setup", body: "<!-- engineering:setup umbrella -->", pull_request: {}}]')"
page 2 '[{"number": 6, "title": "Setup", "body": "<!-- engineering:setup umbrella -->\n## Goal"}]'
run
has '- #6 · Setup'
lacks '- #5 ·'
done_check

setup
check "open issues over 128 KiB of JSON, the limit of one argument, give the facts (#179)"
page 1 "$(jq -nc '[range(1000; 1099) | {number: ., body: ("x" * 2000)}] + [{number: 7, title: "Setup", body: ("<!-- engineering:setup umbrella -->\n" + ("y" * 2000))}]')"
[ "$(wc -c < "$GH_PAGES/1")" -gt 131072 ] || miss "the fixture's page 1 is not over 128 KiB"
run
[ "${out%%"$nl"*}" = '## Facts' ] || miss "the first line is not ## Facts"
has '- #7 · Setup'
lacks 'setup.sh error:'
done_check

setup
check "an open issue whose body holds the marker line is the setup umbrella, even when its title says nothing"
page 1 '[{"number":3,"title":"Things to do","body":"<!-- engineering:setup umbrella -->\n## Goal"},{"number":4,"title":"Setup umbrella","body":"x"},{"number":5,"title":"Other","body":"a marker <!-- engineering:setup umbrella --> inside a line"}]'
run
has "### Setup umbrella$nl- #3 · Things to do$nl$nl"
lacks '#4 ·' '#5 ·'
done_check

setup
check "with no marker in any open issue body, the setup umbrella is none, whatever the titles say"
page 1 '[{"number":4,"title":"engineering: setup umbrella","body":"x"},{"number":5,"title":"Setup","body":null}]'
run
has "### Setup umbrella$nl- none$nl"
lacks '#4 ·' '#5 ·'
done_check

check "SKILL.md runs on Fable (#367)"
ok=1; why=''; out=''
awk 'NR > 1 && $0 == "---" { exit } NR > 1' "$here/../SKILL.md" | grep -qx 'model: fable' || miss "the frontmatter lacks the line model: fable"
done_check

check "SKILL.md pre-approves each GitHub write of the setup umbrella: issues, sub-issue links, labels and the feature branch"
ok=1; why=''; out=''
frontmatter=$(awk 'NR > 1 && $0 == "---" { exit } NR > 1' "$here/../SKILL.md")
for want in \
  '  - Bash(gh api -X POST repos/{owner}/{repo}/issues -f title=* -F body=@*)' \
  '  - Bash(gh api -X POST repos/{owner}/{repo}/issues/*/sub_issues -F sub_issue_id=*)' \
  "  - Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:shaped')" \
  "  - Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:umbrella')" \
  '  - Bash(gh issue develop *)'; do
  grep -qxF -- "$want" <<<"$frontmatter" || miss "the frontmatter lacks the line: $want"
done
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
has "### Docs$nl- adr · \`docs/adr/\` · 1 file$nl- adr · \`architecture/records/\` · 1 file$nl- adr · \`doc/decisions/\` · 2 files$nl- adr · \`notes/\` · 1 file$nl" \
  "- glossary · \`docs/glossary.md\`$nl- glossary · \`CONTEXT.md\`$nl- glossary · \`wiki/Glossary.md\`$nl" \
  '- rules · `.github/CONTRIBUTING.md`' \
  '- rules · `.github/PULL_REQUEST_TEMPLATE/feature.md`' \
  '- rules · `.github/pull_request_template.md`' \
  '- rules · `AGENTS.md`' \
  '- rules · `CLAUDE.md`' \
  '- rules · `CONTRIBUTING.md`' \
  '- `doc/decisions/` looks like an ADR folder (2 files), which the plugin cannot see: it reads ADRs only in `docs/adr/`. Move its ADRs into `docs/adr/`.' \
  '- `wiki/Glossary.md` looks like a glossary, which the plugin cannot see: it reads terms only in `docs/glossary.md`. Move its terms into `docs/glossary.md`.'
lacks 'src/decisions' 'vendor/' 'README.md' '`docs/adr/` looks like' '`docs/glossary.md` looks like'
done_check

setup
check "docs: an ADR in docs/adr/ is listed with a count that leaves out its README, and docs/glossary.md is listed"
mkdir -p docs/adr
printf '# x\n' | tee docs/adr/README.md docs/adr/ADR-001-a.md docs/adr/ADR-002-b.md docs/glossary.md > /dev/null
run
has "### Docs$nl- adr · \`docs/adr/\` · 2 files$nl- glossary · \`docs/glossary.md\`$nl$nl" \
  "## Findings$nl- none"
done_check

setup
check "docs: in the repo that holds the plugin, the plugin's own files are not the repo's docs, and a glossary outside the plugin is still found"
mkdir -p plugins/engineering/scripts plugins/engineering/skills/setup/briefs plugins/engineering/decisions docs
cp "$here/../../../scripts/lib.sh" plugins/engineering/scripts/lib.sh
cp -R "$templates" plugins/engineering/templates
cp "$script" plugins/engineering/skills/setup/setup.sh
cp "$here/../briefs/glossary.md" plugins/engineering/skills/setup/briefs/glossary.md
printf '# x\n' | tee plugins/engineering/decisions/0001-a.md docs/terminology.md > /dev/null
git add -A && git commit -qm plugin
real_script=$script
script=$repo/plugins/engineering/skills/setup/setup.sh
run
script=$real_script
has "### Docs$nl- glossary · \`docs/terminology.md\`$nl$nl" \
  "## Findings$nl- \`docs/terminology.md\` looks like a glossary"
lacks 'briefs/glossary.md' 'plugins/engineering/decisions'
done_check

setup
check "docs: a docs/adr/ that holds only a README is not listed"
mkdir -p docs/adr
printf '# x\n' > docs/adr/README.md
run
has "### Docs$nl- none$nl"
done_check

setup
check "workflows: each workflow file other than the plugin's is listed by path, and with none the section says none"
run
has "### Workflows$nl- none$nl"
mkdir -p .github/workflows
cp "$templates/close-sub-issue.yml" .github/workflows/close-sub-issue.yml
printf 'name: ci\n' | tee .github/workflows/ci.yml .github/workflows/release.yaml > /dev/null
run
has "### Workflows$nl- \`.github/workflows/ci.yml\`$nl- \`.github/workflows/release.yaml\`$nl$nl"
lacks '- `.github/workflows/close-sub-issue.yml`'$'\n'
done_check

setup
check "a failing gh call for the open issues prints one setup.sh error line and exits 0"
export GH_FAIL_ISSUES="HTTP 403: Forbidden"
run
error 'gh api repos/{owner}/{repo}/issues?state=open: HTTP 403: Forbidden'
done_check

setup
check "a failing gh call prints one setup.sh error line and exits 0"
export GH_FAIL="HTTP 401: Bad credentials${nl}second line"
run
error 'gh api repos/{owner}/{repo}: HTTP 401: Bad credentials second line'
done_check

setup
check "a failing git call, outside a git repo, prints one setup.sh error line and exits 0"
repo=$(mktemp -d "$tmp/norepo.XXXXXX")
run
error 'git rev-parse --show-prefix:'
done_check

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
