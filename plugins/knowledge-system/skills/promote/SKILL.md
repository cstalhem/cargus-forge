---
name: promote-staging
description: "Review MEMORY.md staging entries and promote validated learnings to rules, skills, or critical patterns"
user-invocable: false
model: sonnet
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Promote Staging Entries

Review the project's staging entries and promote validated ones to their permanent tier. Run this at **end-of-session or natural stopping points**.

## Steps

### 1. Find staging entries

Read `MEMORY.md` and scan for index lines containing `- [staging:`. For each match, note the referenced filename.

If no staging entries exist, report that and stop — nothing to promote.

### 2. Read and evaluate candidates

Read each `staging_*.md` file referenced from the index. For each entry, note:
- Its metadata tags in the `description` field (`[type:...]`, `[area:...]`, `[promotion-candidate]`)
- The date it was created and whether similar entries have appeared before
- Whether it has enough detail to be actionable

An entry is ready for promotion if any of these apply:
- Tagged with `[promotion-candidate]`
- Has recurred across 2+ sessions (based on dates or multiple observations)
- Has accumulated enough detail to be actionable

### 3. Present options

For each promotion candidate, use AskUserQuestion to present the options:

- **Promote to rule** → Add a one-line rule to the appropriate `.claude/rules/*.md` file
- **Promote to skill** → Create or update a skill in `.claude/skills/`
- **Promote to critical pattern** → Add a WRONG/CORRECT entry to `.claude/rules/critical-patterns.md`
- **Keep in staging** → Leave for further validation
- **Discard** → Delete

Include the entry content and your recommendation in the question.

### 4. Execute promotions

For each approved promotion:

**To rule:**
- Determine the best target rules file based on `[area:...]` tag and existing file structure
- Add the rule as a single line under the appropriate section header
- Add `(see skill: skill-name)` cross-reference if a related skill exists

**To skill:**
- Create a new skill directory or update an existing skill
- Include examples and anti-patterns from the staging entry
- Cross-reference the relevant rules file

**To critical pattern:**
- Add a WRONG/CORRECT entry to `.claude/rules/critical-patterns.md`
- Include the root cause in the "Why:" line

### 5. Clean up

For promoted and discarded entries:
1. Delete the `staging_*.md` file
2. Remove its index line from `MEMORY.md`

Keep entries the user chose to retain in staging — no changes needed for those.
