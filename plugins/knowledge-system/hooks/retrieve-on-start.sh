#!/bin/bash
set -euo pipefail

# SessionStart hook: remind Claude to retrieve relevant knowledge.
# Command hooks communicate via JSON stdout with a systemMessage field.

cat <<'EOF'
{
  "systemMessage": "A new session has started. Run the retrieve-knowledge skill to scan for rules, skills, and critical patterns relevant to this session before beginning work."
}
EOF
