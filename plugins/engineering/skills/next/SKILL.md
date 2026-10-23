---
name: next
description: Show where each open issue stands and suggest one next command. Lists the open issues in status groups, with their blockers, their umbrella and a suggested command each, from status.sh.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh")
---

# next

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The Facts section below is the output of `status.sh`, which read GitHub and git when this skill loaded. Do not fetch the facts again, and do not change them.
- Run none of the suggested commands. The user picks what to run.

## Steps
1. **Check.** If the Facts section starts with `status.sh error:`, show that line and stop.
2. **Report.** Show the `## Report` part of the Facts exactly as printed: each `### <group>` with its lines, then the `Next:` line. Add nothing to it and leave nothing out.

## Facts
!`bash "${CLAUDE_SKILL_DIR}/status.sh"`
