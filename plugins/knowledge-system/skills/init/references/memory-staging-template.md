# Staging Convention

Staging entries are unvalidated learnings discovered during work. Each entry is stored as an individual memory file following the auto-memory format.

## File format

Each staging entry is a file named `staging_<slug>.md` in the project's memory directory:

```markdown
---
name: <short description>
description: "[staging] [type:gotcha|pattern|decision] [area:<project-area>] <one-line summary>"
type: project
---

<date, context, and what you observed>
```

## Index format

Each staging file gets an index line in `MEMORY.md`:

```
- [staging: <short description>](staging_<slug>.md) — [<type>] [area:<project-area>] <one-line summary>
```

## When to create staging entries

- You noticed a gotcha or sharp edge but aren't sure it generalizes
- A workaround was needed and you want to verify it's the right long-term approach
- A pattern emerged that might deserve a rule or skill, but needs a second occurrence to confirm

## When to promote

- Recurred across 2+ sessions → promote to rule in `.claude/rules/`
- Grown with examples and edge cases → promote to skill in `.claude/skills/`
- High-impact WRONG/CORRECT pattern → promote to `.claude/rules/critical-patterns.md`
- After promotion, **delete the staging file and its index line**

## When to discard

- Entry turned out to be wrong or situational → delete file and index line
- Entry duplicates an existing rule or skill → delete file and index line
