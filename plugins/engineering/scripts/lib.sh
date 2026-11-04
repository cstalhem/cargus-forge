# lib.sh: the helpers that status.sh and setup.sh share. They source it; it is never run.
# Each script prints errors as text and exits 0, because a non-zero exit stops the skill.

# Prints `<script> error: <msg>` as one line and ends the script with exit 0.
fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf '%s error: %s\n' "$(basename "$0")" "$msg"
  exit 0
}

# Reads a list page by page, 100 items a page, without following GitHub's next-page link.
# $1 is the path. Sets `items` to one JSON array with every item. Call it in the main shell,
# not in a pipe or `$(…)`, so that its `fail` ends the script and its error text is printed.
# The pages reach `jq` on stdin, not as arguments, because Linux limits one argument to 128 KiB
# (#179 D1).
read_list() {
  local path=$1 sep='?' page=1 out count pages=''
  case $path in *\?*) sep='&' ;; esac
  while :; do
    out=$(gh api "$path${sep}per_page=100&page=$page" 2>&1) || fail "gh api $path: $out"
    count=$(printf '%s' "$out" | jq 'if type == "array" then length else error("not a list") end' 2>/dev/null) \
      || fail "gh api $path did not return a list: $out"
    pages+=$out$'\n'
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done
  items=$(printf '%s' "$pages" | jq -s 'add' 2>/dev/null) || fail "could not join the pages of $path."
}

# Sets `branches` to a JSON array of the names of the remote branches.
read_branches() {
  local remote
  remote=$(git ls-remote --heads origin 2>&1) || fail "git ls-remote --heads origin: $remote"
  branches=$(printf '%s\n' "$remote" | sed -n 's|^[0-9a-f]*[[:space:]]*refs/heads/||p' | jq -R . 2>/dev/null | jq -s . 2>/dev/null) \
    || fail "cannot read the remote branches."
}

# A jq definition, `has_section($name)`, that is true when an issue's `.body` has a `## <name>`
# section: a heading at the start of a line. Put it before the rest of a jq program, as
# `jq "$JQ_HAS_SECTION"'<program>'`. status.sh and setup.sh both tell the plugin's issues by it (#289).
JQ_HAS_SECTION='def has_section($name): (.body // "") | test("(^|\n)## \($name)[ \t]*\r?(\n|$)");'
