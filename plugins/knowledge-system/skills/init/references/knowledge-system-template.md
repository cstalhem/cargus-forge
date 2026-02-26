# Knowledge System

Project knowledge lives in three tiers. Each has a distinct purpose and update trigger.

| Tier        | Location                | Loads                | Contains                                               |
| ----------- | ----------------------- | -------------------- | ------------------------------------------------------ |
| Orientation | `{L1_FILE}` (this file) | Always               | Project structure, commands, design assumptions        |
| Rules       | `.claude/rules/`        | Always (path-scoped) | Concise do/don't rules                                 |
| Skills      | `.claude/skills/`       | On demand            | Deep reference: examples, anti-patterns, decision aids |

**Staging area** (`.claude/staging.md`) holds unvalidated learnings discovered during work. Do NOT use the native `MEMORY.md` for this purpose.

### Updating the knowledge system

When you discover something worth capturing during work:

1. **Caused by a mistake or gotcha?** → Add a one-line rule to the relevant file in `.claude/rules/`. Then update the matching skill's Anti-Patterns section with the full context (what went wrong, why, the fix).
2. **New pattern, example, or decision aid?** → Update the relevant skill in `.claude/skills/`.
3. **New topic not covered by any existing skill?** → Create a new skill directory with `SKILL.md`. Keep description under 200 chars.
4. **Not validated yet?** → Add an entry to `.claude/staging.md` with a date, context tag, and what you observed. Promote to a rule or skill when the pattern recurs across 2+ sessions, then delete the staging entry.

### Proactive maintenance

- After fixing a bug caused by a missing rule, suggest adding the rule.
- After a session where a skill would have prevented confusion, suggest updating it.
- When `.claude/staging.md` entries have been validated across 2+ sessions, suggest promotion.
- Keep rules to one line each — no code examples, no rationale (that belongs in skills).
- Keep skill content timeless — no phase numbers, plan numbers, or session-specific context.
- Surface lint/type/test errors immediately rather than deferring them.
