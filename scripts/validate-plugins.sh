#!/usr/bin/env bash
# Validate each plugin and the marketplace root with `claude plugin validate --json`.
# Fails on every error and on every warning except the one about a missing `version`:
# plugins carry no version, because Claude Code versions them by commit SHA. A plugin's
# report names that warning `version`; the marketplace root's names it `plugins[N] plugin.json → version`.
# Usage: validate-plugins.sh
set -uo pipefail

cd "$(dirname "$0")/.."
status=0

for dir in plugins/*/ .; do
  code=0
  report=$(claude plugin validate --json "$dir" 2>&1) || code=$?
  # claude exits 1 on an error but still prints the JSON report, so read the report first.
  if ! problems=$(jq -r '
        (.manifest.errors[]?, (.manifest.warnings[]? | select((.path == "version" or (.path // "" | endswith(" → version"))) | not)))
        | "  " + (.path // "-") + ": " + .message
      ' <<<"$report" 2>/dev/null); then
    echo "$dir: claude plugin validate gave no JSON report (exit $code)"
    printf '%s\n' "$report" | sed 's/^/  /'
    status=1
  elif [ -n "$problems" ]; then
    echo "$dir:"
    printf '%s\n' "$problems"
    status=1
  elif [ "$code" -ne 0 ]; then
    echo "$dir: claude plugin validate exited $code with no error in its report"
    status=1
  fi
done

exit "$status"
