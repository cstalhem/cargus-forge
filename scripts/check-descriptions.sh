#!/usr/bin/env bash
# Reports each plugin whose description in .claude-plugin/marketplace.json or the
# README Plugin Index differs from its plugin.json, or is missing from one of them.
# Prints nothing and exits 0 when
# every listing matches; prints one line per problem and exits 1 otherwise.
# Usage: check-descriptions.sh [repo-root]   (defaults to the repo holding this script)
set -euo pipefail

root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
marketplace="$root/.claude-plugin/marketplace.json"
# Only the Plugin Index section, so a plugin path in another section can't match.
index=$(awk '/^## /{in_index = ($0 == "## Plugin Index")} in_index' "$root/README.md")
status=0

for manifest in "$root"/plugins/*/.claude-plugin/plugin.json; do
  dir=$(basename "$(dirname "$(dirname "$manifest")")")
  name=$(jq -r .name "$manifest")
  want=$(jq -r .description "$manifest")

  if ! jq -e --arg n "$name" 'any(.plugins[]; .name == $n)' "$marketplace" >/dev/null; then
    echo "$name: missing from marketplace.json"
    status=1
  else
    got=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .description' "$marketplace")
    if [[ $got != "$want" ]]; then
      echo "$name: marketplace.json differs from plugin.json"
      status=1
    fi
  fi

  marker="(\`plugins/$dir\`): "
  line=$(grep -F -- "$marker" <<<"$index" | head -n 1 || true)
  if [[ -z $line ]]; then
    echo "$name: missing from README.md"
    status=1
  elif [[ ${line#*"$marker"} != "$want" ]]; then
    echo "$name: README.md differs from plugin.json"
    status=1
  fi
done

exit "$status"
