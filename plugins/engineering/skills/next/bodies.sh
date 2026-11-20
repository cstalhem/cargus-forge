#!/usr/bin/env bash
set -u

lib=$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh
if [ ! -f "$lib" ]; then
  printf '%s error: cannot find %s\n' "$(basename "$0")" "$lib"
  exit 0
fi
. "$lib"

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

read_list 'repos/{owner}/{repo}/issues?state=open'

out=$(printf '%s' "$items" | jq -r "$JQ_TRUSTED"'
  map(select(has("pull_request") | not)) | sort_by(.number) as $all

  | def sections:
      (.body // "") | split("\n") | map(rtrimstr("\r"))
      | reduce .[] as $l ({cur: null, out: {}};
          if ($l | test("^## ")) then
            ($l | sub("^## +"; "") | sub("[ \t]+$"; "")) as $name
            | .cur = $name | .out[$name] = ((.out[$name] // []) + [$l])
          elif .cur != null then .out[.cur] += [$l]
          else . end)
      | .out | map_values(join("\n") | sub("\\s+$"; ""));
    def pick($names):
      sections as $s | [$names[] | select($s[.] != null) | $s[.]] | join("\n\n");

    ([2000, (24000 / ([($all | length), 1] | max) | floor)] | min) as $share

  | if ($all | length) == 0 then "- none" else
      $all | map(
        (sections | keys) as $has
        | (if (trusted | not) then "from \(.user.login // "unknown"), not a trusted author"
           elif ($has | index("What it delivers")) then pick(["What it delivers", "Files"])
           elif ($has | index("Goal")) then pick(["Goal", "Out of scope"])
           else ((.body // "") | gsub("\r"; "") | sub("\\s+$"; "")) end) as $text
        | "### #\(.number) \(.title)\n\(if ($text | length) > $share then $text[0:($share - 1)] + "…" else $text end)")
      | join("\n\n")
    end
' 2>/dev/null) || fail "cannot build the bodies."

printf '%s\n' "$out"
