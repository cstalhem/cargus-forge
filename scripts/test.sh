#!/usr/bin/env bash
# Runs every tracked test file: *.test.sh with bash, test_*.py with unittest and
# *.test.mjs with node --test. Prints the output of each file that fails and exits
# non-zero if any fails.
# Usage: scripts/test.sh [repo root]
set -u

root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
cd "$root" || exit 1

status=0
while IFS= read -r file; do
  case $file in
    *.test.sh) cmd=(bash "$file") ;;
    test_*.py | */test_*.py) cmd=(python3 -m unittest "$file") ;;
    *.test.mjs) cmd=(node --test "$file") ;;
    *) continue ;;
  esac
  if ! out=$("${cmd[@]}" 2>&1); then
    echo "FAIL $file"
    printf '%s\n' "$out"
    status=1
  fi
done < <(git ls-files)
exit "$status"
