#!/usr/bin/env bash
set -u

script="$(cd "$(dirname "$0")" && pwd)/check-comments.sh"
failures=0
tmp=$(mktemp -d "${TMPDIR:-/tmp}/check-comments.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
export GIT_CEILING_DIRECTORIES=$tmp

fixture() {
  local root
  root=$(mktemp -d "$tmp/repo.XXXXXX") || exit 1
  git -C "$root" init -q
  mkdir -p "$root/scripts"
  printf '#!/usr/bin/env bash\n# one\n# two\necho hi\n' > "$root/old.sh"
  printf '#!/usr/bin/env bash\necho hi\n' > "$root/clean.sh"
  printf '2 old.sh\n' > "$root/scripts/comments-baseline.txt"
  git -C "$root" add -A
  echo "$root"
}

check() {
  local desc=$1 want_rc=$2 want_out=$3 root=$4 out rc
  shift 4
  out=$("$script" "$@" "$root" 2>&1)
  rc=$?
  if [ "$rc" = "$want_rc" ] && [[ $out == $want_out ]]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc (exit $rc): $out"
    failures=$((failures + 1))
  fi
}

root=$(fixture)
check "a file at its baseline passes" 0 '' "$root"

root=$(fixture)
printf '# new\n' >> "$root/clean.sh"
check "a comment in a file with no baseline line fails" 1 'clean.sh: 1 comment lines, 0 allowed.*' "$root"

root=$(fixture)
printf '# three\n' >> "$root/old.sh"
check "a comment above a file's baseline fails" 1 'old.sh: 3 comment lines, 2 allowed.*' "$root"

root=$(fixture)
printf '#!/usr/bin/env bash\n# one\necho hi\n' > "$root/old.sh"
check "a file below its baseline fails until the baseline is lowered" 1 'old.sh: 1 comment lines, 2 allowed.*--update*' "$root"
check "--update lowers the baseline" 0 '' "$root" --update
if [ "$(cat "$root/scripts/comments-baseline.txt")" = '1 old.sh' ]; then
  echo "ok: the lowered baseline holds the new count"
else
  echo "FAIL: the lowered baseline holds the new count"
  failures=$((failures + 1))
fi

root=$(fixture)
printf '# three\n' >> "$root/old.sh"
check "--update never raises the baseline" 1 'old.sh: 3 comment lines, 2 allowed.*' "$root" --update

root=$(fixture)
printf '#!/usr/bin/env bash\necho hi\n' > "$root/old.sh"
"$script" --update "$root" >/dev/null
if [ ! -s "$root/scripts/comments-baseline.txt" ]; then
  echo "ok: a file with no comment left has no baseline line"
else
  echo "FAIL: a file with no comment left has no baseline line"
  failures=$((failures + 1))
fi

root=$(fixture)
printf 'const a = 1;\n// new\n' > "$root/new.mjs"
git -C "$root" add new.mjs
check "a // comment in a JavaScript file fails" 1 'new.mjs: 1 comment lines, 0 allowed.*' "$root"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
