#!/usr/bin/env bash
# apply.sh: writes the files that the user accepted in /engineering:setup.
# Run it from the root of the user's repo. It finds the plugin's templates relative to its
# own location, writes only the paths that its arguments name, and prints each path it wrote,
# one per line. It never writes `docs/agents/commands.md`, which the model writes, and it runs
# no `git` or `gh` command (#149 D1).
#
# Usage:
#   apply.sh [--issue-tracker --repo <owner/name> --default-branch <branch>]
#            [--behaviour <name>]...
#
#   --issue-tracker     render `docs/agents/issue-tracker.md` from `templates/issue-tracker.md`
#                       with the repo and the default branch, and keep the existing file's
#                       `## Notes` byte-identical (#85 D4, D8).
#   --behaviour <name>  copy an optional behaviour's file from the template with `cp`, so the
#                       copy is byte-identical (#85 D8). Known: close-sub-issue.
#
# An error prints one line, `apply.sh error: <reason>`, to stderr and exits 1. The arguments,
# the templates and the existing issue tracker are checked before the first write, so an
# error in them writes nothing.

set -u

fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf 'apply.sh error: %s\n' "$msg" >&2
  exit 1
}

here=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || fail "cannot find the directory of apply.sh."
templates="$here/../../templates"

marker_prefix='<!-- Written by /engineering:setup.'
tracker=docs/agents/issue-tracker.md

# The file in the repo, and the template it copies, of each optional behaviour.
behaviour_target() {
  case $1 in
    close-sub-issue) printf '%s' .github/workflows/close-sub-issue.yml ;;
    *) return 1 ;;
  esac
}
behaviour_template() {
  case $1 in
    close-sub-issue) printf '%s' "$templates/close-sub-issue.yml" ;;
    *) return 1 ;;
  esac
}

repo='' default_branch='' issue_tracker=0 behaviours=()

# value <option> <arg count> <value>: fail unless the option has a value.
value() {
  [ "$2" -ge 2 ] || fail "$1 needs a value."
  case $3 in --*|'') fail "$1 needs a value." ;; esac
}

while [ $# -gt 0 ]; do
  case $1 in
    --repo) value "$1" $# "${2-}"; repo=$2; shift 2 ;;
    --default-branch) value "$1" $# "${2-}"; default_branch=$2; shift 2 ;;
    --issue-tracker) issue_tracker=1; shift ;;
    --behaviour)
      value "$1" $# "${2-}"
      behaviour_target "$2" >/dev/null || fail "unknown behaviour: $2. Known: close-sub-issue."
      case " ${behaviours[*]-} " in *" $2 "*) ;; *) behaviours+=("$2") ;; esac
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[ "$issue_tracker" = 1 ] || [ "${#behaviours[@]}" -gt 0 ] \
  || fail "nothing to write: pass --issue-tracker, --behaviour <name>, or both."

work=$(mktemp -d 2>/dev/null) || fail "cannot create a temporary directory."
trap 'rm -rf "$work"' EXIT

for b in "${behaviours[@]+"${behaviours[@]}"}"; do
  [ -f "$(behaviour_template "$b")" ] || fail "the template of $b is missing: $(behaviour_template "$b")"
done

# Escapes a value for the replacement side of a sed `s#…#…#` command: `\`, `&` and `#`.
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\&#]/\\&/g'
}

# notes <file> <out>: writes the text after the existing file's `## Notes` line to <out>,
# byte for byte, trailing newlines or their absence included. Fails if the file has no
# marker line or no `## Notes` line, because then setup would drop text it does not own.
notes() {
  local file=$1 out=$2 first='' line bytes
  IFS= read -r first < "$file" || [ -n "$first" ] || first=''
  case $first in
    "$marker_prefix"*) ;;
    *) fail "$file was not written by setup: its first line is not the marker line. It is left as it is." ;;
  esac
  line=$(grep -a -n -m 1 -x '## Notes' "$file" | cut -d: -f1)
  [ -n "$line" ] || fail "$file has no '## Notes' line. It is left as it is."
  bytes=$(head -n "$line" "$file" | wc -c) || fail "cannot read $file."
  tail -c +"$((bytes + 1))" "$file" > "$out" || fail "cannot read $file."
}

# Renders the issue tracker into $work/issue-tracker.md: the template with the facts, up to
# and including its `## Notes` line, then the existing file's notes, or none.
if [ "$issue_tracker" = 1 ]; then
  [ -n "$repo" ] || fail "--issue-tracker needs --repo <owner/name>."
  [ -n "$default_branch" ] || fail "--issue-tracker needs --default-branch <branch>."
  case $repo$default_branch in *$'\n'*|*$'\r'*) fail "--repo and --default-branch must be one line." ;; esac
  template="$templates/issue-tracker.md"
  [ -f "$template" ] || fail "the template is missing: $template"
  grep -q -x '## Notes' "$template" || fail "the template has no '## Notes' line: $template"
  if [ -e "$tracker" ]; then
    [ -f "$tracker" ] || fail "$tracker is not a file."
    notes "$tracker" "$work/notes"
  else
    : > "$work/notes"
  fi
  sed -e "s#{{repo}}#$(sed_escape "$repo")#g" \
      -e "s#{{default_branch}}#$(sed_escape "$default_branch")#g" "$template" > "$work/rendered" \
    || fail "cannot render $template."
  awk '{ print } $0 == "## Notes" { exit }' "$work/rendered" > "$work/head" || fail "cannot render $template."
  cat "$work/head" "$work/notes" > "$work/issue-tracker.md" || fail "cannot render $template."
fi

# Every check has passed. Write the files.
written=()
for b in "${behaviours[@]+"${behaviours[@]}"}"; do
  target=$(behaviour_target "$b")
  mkdir -p "$(dirname "$target")" 2>/dev/null || fail "cannot create the directory of $target."
  cp "$(behaviour_template "$b")" "$target" 2>/dev/null || fail "cannot copy the template of $b to $target."
  written+=("$target")
done
if [ "$issue_tracker" = 1 ]; then
  mkdir -p "$(dirname "$tracker")" 2>/dev/null || fail "cannot create the directory of $tracker."
  cat "$work/issue-tracker.md" > "$tracker" 2>/dev/null || fail "cannot write $tracker."
  written+=("$tracker")
fi

printf '%s\n' "${written[@]}"
