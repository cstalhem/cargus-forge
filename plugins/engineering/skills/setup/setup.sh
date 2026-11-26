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
[ -z "$prefix" ] || fail "start the session at the top of the repo: setup reads the repo's files at paths relative to it."

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

  out=$(gh api 'repos/{owner}/{repo}/branches/main' --jq .name 2>&1) || case $out in
    *'HTTP 404'*) fail "the remote has no \`main\` branch, and the plugin's skills take \`main\` as the default branch." ;;
    *) fail "gh api repos/{owner}/{repo}/branches/main: $out" ;;
  esac
  actions=$(gh api 'repos/{owner}/{repo}/actions/permissions' --jq .enabled 2>/dev/null) || actions=unknown
  case $actions in true | false) ;; *) actions=unknown ;; esac

  line '### Repo'
  line "- repo: \`$repo\`"
  line "- allow_squash_merge: \`$squash\`"
  line "- actions_enabled: \`$actions\`"
  line

  if [ "$default_branch" != main ]; then
    findings+=("The default branch is \`$default_branch\`, not \`main\`. Rename the default branch to \`main\`, or expect the plugin's skills to take \`main\`.")
  fi
  case $squash in
    false) findings+=("\`allow_squash_merge\` is off, but the plugin squash-merges every PR. Turn on squash merge under Settings, General, Pull Requests.") ;;
    unknown) findings+=("\`allow_squash_merge\` is unknown, because the token cannot read the repo's merge settings. The plugin squash-merges every PR. Check under Settings, General, Pull Requests that squash merge is on.") ;;
  esac
  case $actions in
    false) findings+=("Actions is off for the repo, so the close-sub-issue workflow will not run. Turn on Actions under Settings, Actions, General.") ;;
    unknown) findings+=("Whether Actions is on is unknown, because the token cannot read the repo's Actions settings. The close-sub-issue workflow runs only when Actions is on. Check under Settings, Actions, General that Actions is on.") ;;
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

stack=''

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

facts_umbrella() {
  local marker='<!-- engineering:setup umbrella -->' out
  read_list 'repos/{owner}/{repo}/issues?state=open'
  out=$(printf '%s' "$items" | jq -r --arg marker "$marker" '
    [.[] | select(has("pull_request") | not)
         | select((.body // "") | split("\n") | (.[0] // "") | rtrimstr("\r") == $marker)]
    | if length == 0 then "- none"
      else .[] | "- #\(.number) · \(.title | gsub("[\r\n]+"; " "))" end' 2>/dev/null) \
    || fail "cannot read the open issues."
  line '### Setup umbrella'
  line "$out"
  line
}

facts_workflows() {
  local file entry path skip n=0
  line '### Workflows'
  shopt -s nullglob
  for file in .github/workflows/*.yml .github/workflows/*.yaml; do
    skip=0
    for entry in "${behaviours[@]}"; do
      IFS='|' read -r _ path _ <<<"$entry"
      [ "$file" = "$path" ] && skip=1
    done
    [ "$skip" = 0 ] || continue
    line "- \`$file\`"
    n=$((n + 1))
  done
  shopt -u nullglob
  [ "$n" -gt 0 ] || line '- none'
  line
}

facts_docs() {
  local adr_dir='' own='' top out
  top=$(pwd -P) || fail "cannot read the current directory."
  case $plugin_root in "$top"/*) own=${plugin_root#"$top"/}/ ;; esac
  if [ -f .adr-dir ]; then
    adr_dir=$(head -n 1 .adr-dir 2>/dev/null | tr -d '\r') || fail "cannot read .adr-dir."
    adr_dir=$(printf '%s' "$adr_dir" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#^\./##' -e 's#/*$##')
  fi
  out=$(printf '%s\n' "$files" | awk -v adrdir="$adr_dir" -v own="$own" '
    function doc(name) { return tolower(name) ~ /\.(md|mdx|markdown|rst|txt|adoc)$/ }
    $0 == "" { next }
    own != "" && index($0, own) == 1 { next }
    {
      path = $0; lp = tolower(path)
      n = split(path, parts, "/")
      base = parts[n]; lbase = tolower(base)
      dir = (n > 1) ? substr(path, 1, length(path) - length(base) - 1) : ""
      ldname = (n > 1) ? tolower(parts[n - 1]) : ""
      if (dir == "docs/adr" && doc(base) && lbase != "readme.md") docadr++
      if (path == "docs/glossary.md") docgloss = 1
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
      if (docadr > 0) print "F - adr · `docs/adr/` · " docadr " file" (docadr == 1 ? "" : "s")
      for (i = 1; i <= k; i++) {
        d = order[i]; c = adr[d] " file" (adr[d] == 1 ? "" : "s")
        print "F - adr · `" d "/` · " c
        print "W `" d "/` looks like an ADR folder (" c "), which the plugin cannot see: it reads ADRs only in `docs/adr/`. Move its ADRs into `docs/adr/`."
      }
      if (docgloss) print "F - glossary · `docs/glossary.md`"
      for (i = 1; i <= g; i++) {
        print "F - glossary · `" glossary[i] "`"
        print "W `" glossary[i] "` looks like a glossary, which the plugin cannot see: it reads terms only in `docs/glossary.md`. Move its terms into `docs/glossary.md`."
      }
      for (i = 1; i <= r; i++) print "F - rules · `" rules[i] "`"
      if (k + g + r + docadr + docgloss == 0) print "F - none"
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
facts_stack
facts_umbrella
facts_workflows
facts_docs

line '## Findings'
if [ "${#findings[@]}" -eq 0 ]; then
  line '- none'
else
  for w in "${findings[@]}"; do line "- $w"; done
fi

printf '%s' "$report"
