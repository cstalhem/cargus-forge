---
name: retrieve-knowledge
description: "Scan project rules and skills for knowledge relevant to the current task before starting non-trivial work"
user-invocable: false
model: sonnet
allowed-tools: Read, Grep, Glob
---

# Retrieve Relevant Knowledge

Scan the project's knowledge system for rules, skills, and critical patterns relevant to the current task. Run this **before starting non-trivial work** — skip for trivial changes (typos, copy edits, color changes, one-line fixes).

## Steps

### 1. Extract task keywords

From the current task context, identify:
- Technologies and frameworks involved (e.g., "React", "PostgreSQL", "auth")
- File paths or directories being modified
- Concepts and patterns (e.g., "migration", "API endpoint", "error handling")

### 2. Search rules

Grep `.claude/rules/` (including `critical-patterns.md`) for keyword matches:

```
.claude/rules/*.md
```

For each match, read the relevant rule line(s) — not the entire file.

### 3. Search skills

Glob `.claude/skills/*/SKILL.md` and read only the frontmatter `description` field of each skill. For skills whose description matches the task context, note them as relevant.

Do NOT read full skill content — only surface which skills exist and what they cover.

### 4. Check staging entries

Scan `MEMORY.md` for index lines containing `- [staging:` that match the task keywords. If any exist, note them — they may contain unvalidated gotchas relevant to the current work.

Do NOT read the full staging files — just surface their one-line descriptions from the index.

### 5. Return summary

Output a brief summary of relevant findings:

- **Applicable rules:** List each relevant rule (one line each)
- **Applicable critical patterns:** List any WRONG/CORRECT patterns that apply
- **Relevant skills:** List skill names and descriptions that the model should load if needed
- **Staging entries:** List any matching staging descriptions (flag as unvalidated)

If nothing relevant is found, say so and proceed — do not force matches.
