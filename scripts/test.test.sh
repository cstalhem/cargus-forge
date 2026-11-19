#!/usr/bin/env bash
# Tests for test.sh, run against fixture repos built under mktemp -d.
# Usage: bash scripts/test.test.sh
set -u

script="$(cd "$(dirname "$0")" && pwd)/test.sh"
failures=0
tmp=$(mktemp -d "${TMPDIR:-/tmp}/test-sh.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

# Prints the root of a new git repo with one test file of each kind. Each one
# appends its own name to $ran when it runs; the .py and .mjs ones fail when
# $FAIL_<kind> is set, and the .test.sh one fails when $FAIL_sh is set.
fixture() {
  local root
  root=$(mktemp -d "$tmp/repo.XXXXXX") || exit 1
  mkdir -p "$root/a" "$root/b"
  cat > "$root/a/one.test.sh" <<'EOF'
echo one.test.sh >> "$RAN"
if [[ -n ${FAIL_sh:-} ]]; then echo "one-sh-output"; exit 1; fi
EOF
  cat > "$root/a/test_two.py" <<'EOF'
import os, unittest
class T(unittest.TestCase):
    def test_it(self):
        open(os.environ["RAN"], "a").write("test_two.py\n")
        if os.environ.get("FAIL_py"):
            self.fail("two-py-output")
if __name__ == "__main__":
    unittest.main()
EOF
  cat > "$root/b/three.test.mjs" <<'EOF'
import { test } from "node:test";
import { appendFileSync } from "node:fs";
test("it", () => {
  appendFileSync(process.env.RAN, "three.test.mjs\n");
  if (process.env.FAIL_mjs) throw new Error("three-mjs-output");
});
EOF
  git -C "$root" init -q && git -C "$root" add -A
  echo "$root"
}

# check <test name> <expected exit code> <expected files run> <expected output substring> [VAR=value ...]
check() {
  local name=$1 want_code=$2 want_ran=$3 want_out=$4 root out code ran
  shift 4
  root=$(fixture)
  ran="$tmp/ran.$name"
  : > "$ran"
  out=$(env RAN="$ran" "$@" bash "$script" "$root" 2>&1)
  code=$?
  got_ran=$(sort "$ran" | tr '\n' ' ')
  if [[ $code -ne $want_code || $got_ran != "$want_ran" || $out != *"$want_out"* ]]; then
    printf 'FAIL %s\n  want exit %s, ran %q, output with %q\n  got  exit %s, ran %q, output %q\n' \
      "$name" "$want_code" "$want_ran" "$want_out" "$code" "$got_ran" "$out"
    failures=$((failures + 1))
  else
    echo "ok   $name"
  fi
}

all=$(printf '%s\n' one.test.sh test_two.py three.test.mjs | sort | tr '\n' ' ')

check "all three kinds run and pass" 0 "$all" ""
check "a failing .test.sh prints its output" 1 "$all" "one-sh-output" FAIL_sh=1
check "a failing test_*.py prints its output" 1 "$all" "two-py-output" FAIL_py=1
check "a failing *.test.mjs prints its output" 1 "$all" "three-mjs-output" FAIL_mjs=1

if [[ $failures -ne 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
