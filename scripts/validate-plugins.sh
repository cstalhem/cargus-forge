#!/usr/bin/env bash
# Validate each plugin and the marketplace root with `claude plugin validate --json`.
# Reads the manifest's problems and those of each skill, agent and command in `contents`.
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
        (.manifest, .contents[]?) | .errors[]?, (.warnings[]? | select((.path == "version" or (.path // "" | endswith(" → version"))) | not))
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

# `claude plugin validate` does not catch a skill that injects a file that does not exist, so check each
# !`cat "${CLAUDE_PLUGIN_ROOT}/<path>"` and !`bash "${CLAUDE_SKILL_DIR}/<path>"` here. A `cat docs/glossary.md`
# reads the user's repo and may be absent, so it has no variable and is not matched.
for skill in plugins/*/skills/*/SKILL.md; do
  while IFS= read -r injection; do
    var=${injection#*\$\{}
    var=${var%%\}*}
    path=${injection#*\}/}
    path=${path%\"}
    if [ "$var" = CLAUDE_PLUGIN_ROOT ]; then
      file=${skill%%/skills/*}/$path
    else
      file=$(dirname "$skill")/$path
    fi
    if [ ! -f "$file" ]; then
      echo "$skill: injects $path, which does not exist"
      status=1
    fi
  done < <(grep -oE '!`(cat|bash) "\$\{CLAUDE_(PLUGIN_ROOT|SKILL_DIR)\}/[^"]+"' "$skill")
done

exit "$status"
