#!/usr/bin/env bash
# setup.sh: the facts for /engineering:setup.
# Reads the repo's settings through `gh api` REST, and the repo's files from the top of the
# git worktree that holds the current directory. It changes nothing: it writes no file, runs
# no git command that writes, and makes no GitHub write.
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
# An error prints exactly one line, `setup.sh error: <reason>`, and nothing else: the output
# is printed only once it is complete.
#
# The plugin's templates are found from this script's own path, `<plugin>/skills/setup/`, so
# the script runs from the user's repo.
#
# Output:
#   ## Facts
#   ### Repo                 `- repo:`, `- default branch:` and `- allow_squash_merge:` lines.
#   ### Files                a line `- <path> · <state>` for each file of the repo profile:
#                            `docs/agents/issue-tracker.md` is missing, current or differs
#                            (#148 D2), and `docs/agents/commands.md` is present or missing.
#   ### Optional behaviours  a line `- <name> · <path> · <state>` for each optional behaviour:
#                            missing, current or differs. A file that differs, here and under
#                            `### Files`, gets a fenced `diff -u` block under its line, from the
#                            repo's file (`-`) to what setup would write (`+`).
#   ### Commands             a line `- <command> · <source>` for each command found in
#                            `package.json`, a Makefile, `pyproject.toml` and the run lines of
#                            `.github/workflows/*`, or `- none` (#85 D7).
#   ## Warnings              a line `- <warning>` for each warning, or `- none`.

set -u

fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf 'setup.sh error: %s\n' "$msg"
  exit 0
}

for tool in gh jq git diff cmp awk; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

plugin_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd -P) \
  || fail "cannot find the plugin's directory from $0."
templates=$plugin_root/templates

# Each optional behaviour (#85 D5): its name, the file that turns it on, and the template that
# file is a byte-identical copy of.
behaviours=(
  "close-sub-issue|.github/workflows/close-sub-issue.yml|close-sub-issue.yml"
)

report=''
warnings=()
line() { report+="$*"$'\n'; }

top=$(git rev-parse --show-toplevel 2>&1) || fail "git rev-parse --show-toplevel: $top"
cd "$top" 2>/dev/null || fail "cannot enter the repo's top directory $top."

facts_repo() {
  local out
  out=$(gh api 'repos/{owner}/{repo}' 2>&1) || fail "gh api repos/{owner}/{repo}: $out"
  repo=$(printf '%s' "$out" | jq -er '.full_name | strings' 2>/dev/null) \
    || fail "gh api repos/{owner}/{repo} did not return a repo: $out"
  default_branch=$(printf '%s' "$out" | jq -er '.default_branch | strings' 2>/dev/null) \
    || fail "gh api repos/{owner}/{repo} did not return a default branch: $out"
  # GitHub leaves the merge settings out for a token that cannot change them.
  squash=$(printf '%s' "$out" | jq -r '.allow_squash_merge | if type == "boolean" then tostring else "unknown" end' 2>/dev/null) \
    || fail "gh api repos/{owner}/{repo} did not return a repo: $out"

  line '### Repo'
  line "- repo: \`$repo\`"
  line "- default branch: \`$default_branch\`"
  line "- allow_squash_merge: \`$squash\`"
  line

  if [ "$default_branch" != main ]; then
    warnings+=("The default branch is \`$default_branch\`, not \`main\`. ship and the final PR still assume \`main\` (#85 D6).")
  fi
  case $squash in
    false) warnings+=("\`allow_squash_merge\` is off, but the plugin squash-merges every PR. Setup changes no repo setting.") ;;
    unknown) warnings+=("\`allow_squash_merge\` is unknown, because the token cannot read the repo's merge settings. The plugin squash-merges every PR.") ;;
  esac
}

# Prints file $1 up to and including its first `## Notes` line, or all of it if it has none.
head_to_notes() { awk '{ print } /^## Notes$/ { exit }' "$1"; }

# Prints $1 escaped for the replacement of a `s#…#…#` sed command: `\`, `&` and `#`.
sed_escape() { printf '%s' "$1" | sed -e 's/[\\&#]/\\&/g'; }

# Sets `rendered` to templates/issue-tracker.md with the repo's facts, byte for byte. It
# renders as apply.sh does, so a file that apply.sh just wrote reads as current.
render_issue_tracker() {
  local r b
  [ -f "$templates/issue-tracker.md" ] || fail "cannot find the template $templates/issue-tracker.md."
  r=$(sed_escape "$repo") && b=$(sed_escape "$default_branch") || fail "cannot escape the repo's facts."
  rendered=$(sed -e "s#{{repo}}#$r#g" -e "s#{{default_branch}}#$b#g" "$templates/issue-tracker.md" 2>/dev/null \
    && printf x) || fail "cannot render the template $templates/issue-tracker.md."
  rendered=${rendered%x}
}

# Adds a fenced `diff -u` block from what is in the repo to what setup would write.
# $1 and $2 are the labels, $3 and $4 the files.
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
  local path=docs/agents/issue-tracker.md head
  line '### Files'
  if [ ! -f "$path" ]; then
    line "- \`$path\` · missing"
  else
    render_issue_tracker
    head=$(head_to_notes "$path" 2>/dev/null && printf x) || fail "cannot read $path."
    head=${head%x}
    if [ "$head" = "$rendered" ]; then
      line "- \`$path\` · current"
    else
      line "- \`$path\` · differs"
      add_diff "$path, up to ## Notes" "templates/issue-tracker.md, rendered" \
        <(printf '%s' "$head") <(printf '%s' "$rendered")
    fi
  fi

  path=docs/agents/commands.md
  if [ -f "$path" ]; then
    line "- \`$path\` · present"
  else
    line "- \`$path\` · missing"
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

# package.json scripts, each run with the package manager its lockfile names.
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

# Makefile targets, with their line. A pattern rule or a target with a variable is left out.
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

# pyproject.toml: the tasks of poe, taskipy, pdm, hatch and rye, and the tools it configures.
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

# The run lines of each workflow, with their line. A `run: |` block gives one command per line,
# and a line that ends with `\` joins the next. An optional behaviour's file is left out,
# because it is the plugin's, not the repo's.
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
        # A comment or a line with only a shell keyword is not a command.
        if (cmd != "" && cmd !~ /^#/ && cmd !~ /^(then|else|fi|do|done|esac|[{}]|;;)$/) print "- " cmd " · " f ":" at
      }
      # Adds a line of a command, which goes out once a line does not end with a backslash.
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

# The report: one section after the other, then the warnings that the sections gave.
line '## Facts'
line
facts_repo
facts_files
facts_behaviours
facts_commands

line '## Warnings'
if [ "${#warnings[@]}" -eq 0 ]; then
  line '- none'
else
  for w in "${warnings[@]}"; do line "- $w"; done
fi

printf '%s' "$report"
