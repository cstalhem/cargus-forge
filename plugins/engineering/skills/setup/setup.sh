#!/usr/bin/env bash
set -u

lib=$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh
if [ ! -f "$lib" ]; then
  printf '%s error: cannot find %s\n' "$(basename "$0")" "$lib"
  exit 0
fi
. "$lib"

for tool in gh jq git diff cmp awk; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

plugin_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd -P) \
  || fail "cannot find the plugin's directory from $0."
templates=$plugin_root/templates

behaviours=(
  "close-sub-issue|.github/workflows/close-sub-issue.yml|close-sub-issue.yml"
)

report=''
findings=()
line() { report+="$*"$'\n'; }

prefix=$(git rev-parse --show-prefix 2>&1) || fail "git rev-parse --show-prefix: $prefix"
[ -z "$prefix" ] || fail "start the session at the top of the repo: setup copies files to paths relative to it."

files=$(git -c core.quotePath=false ls-files --cached --others --exclude-standard 2>&1) \
  || fail "git ls-files: $files"

facts_repo() {
  local out
  out=$(gh api 'repos/{owner}/{repo}' 2>&1) || fail "gh api repos/{owner}/{repo}: $out"
  repo=$(printf '%s' "$out" | jq -er '.full_name | strings' 2>/dev/null) \
    || fail "gh api repos/{owner}/{repo} did not return a repo: $out"
  default_branch=$(printf '%s' "$out" | jq -er '.default_branch | strings' 2>/dev/null) \
    || fail "gh api repos/{owner}/{repo} did not return a default branch: $out"
  squash=$(printf '%s' "$out" | jq -r '.allow_squash_merge | if type == "boolean" then tostring else "unknown" end' 2>/dev/null) \
    || fail "gh api repos/{owner}/{repo} did not return a repo: $out"

  line '### Repo'
  line "- repo: \`$repo\`"
  line "- allow_squash_merge: \`$squash\`"
  line

  if [ "$default_branch" != main ]; then
    findings+=("The default branch is \`$default_branch\`, not \`main\`. Rename the default branch to \`main\`, or expect the plugin's skills to take \`main\`.")
  fi
  case $squash in
    false) findings+=("\`allow_squash_merge\` is off, but the plugin squash-merges every PR. Turn on squash merge under Settings, General, Pull Requests.") ;;
    unknown) findings+=("\`allow_squash_merge\` is unknown, because the token cannot read the repo's merge settings. The plugin squash-merges every PR. Check under Settings, General, Pull Requests that squash merge is on.") ;;
  esac
}

add_diff() {
  local d rc
  d=$(diff -u -L "$1" -L "$2" "$3" "$4" 2>&1)
  rc=$?
  [ "$rc" -le 1 ] || fail "diff $1 $2: $d"
  line '```diff'
  line "$d"
  line '```'
}

facts_files() {
  local path=docs/agents/commands.md rules=.claude/rules n=0
  line '### Files'
  if [ -f "$path" ]; then
    line "- \`$path\` · present"
  else
    line "- \`$path\` · missing"
  fi
  [ ! -d "$rules" ] || n=$(find "$rules" -type f -name '*.md' | wc -l | tr -d ' ')
  if [ "$n" -gt 0 ]; then
    line "- \`$rules/\` · present ($n files)"
  else
    line "- \`$rules/\` · missing"
  fi
  line
}

facts_behaviours() {
  local entry name path template rc
  line '### Optional behaviours'
  for entry in "${behaviours[@]}"; do
    IFS='|' read -r name path template <<<"$entry"
    [ -f "$templates/$template" ] || fail "cannot find the template $templates/$template."
    if [ ! -f "$path" ]; then
      line "- $name · \`$path\` · missing"
      continue
    fi
    cmp -s "$path" "$templates/$template"
    rc=$?
    case $rc in
      0) line "- $name · \`$path\` · current" ;;
      1)
        line "- $name · \`$path\` · differs"
        add_diff "$path" "templates/$template" "$path" "$templates/$template"
        ;;
      *) fail "cannot compare $path with $templates/$template." ;;
    esac
  done
  line
}

commands=''

