fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf '%s error: %s\n' "$(basename "$0")" "$msg"
  exit 0
}

read_list() {
  local path=$1 sep='?' out
  case $path in *\?*) sep='&' ;; esac
  out=$(gh api --paginate --slurp "$path${sep}per_page=100" 2>&1) || fail "gh api $path: $out"
  items=$(printf '%s' "$out" | jq 'if type == "array" and all(.[]; type == "array") then add // [] else error("not a list") end' 2>/dev/null) \
    || fail "gh api $path did not return a list: $out"
}

read_branches() {
  local remote
  remote=$(git ls-remote --heads origin 2>&1) || fail "git ls-remote --heads origin: $remote"
  branches=$(printf '%s\n' "$remote" | sed -n 's|^[0-9a-f]*[[:space:]]*refs/heads/||p' | jq -R . 2>/dev/null | jq -s . 2>/dev/null) \
    || fail "cannot read the remote branches."
}

JQ_HAS_SECTION='def has_section($name): (.body // "") | test("(^|\n)## \($name)[ \t]*\r?(\n|$)");'

JQ_TRUSTED='def trusted: (.author_association // "") | IN("OWNER", "MEMBER", "COLLABORATOR");'
