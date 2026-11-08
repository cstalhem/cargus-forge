#!/usr/bin/env bash
# bodies.sh: the issue bodies for /engineering:next (#344).
# Prints a filtered copy of each open issue's body, so that next can compare the issues for shared
# files, conflicting goals and dependencies. It reads the open issues through `gh api` REST and
# changes nothing. Only next loads it: the Autopilots load status.sh every run and do not carry
# the bodies (#344 D6).
# It always exits 0 and prints errors as text, because a non-zero exit stops the skill.
# An error prints exactly one line, `bodies.sh error: <reason>`, and nothing else: each jq call
# sends its stderr to /dev/null, and the output is printed only once it is complete.
#
# Output: for each open issue, no PR, lowest number first, a heading `### #<n> <title>` and its
# text, or `- none` when no issue is open. The text is, the first that applies:
#   - the line `from <login>, not a trusted author`, when the issue's author is not a trusted
#     author: its body is text from outside the repo (#362);
#   - the `## What it delivers` and `## Files` sections, when the body has the first;
#   - the `## Goal` and `## Out of scope` sections, when the body has the first;
#   - the whole body.
# A text longer than its share, min(2000, floor(24000 / the number of open issues)) characters,
# is cut to its share and ends with `…`. A `!`cmd`` injection keeps about 30,000 characters
# (#344 D7), and the 24,000 leave room for the headings.

set -u

# `fail`, `read_list` and `JQ_TRUSTED` come from the plugin's shared file. `fail` does not exist
# until it is loaded, so a missing file prints its own error line.
lib=$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh
if [ ! -f "$lib" ]; then
  printf '%s error: cannot find %s\n' "$(basename "$0")" "$lib"
  exit 0
fi
. "$lib"

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed."
done

# The issues endpoint lists PRs too.
read_list 'repos/{owner}/{repo}/issues?state=open'

out=$(printf '%s' "$items" | jq -r "$JQ_TRUSTED"'
  map(select(has("pull_request") | not)) | sort_by(.number) as $all

  # The sections of a body, by name: each one is its `## <name>` heading line and the lines under
  # it up to the next `## ` heading.
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
