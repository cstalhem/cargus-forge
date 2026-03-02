# Staging Area

Temporary holding area for learnings discovered during work. Entries here are **unvalidated** — they may turn out to be wrong, situational, or already covered elsewhere.

## How to use this file

**When to add entries:**
- You noticed a gotcha or sharp edge but aren't sure it generalizes
- A workaround was needed and you want to verify it's the right long-term approach
- A pattern emerged that might deserve a rule or skill, but needs a second occurrence to confirm

**Entry format:**
- One entry per heading: `### <short description>`
- Include date, context, and what you observed
- Tag each entry with structured metadata:
  - `[type:gotcha|pattern|decision]` — what kind of learning this is
  - `[area:<project-area>]` — which part of the project it relates to (e.g., `[area:api]`, `[area:build]`)
  - `[promotion-candidate]` — add this tag when the pattern has been confirmed across 2+ sessions

**When to promote:**
- The pattern has recurred across 2+ sessions → promote to a rule in `.claude/rules/`
- The entry has grown with examples and edge cases → promote to a skill in `.claude/skills/`
- High-impact WRONG/CORRECT pattern → promote to `.claude/rules/critical-patterns.md`
- After promotion, **delete the entry** from this file

**When to discard:**
- The entry turned out to be wrong or situational → delete it
- The entry duplicates an existing rule or skill → delete it
