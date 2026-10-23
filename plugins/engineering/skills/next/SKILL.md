---
name: next
description: Show where each open issue stands and suggest one next command. Lists the open issues in status groups, with their blockers, their umbrella and a suggested command each, from status.sh, and repairs each status label that the facts contradict.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh")
---

# next

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The Facts section below is the output of `status.sh`, which read GitHub and git when this skill loaded. Do not fetch the facts again, other than the label read-back in step 2, and do not change them.
- Run none of the suggested commands. The user picks what to run. The `gh api` calls under `## Repairs` are not suggestions: step 2 runs them.
- A repair follows the label rule above. `status.sh` read the labels, which stands for its step 1, and it removes only labels that it read.

## Steps
1. **Check.** If the Facts section starts with `status.sh error:`, show that line and stop.
2. **Repair.** If the `## Repairs` part of the Facts is `- none`, go to step 3. Otherwise, take the entries one at a time, in the order printed. Each entry starts with a line `- #<n> · <change> · <fact>`. Do not ask, and show no text unless a read-back differs. Finish one entry, its read-back included, before you start the next, and never put calls of two entries, or two calls, in one message. For each entry:
   1. Run each indented `gh api` line under it as its own Bash call, exactly as printed, one at a time, in order. Add nothing to a call: no `>/dev/null`, no `&&` or `;` chain, no pipe and no `--jq`.
   2. Read the labels back, as its own Bash call, with `gh api 'repos/{owner}/{repo}/issues/<n>/labels?per_page=100' --jq '[.[].name] | sort | tojson'`. Its output must be exactly the JSON array on the entry's `labels after:` line, which holds the labels sorted the same way.
   3. If it is not, run no further call. Show the issue number, the expected array and the array you read, and stop. Ask no question, do not retry, and skip step 3.
3. **Report.** Your reply is these parts, in this order, and nothing else:
   1. The `## Report` part of the Facts exactly as printed: the `## Report` heading, each `### <group>` with its lines, then the `Next:` line.
   2. Only if step 2 ran a repair: a `## Repairs` heading, then the `- #<n> · …` line of each entry, as printed, one per line, without its calls and its `labels after:` line.
   Add no text before, between or after them: no summary, no read-back result and no comment.

## Facts
!`bash "${CLAUDE_SKILL_DIR}/status.sh"`