commands_package_json() {
  local runner=npm out
  [ -f package.json ] || return
  if [ -f pnpm-lock.yaml ]; then runner=pnpm
  elif [ -f yarn.lock ]; then runner=yarn
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then runner=bun
  fi
  if out=$(jq -r --arg runner "$runner" '
      (.scripts // {}) | to_entries[]
      | "- \($runner) run \(.key) · package.json: \(.value | tostring | gsub("[\r\n]+"; " "))"' \
      package.json 2>/dev/null); then
    [ -z "$out" ] || commands+="$out"$'\n'
  else
    commands+="- package.json is not valid JSON, so its scripts were not read"$'\n'
  fi
}

commands_makefile() {
  local file out
  for file in GNUmakefile makefile Makefile; do
    [ -f "$file" ] || continue
    out=$(awk -v f="$file" '
      /^[A-Za-z0-9_][^:=#]*:([^=]|$)/ {
        t = $0; sub(/:.*/, "", t)
        n = split(t, names, /[ \t]+/)
        for (i = 1; i <= n; i++)
          if (names[i] != "" && names[i] !~ /[%$]/) print "- make " names[i] " · " f ":" NR
      }' "$file" 2>/dev/null) || fail "cannot read $file."
    [ -z "$out" ] || commands+="$out"$'\n'
    break
  done
}

commands_pyproject() {
  local out
  [ -f pyproject.toml ] || return
  out=$(awk '
    function emit(cmd) { print "- " cmd " · pyproject.toml [" table "]" }
    /^[ \t]*\[/ {
      table = $0
      gsub(/^[ \t]*\[+[ \t]*|[ \t]*\]+.*$/, "", table)
      runner = ""
      if (table == "tool.poe.tasks") runner = "poe "
      else if (table == "tool.taskipy.tasks") runner = "task "
      else if (table == "tool.pdm.scripts") runner = "pdm run "
      else if (table == "tool.rye.scripts") runner = "rye run "
      else if (table ~ /^tool\.hatch\.envs\.[^.]+\.scripts$/) {
        env = table; sub(/^tool\.hatch\.envs\./, "", env); sub(/\.scripts$/, "", env)
        runner = (env == "default") ? "hatch run " : "hatch run " env ":"
      }
      else if (table ~ /^tool\.poe\.tasks\.[^.]+$/) { name = table; sub(/^tool\.poe\.tasks\./, "", name); emit("poe " name) }
      else if (table == "tool.pytest.ini_options") emit("pytest")
      else if (table == "tool.ruff") emit("ruff check")
      else if (table == "tool.mypy") emit("mypy")
      next
    }
    runner != "" && /^[ \t]*("[^"]+"|[A-Za-z0-9_.-]+)[ \t]*=/ {
      key = $0
      sub(/^[ \t]*/, "", key); sub(/[ \t]*=.*$/, "", key); gsub(/"/, "", key)
      if (key !~ /^_/) emit(runner key)
    }' pyproject.toml 2>/dev/null) || fail "cannot read pyproject.toml."
  [ -z "$out" ] || commands+="$out"$'\n'
}

commands_workflows() {
  local file entry path skip out
  shopt -s nullglob
  for file in .github/workflows/*.yml .github/workflows/*.yaml; do
    skip=0
    for entry in "${behaviours[@]}"; do
      IFS='|' read -r _ path _ <<<"$entry"
      [ "$file" = "$path" ] && skip=1
    done
    [ "$skip" = 0 ] || continue
    out=$(awk -v f="$file" -v q="'" '
      function indent(s) { match(s, /^ */); return RLENGTH }
      function emit(cmd, at) {
        gsub(/^[ \t]+|[ \t]+$/, "", cmd)
        if (cmd != "" && cmd !~ /^#/ && cmd !~ /^(then|else|fi|do|done|esac|[{}]|;;)$/) print "- " cmd " · " f ":" at
      }
      function part(s, at) {
        if (pending == "") pending_at = at
        sub(/^[ \t]+/, "", s)
        if (s ~ /\\[ \t]*$/) { sub(/[ \t]*\\[ \t]*$/, "", s); pending = pending s " "; return }
        emit(pending s, pending_at); pending = ""
      }
      { sub(/\r$/, "") }
      block {
        if ($0 ~ /^[ \t]*$/) next
        if (indent($0) > base) { part($0, NR); next }
        if (pending != "") { emit(pending, pending_at); pending = "" }
        block = 0
      }
      match($0, /^ *(- +)?run:/) {
        base = RLENGTH - 4
        value = substr($0, RLENGTH + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        if (value ~ /^[|>][-+0-9]*([ \t]+#.*)?$/) { block = 1; next }
        if (length(value) > 1 && (value ~ /^".*"$/ || (substr(value, 1, 1) == q && substr(value, length(value)) == q)))
          value = substr(value, 2, length(value) - 2)
        emit(value, NR)
      }
      END { if (pending != "") emit(pending, pending_at) }' "$file" 2>/dev/null) || fail "cannot read $file."
    [ -z "$out" ] || commands+="$out"$'\n'
  done
  shopt -u nullglob
}

facts_commands() {
  commands_package_json
  commands_makefile
  commands_pyproject
  commands_workflows
  line '### Commands'
  if [ -z "$commands" ]; then
    line '- none'
  else
    report+=$commands
  fi
  line
}

stack=''

stack_manifest() {
  local joined
  joined=$(printf '%s\n' "$2" | LC_ALL=C sort -u | awk 'NF { printf "%s%s", (n++ ? ", " : ""), $0 }')
  stack+="- $1: ${joined:-none}"$'\n'
}

stack_package_json() {
  local names
  [ -f package.json ] || return
  if names=$(jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' package.json 2>/dev/null); then
    stack_manifest package.json "$names"
  else
    stack+="- package.json: not valid JSON, so its dependencies were not read"$'\n'
  fi
}

stack_pyproject() {
  local names
  [ -f pyproject.toml ] || return
  names=$(awk '
    function reqs(s,   b) {
      gsub(/\{[^}]*\}/, "", s)
      while (match(s, /"[^"]*"|\047[^\047]*\047/)) {
        b = substr(s, RSTART + 1, RLENGTH - 2)
        s = substr(s, RSTART + RLENGTH)
        sub(/^[ \t]+/, "", b)
        if (match(b, /^[A-Za-z0-9][A-Za-z0-9._-]*/)) print substr(b, 1, RLENGTH)
      }
      sub(/#.*/, "", s)
      if (s ~ /\]/) arr = 0
    }
    /^[ \t]*\[/ {
      table = $0
      gsub(/^[ \t]*\[+[ \t]*|[ \t]*\]+.*$/, "", table)
      arr = 0; mode = ""
      if (table ~ /^tool\.poetry\.(dev-dependencies|dependencies|group\.[^.]+\.dependencies)$/) mode = "keys"
      else if (table == "project.optional-dependencies" || table == "dependency-groups") mode = "any"
      else if (table == "project") mode = "dependencies"
      next
    }
    mode == "keys" && /^[ \t]*[A-Za-z0-9_.-]+[ \t]*=/ {
      key = $0; sub(/^[ \t]*/, "", key); sub(/[ \t]*=.*$/, "", key)
      if (key != "python") print key
      next
    }
    arr { reqs($0); next }
    (mode == "any" || mode == "dependencies") && /^[ \t]*[A-Za-z0-9_.-]+[ \t]*=[ \t]*\[/ {
      key = $0; sub(/^[ \t]*/, "", key); sub(/[ \t]*=.*$/, "", key)
      if (mode == "any" || key == "dependencies") { arr = 1; rest = $0; sub(/^[^[]*\[/, "", rest); reqs(rest) }
    }' pyproject.toml 2>/dev/null) || fail "cannot read pyproject.toml."
  stack_manifest pyproject.toml "$names"
}

stack_go_mod() {
  local names
  [ -f go.mod ] || return
  names=$(awk '
    /^[ \t]*\/\// { next }
    /^require[ \t]*\(/ { inreq = 1; next }
    inreq && /^[ \t]*\)/ { inreq = 0; next }
    inreq && NF && !/\/\/[ \t]*indirect/ { print $1; next }
    /^require[ \t]+[^( \t]/ && !/\/\/[ \t]*indirect/ { print $2 }' go.mod 2>/dev/null) || fail "cannot read go.mod."
  stack_manifest go.mod "$names"
}

stack_cargo() {
  local names
  [ -f Cargo.toml ] || return
  names=$(awk '
    /^[ \t]*\[/ {
      table = $0
      gsub(/^[ \t]*\[+[ \t]*|[ \t]*\]+.*$/, "", table)
      keys = (table ~ /(^|\.)(dev-|build-)?dependencies$/)
      if (match(table, /(^|\.)(dev-|build-)?dependencies\./)) print substr(table, RSTART + RLENGTH)
      next
    }
    keys && match($0, /^[ \t]*[A-Za-z0-9_-]+[ \t]*[.=]/) {
      key = substr($0, RSTART, RLENGTH); gsub(/^[ \t]+|[ \t]*[.=]$/, "", key)
      print key
    }' Cargo.toml 2>/dev/null) || fail "cannot read Cargo.toml."
  stack_manifest Cargo.toml "$names"
}

stack_gemfile() {
  local names
  [ -f Gemfile ] || return
  names=$(sed -nE "s/^[[:space:]]*gem[[:space:]]+[\"']([^\"']+).*/\1/p" Gemfile 2>/dev/null) || fail "cannot read Gemfile."
  stack_manifest Gemfile "$names"
}

stack_configs() {
  local f tools
  for f in \
    .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.mjs .eslintrc.json .eslintrc.yml .eslintrc.yaml \
    eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts \
    .prettierrc .prettierrc.json .prettierrc.json5 .prettierrc.yml .prettierrc.yaml .prettierrc.toml \
    .prettierrc.js .prettierrc.cjs .prettierrc.mjs \
    prettier.config.js prettier.config.cjs prettier.config.mjs prettier.config.ts \
    biome.json biome.jsonc ruff.toml .ruff.toml .flake8 mypy.ini .mypy.ini \
    .golangci.yml .golangci.yaml .golangci.toml .golangci.json rustfmt.toml .rustfmt.toml \
    .rubocop.yml .editorconfig; do
    if [ -f "$f" ]; then stack+="- config: $f"$'\n'; fi
  done
  [ -f pyproject.toml ] || return
  tools=$(awk '
    /^[ \t]*\[/ {
      table = $0
      gsub(/^[ \t]*\[+[ \t]*|[ \t]*\]+.*$/, "", table)
      if (match(table, /^tool\.(black|ruff|mypy)(\.|$)/)) {
        table = substr(table, 1, RLENGTH); sub(/\.$/, "", table)
        if (!(table in seen)) { seen[table] = 1; print "- config: pyproject.toml [" table "]" }
      }
    }' pyproject.toml 2>/dev/null) || fail "cannot read pyproject.toml."
  [ -z "$tools" ] || stack+="$tools"$'\n'
}

facts_stack() {
  local languages
  languages=$(printf '%s\n' "$files" | awk '
    BEGIN {
      n = split("py:Python js:JavaScript mjs:JavaScript cjs:JavaScript jsx:JavaScript ts:TypeScript mts:TypeScript cts:TypeScript tsx:TypeScript go:Go rs:Rust rb:Ruby java:Java kt:Kotlin cs:C# php:PHP swift:Swift c:C h:C cc:C++ cpp:C++ hpp:C++ sh:Shell bash:Shell", pairs, " ")
      for (i = 1; i <= n; i++) { split(pairs[i], kv, ":"); lang[kv[1]] = kv[2] }
    }
    {
      base = $0; sub(/.*\//, "", base)
      if (match(base, /\.[^.]+$/) && RSTART > 1) {
        ext = tolower(substr(base, RSTART + 1))
        if (ext in lang) count[lang[ext]]++
      }
    }
    END { for (l in count) print count[l] "\t" l }' 2>/dev/null \
    | LC_ALL=C sort -t "$(printf '\t')" -k1,1nr -k2,2 \
    | awk -F '\t' '{ print "- language: " $2 " · " $1 " files" }') \
    || fail "cannot read the list of the repo's files."
  stack=''
  [ -z "$languages" ] || stack+="$languages"$'\n'
  stack_package_json
  stack_pyproject
  stack_go_mod
  stack_cargo
  stack_gemfile
  stack_configs
  line '### Stack'
  if [ -z "$stack" ]; then
    line '- none'
  else
    report+=$stack
  fi
  line
}

add_lines() {
  local l
  while IFS= read -r l; do
    case $l in
      'F '*) line "${l#F }" ;;
      'W '*) findings+=("${l#W }") ;;
    esac
  done <<<"$1"
}

facts_conversion() {
  local marker='<!-- engineering:setup conversion issue -->' out
  read_list 'repos/{owner}/{repo}/issues?state=open'
  out=$(printf '%s' "$items" | jq -r --arg marker "$marker" '
    [.[] | select(has("pull_request") | not)] as $open
    | [$open[] | select((.body // "") | split("\n") | any(rtrimstr("\r") == $marker))] as $marked
    | (if ($marked | length) > 0 then [$marked[] | {n: .number, t: .title, by: "marker"}]
       else [$open[] | select((.title // "") | ascii_downcase | contains("convert") and (contains("plugin") or contains("engineering")))
             | {n: .number, t: .title, by: "title"}] end) as $found
    | if ($found | length) == 0 then "- none"
      else $found[] | "- #\(.n) · \(.t | gsub("[\r\n]+"; " ")) · by \(.by)" end' 2>/dev/null) \
    || fail "cannot read the open issues."
  line '### Conversion issue'
  line "$out"
  line
}

facts_docs() {
  local adr_dir='' out
  if [ -f .adr-dir ]; then
    adr_dir=$(head -n 1 .adr-dir 2>/dev/null | tr -d '\r') || fail "cannot read .adr-dir."
    adr_dir=$(printf '%s' "$adr_dir" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#^\./##' -e 's#/*$##')
  fi
  out=$(printf '%s\n' "$files" | awk -v adrdir="$adr_dir" '
    function doc(name) { return tolower(name) ~ /\.(md|mdx|markdown|rst|txt|adoc)$/ }
    $0 == "" { next }
    {
      path = $0; lp = tolower(path)
      n = split(path, parts, "/")
      base = parts[n]; lbase = tolower(base)
      dir = (n > 1) ? substr(path, 1, length(path) - length(base) - 1) : ""
      ldname = (n > 1) ? tolower(parts[n - 1]) : ""
      if (dir != "" && dir != "docs/adr" && index(dir, "docs/adr/") != 1 && doc(base) \
          && (dir == adrdir || lbase ~ /^adr[-_]?[0-9]/ \
              || ldname ~ /^(adrs?|decisions|decision-records|architecture-decisions|architecture-decision-records)$/)) {
        if (!(dir in adr)) order[++k] = dir
        adr[dir]++
      }
      stem = lbase; sub(/\.[^.]*$/, "", stem)
      if (path != "docs/glossary.md" && doc(base) \
          && stem ~ /^(glossary|glossaries|terminology|ubiquitous[-_]language|domain[-_]language|context)$/)
        glossary[++g] = path
      if (lp ~ /^(\.claude\/)?claude\.md$/ || lp == "agents.md" || lp ~ /^(\.github\/|docs\/)?contributing\.md$/ \
          || lp ~ /^(\.github\/|docs\/)?pull_request_template(\.md|\/[^\/]+\.md)$/)
        rules[++r] = path
    }
    END {
      for (i = 1; i <= k; i++) {
        d = order[i]; c = adr[d] " file" (adr[d] == 1 ? "" : "s")
        print "F - adr · `" d "/` · " c
        print "W `" d "/` looks like an ADR folder (" c "), which the plugin cannot see: it reads ADRs only in `docs/adr/`. Move its ADRs into `docs/adr/`."
      }
      for (i = 1; i <= g; i++) {
        print "F - glossary · `" glossary[i] "`"
        print "W `" glossary[i] "` looks like a glossary, which the plugin cannot see: it reads terms only in `docs/glossary.md`. Move its terms into `docs/glossary.md`."
      }
      for (i = 1; i <= r; i++) print "F - rules · `" rules[i] "`"
      if (k + g + r == 0) print "F - none"
    }' 2>/dev/null) || fail "cannot read the list of the repo's files."
  line '### Docs'
  add_lines "$out"
  line
}

line '## Facts'
line
facts_repo
facts_files
facts_behaviours
facts_commands
facts_stack
facts_conversion
facts_docs

line '## Findings'
if [ "${#findings[@]}" -eq 0 ]; then
  line '- none'
else
  for w in "${findings[@]}"; do line "- $w"; done
fi

printf '%s' "$report"
