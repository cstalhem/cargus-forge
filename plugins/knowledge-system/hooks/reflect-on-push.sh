#!/bin/bash
set -euo pipefail

# PostToolUse(Bash) hook: when Claude publishes work (git push / gh pr create),
# remind it to reflect on whether the work warrants a knowledge-system update.
# Reads the hook payload from stdin and emits context only on a match, so every
# other Bash command is a no-op. PostToolUse fires only after the tool succeeds,
# so a failed push never triggers the reminder.

payload="$(cat)"

if printf '%s' "$payload" | grep -Eq 'git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create'; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Work was just published. Reflect on whether anything discovered during it warrants a knowledge-system update — a new rule, skill, critical pattern, or staging entry. If so, capture it now and commit the change as a follow-up. If nothing qualifies, continue without changes."
  }
}
EOF
fi
