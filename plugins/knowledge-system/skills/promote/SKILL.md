---
name: promote-staging
description: "Review MEMORY.md staging entries and promote validated learnings to rules, skills, or critical patterns"
user-invocable: false
model: sonnet
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Promote Staging Entries

Review the project's `MEMORY.md` staging area and promote validated entries to their permanent tier. Run this at **end-of-session or natural stopping points**.

## Steps

### 1. Read staging entries

Read the project's `MEMORY.md` and identify entries under the `# Staging Area` section. For each entry, note:
- Its structured metadata tags (`[type:...]`, `[area:...]`, `[promotion-candidate]`)
- How many sessions it has appeared in (check dates if available)
- Whether it has grown with examples or edge cases

### 2. Identify promotion candidates

An entry is ready for promotion if any of these apply:
- Tagged with `[promotion-candidate]`
- Has recurred across 2+ sessions (based on dates or multiple observations)
- Has accumulated enough detail to be actionable

### 3. Present options

For each promotion candidate, use AskUserQuestion to present the options:

- **Promote to rule** → Add a one-line rule to the appropriate `.claude/rules/*.md` file
- **Promote to skill** → Create or update a skill in `.claude/skills/`
- **Promote to critical pattern** → Add a WRONG/CORRECT entry to `.claude/rules/critical-patterns.md`
- **Keep in staging** → Leave it in `MEMORY.md` for further validation
- **Discard** → Delete it from `MEMORY.md`

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

After all promotions are executed, delete the promoted entries from `MEMORY.md`. Keep entries that the user chose to retain or discard (delete discarded ones too).
