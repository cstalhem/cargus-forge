#!/usr/bin/env bash
set -u

update=0
if [ "${1:-}" = --update ]; then
  update=1
  shift
fi
root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$root" || exit 1
baseline=scripts/comments-baseline.txt

count() {
  case $1 in
    *.sh | *.bash | *.yml | *.yaml | *.py) grep -cE '^[[:space:]]*#( |$)' "$1" ;;
    *.js | *.mjs | *.cjs | *.ts) grep -cE '^[[:space:]]*(//|/\*|\*( |/|$))' "$1" ;;
    *) return 1 ;;
  esac
}

allowed() {
  [ -f "$baseline" ] || { echo 0; return; }
  awk -v f="$1" '$2 == f { n = $1 } END { print n + 0 }' "$baseline"
}

status=0
next=''
while IFS= read -r file; do
  [ -f "$file" ] || continue
  now=$(count "$file") || [ -n "$now" ] || continue
  was=$(allowed "$file")
  if [ "$now" -gt "$was" ]; then
    echo "$file: $now comment lines, $was allowed. Delete the new comments: a reason goes in an ADR, an issue or a test name."
    status=1
  elif [ "$now" -lt "$was" ] && [ "$update" = 0 ]; then
    echo "$file: $now comment lines, $was allowed. Lower the baseline with scripts/check-comments.sh --update."
    status=1
  fi
  [ "$now" -lt "$was" ] && was=$now
  [ "$was" -eq 0 ] || next+="$was $file"$'\n'
done < <(git ls-files)

if [ "$update" = 1 ]; then
  printf '%s' "$next" > "$baseline"
fi
exit "$status"
