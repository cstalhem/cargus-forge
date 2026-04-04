# Knowledge System

The purpose of this system is to make each change to the code simpler than the last, by continually capturing gotchas, patterns, and decisions as they're discovered.

Project knowledge lives in three tiers. Each has a distinct purpose and update trigger.

| Tier        | Location                | Loads                | Contains                                               |
| ----------- | ----------------------- | -------------------- | ------------------------------------------------------ |
| Orientation | `{L1_FILE}` (this file) | Always               | Project structure, commands, design assumptions        |
| Rules       | `.claude/rules/`        | Always (path-scoped) | Concise do/don't rules                                 |
| Skills      | `.claude/skills/`       | On demand            | Deep reference: examples, anti-patterns, decision aids |

**Staging area** — unvalidated learnings are stored as individual `staging_*.md` files in the project's memory directory (same directory as `MEMORY.md`), with index lines in `MEMORY.md` prefixed with `- [staging:`. This integrates with the auto-memory system rather than conflicting with it.

**Critical patterns** — `.claude/rules/critical-patterns.md` captures high-impact WRONG/CORRECT patterns for mistakes that break builds, cause data loss, or create security issues.

### Workflow checkpoints

- **Before non-trivial tasks:** Scan `.claude/rules/` (including `critical-patterns.md`) and `.claude/skills/` for knowledge relevant to the task at hand. Skip for trivial changes (typos, copy edits, color tweaks, one-line fixes).
- **After completing tasks:** Check if anything discovered during the task should be staged in `MEMORY.md`.

### Updating the knowledge system

When you discover something worth capturing during work:

1. **Caused by a mistake or gotcha?** → Add a one-line rule to the relevant file in `.claude/rules/`. Update the matching skill's Anti-Patterns section with the full context (what went wrong, why, the fix).
2. **High-impact mistake (build-breaking, data loss, security)?** → Add a WRONG/CORRECT entry to `.claude/rules/critical-patterns.md`.
3. **New pattern, example, or decision aid?** → Update the relevant skill in `.claude/skills/`.
4. **New topic not covered by any existing skill?** → Create a new skill directory with `SKILL.md`. Keep description under 200 chars.
5. **Not validated yet?** → Create a `staging_<slug>.md` file in the project's memory directory with frontmatter tags (`[staging] [type:gotcha|pattern|decision] [area:<project-area>]`) and add an index line to `MEMORY.md` prefixed with `- [staging:`. Add `[promotion-candidate]` to the description when the pattern recurs across 2+ sessions.

### Cross-referencing

- Rules reference backing skills: `(see skill: skill-name)` for deeper context.
- Skills reference the rules they support for quick lookup.

### Proactive maintenance

- After fixing a bug caused by a missing rule, suggest adding the rule.
- After a session where a skill would have prevented confusion, suggest updating it.
- When staging entries (files prefixed `staging_*` in the memory directory) have been validated across 2+ sessions, suggest promotion.
- When a rule or skill leads to incorrect behavior, flag it: critical issues → propose a direct fix (with user approval), minor issues → create a staging entry with `[type:gotcha]` and `[promotion-candidate]` tags.
- Keep rules to one line each — no code examples, no rationale (that belongs in skills).
- Keep skill content timeless — no phase numbers, plan numbers, or session-specific context.
- Surface lint/type/test errors immediately rather than deferring them.
