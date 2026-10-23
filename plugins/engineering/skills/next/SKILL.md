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
2. **Repair.** If the `## Repairs` part of the Facts is `- none`, go to step 3. Otherwise, for each entry, which starts with a line `- #<n> · <change> · <fact>`, without asking:
   1. Run each indented `gh api` line under it, exactly as printed, one call at a time, in order.
   2. Read the labels back with `gh api 'repos/{owner}/{repo}/issues/<n>/labels?per_page=100' --jq '.[].name'`. Unless they are the labels on the entry's `labels after:` line, in any order, stop and name the issue and the difference.
3. **Report.** Show the `## Report` part of the Facts exactly as printed: each `### <group>` with its lines, then the `Next:` line. Add nothing to it and leave nothing out. If step 2 repaired labels, then show a `## Repairs` heading with the `- #<n> · …` line of each entry, as printed, without its calls and its `labels after:` line.

## Facts
!`bash "${CLAUDE_SKILL_DIR}/status.sh"`
