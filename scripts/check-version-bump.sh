#!/usr/bin/env bash
# Report each plugin that changed since its merge-base with <base> without a greater plugin.json version.
# Usage: check-version-bump.sh <base> [root]
set -euo pipefail

base=${1:?usage: check-version-bump.sh <base> [root]}
root=${2:-.}
merge_base=$(git -C "$root" merge-base "$base" HEAD)
status=0

for name in $(git -C "$root" diff --name-only "$base"...HEAD -- plugins/ | cut -d/ -f2 | sort -u); do
  manifest="plugins/$name/.claude-plugin/plugin.json"
  # A plugin that is new or deleted at HEAD has no version to compare.
  git -C "$root" cat-file -e "$merge_base:$manifest" 2>/dev/null || continue
  git -C "$root" cat-file -e "HEAD:$manifest" 2>/dev/null || continue
  old=$(git -C "$root" show "$merge_base:$manifest" | jq -r .version)
  new=$(git -C "$root" show "HEAD:$manifest" | jq -r .version)
  if [ "$old" = "$new" ] || [ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -n1)" != "$new" ]; then
    echo "$name: version $new is not greater than $old at the merge-base with $base"
    status=1
  fi
done

exit "$status"
