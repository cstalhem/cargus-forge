#!/bin/bash
set -euo pipefail

# SessionStart hook: remind Claude to retrieve relevant knowledge.
# For SessionStart, stdout text is added to Claude's context before the first prompt.

echo "A new session has started. Run the retrieve-knowledge skill to scan for rules, skills, and critical patterns relevant to this session before beginning work."
