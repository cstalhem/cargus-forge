#!/usr/bin/env bash
# apply.sh: writes the optional behaviours that the user accepted in /engineering:setup.
# Run it from the root of the user's repo. It finds the plugin's templates relative to its
# own location, writes only the paths that its arguments name, and prints each path it wrote,
# one per line. It never writes `docs/agents/commands.md`, which the model writes, and it runs
# no `git` or `gh` command (#149 D1).
#
# Usage:
#   apply.sh --behaviour <name> [--behaviour <name>]...
#
#   --behaviour <name>  copy an optional behaviour's file from the template with `cp`, so the
#                       copy is byte-identical (#85 D8). Known: close-sub-issue.
#
# An error prints one line, `apply.sh error: <reason>`, to stderr and exits 1. The arguments
# and the templates are checked before the first write, so an error in them writes nothing.

set -u

fail() {
  local msg
  msg=$(printf '%s' "$*" | tr '\r\n' '  ')
  printf 'apply.sh error: %s\n' "$msg" >&2
  exit 1
}

here=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || fail "cannot find the directory of apply.sh."
templates="$here/../../templates"

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

behaviours=()

while [ $# -gt 0 ]; do
  case $1 in
    --behaviour)
      [ $# -ge 2 ] || fail "$1 needs a value."
      case $2 in --*|'') fail "$1 needs a value." ;; esac
      behaviour_target "$2" >/dev/null || fail "unknown behaviour: $2. Known: close-sub-issue."
      case " ${behaviours[*]-} " in *" $2 "*) ;; *) behaviours+=("$2") ;; esac
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[ "${#behaviours[@]}" -gt 0 ] || fail "nothing to write: pass --behaviour <name>."

for b in "${behaviours[@]}"; do
  [ -f "$(behaviour_template "$b")" ] || fail "the template of $b is missing: $(behaviour_template "$b")"
done

# Every check has passed. Write the files.
written=()
for b in "${behaviours[@]}"; do
  target=$(behaviour_target "$b")
  mkdir -p "$(dirname "$target")" 2>/dev/null || fail "cannot create the directory of $target."
  cp "$(behaviour_template "$b")" "$target" 2>/dev/null || fail "cannot copy the template of $b to $target."
  written+=("$target")
done

printf '%s\n' "${written[@]}"
