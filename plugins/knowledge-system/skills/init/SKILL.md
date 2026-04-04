---
name: init-memory
description: "Bootstrap a project knowledge system with guided research and adaptive questioning"
model: opus
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, WebSearch, WebFetch, AskUserQuestion
---

# Knowledge System Init

Bootstrap a three-tier knowledge system for any project. Produces:

- **L1 (Orientation):** AGENTS.md or CLAUDE.md with project overview, commands, design assumptions, and the Knowledge System section
- **L2 (Rules):** `.claude/rules/*.md` with path-scoped one-line rules
- **L3 (Skills):** `.claude/skills/*/SKILL.md` with deep reference material
- **Staging area:** Project-specific `MEMORY.md` for unvalidated learnings

---

## Phase 1: Project Scan

Gather project context using 4 parallel Explore subagents:

1. **Structure** — Directory layout, entry points, build outputs, monorepo detection
2. **Existing docs** — README, CONTRIBUTING, CLAUDE.md, AGENTS.md, .cursorrules, .github/copilot-instructions.md, any `.claude/` content
3. **Tech stack** — Languages, frameworks, package managers, test runners, linters, CI/CD
4. **Code conventions** — Naming patterns, file organization, import style, error handling patterns

### Synthesize into a project profile

From the scan results, determine:

- **Project name and purpose** (from README, package.json, pyproject.toml, etc.)
- **Tech stack summary** (language + framework per component)
- **Key commands** (dev, test, lint, build, deploy)
- **Project classification:**
  - `greenfield` — No existing Claude/AI configuration, no AGENTS.md or CLAUDE.md
  - `partial` — Some docs exist but no structured knowledge system
  - `existing` — Already has a three-tier system (AGENTS.md + rules + skills)
  - `foreign-ai-config` — Has .cursorrules, copilot-instructions.md, or similar non-Claude AI config

Present the profile summary to the user before proceeding.

---

## Phase 2: Gap Analysis & Interview

Adapt questioning based on project classification.

### Greenfield

Run 3-4 focused AskUserQuestion rounds:

1. **Project purpose & context** — What does this project do? Is it personal or team? What's the development stage?
2. **Dev environment & conventions** — Preferred package manager, test approach, any strong conventions? Anything Claude should never do?
3. **Known gotchas** — Any sharp edges, tricky configurations, or "things you always forget"?
4. **L1 file choice** — AGENTS.md (if collaborators/agents will read it) or CLAUDE.md (personal project)?

### Partial

Analyze existing documentation and present a migration map:

- What existing content maps to L1 (orientation)?
- What maps to L2 (rules)?
- What maps to L3 (skills)?
- What's missing from each tier?

Ask the user to confirm the mapping and fill gaps.

### Existing

The project already has a three-tier system. Offer to **audit** instead:

- Check rules for staleness or redundancy
- Check skills for outdated patterns
- Check `MEMORY.md` for staging entries ready to promote
- Suggest additions based on the project scan

Ask the user if they want the audit or want to reinitialize from scratch.

### Foreign AI Config

Analyze the foreign config files (.cursorrules, copilot-instructions.md, etc.):

- Extract rules and patterns that are still relevant
- Map them to the three-tier structure
- Present the migration plan

**Important:** Never delete the original foreign config files. Offer to migrate knowledge but leave originals intact.

### Staging Area Analysis

If the project's `MEMORY.md` has existing content:

- Read its contents
- Identify entries that should be promoted to rules (validated patterns, gotchas)
- Identify entries that should become skills (detailed patterns with examples)
- Identify entries that should stay as staging (unvalidated, session-specific)
- Include promotion recommendations in the gap analysis

### Monorepo Handling

If the scan detected a monorepo:

- Ask which packages/apps to cover
- Plan path-scoped rules per package (e.g., `paths: ["packages/api/**"]`)
- Consider shared rules file for cross-cutting concerns

---

## Phase 3: Stack Research

Research the project's tech stack for Claude-relevant gotchas.

Launch parallel research subagents (one per major technology), using WebSearch and WebFetch. Each agent should find:

- Common mistakes Claude would make with this technology
- Framework-specific patterns that differ from the "obvious" approach
- Configuration gotchas that are hard to debug

### Filter criteria

Only keep findings that pass this test: **"Would Claude plausibly make this mistake without the rule?"**

Skip:

- Well-known language features (e.g., "JavaScript has hoisting")
- Generic best practices (e.g., "write tests")
- Patterns the project doesn't use

### Output

A categorized list of potential rules and skill topics, grouped by technology.

---

## Phase 4: Plan Presentation

Present the complete plan to the user for approval.

### Format

**L1 — Orientation ({chosen_file})**
Show the proposed outline with section headers and brief descriptions of what each section covers.

**L2 — Rules**
Group proposed rules by file with path scoping shown:

```
.claude/rules/frontend.md (paths: ["frontend/**", "src/**"])
- Use bun, not npm
- Prefer server components; "use client" only when needed
- ...

.claude/rules/backend.md (paths: ["backend/**", "api/**"])
- ...
```

**L3 — Skills**
List each proposed skill with name, description (<200 chars), and a one-line summary of what it would contain:

```
chakra-ui-v3 — "Chakra UI v3 component patterns..."
  → Key patterns, portal rules, anti-patterns with code examples
```

### Approval

Use AskUserQuestion with these options:

- **Proceed with full plan** — Create all three tiers as shown
- **Start smaller (L1 + L2 only)** — Skip skills for now, add them organically as patterns emerge
- **Modify plan** — Let user specify what to change

---

## Phase 5: Implementation

Execute the approved plan.

### Step 1: Create directory structure

```
.claude/rules/       (if not exists)
.claude/skills/      (if not exists, and L3 approved)
```

### Step 2: Write L2 rules files

Create each rules file with proper frontmatter:

```markdown
---
paths: ["relevant/path/**"]
---

# Section Header

- One-line rule here
- Another one-line rule
```

**Rules writing guide:**

- One line per rule, no exceptions
- Start with a verb ("Use", "Never", "Prefer") or subject ("Server Components", "Query keys")
- No code blocks — if it needs a code example, it belongs in a skill
- No rationale — if it needs explanation, add it to the matching skill's Anti-Patterns section
- Group related rules under `##` headers

### Step 3: Write L3 skills (if approved)

Create each skill directory with SKILL.md:

```markdown
---
name: skill-name
description: "Under 200 chars describing when to use this skill"
---

# Skill Title

Brief intro paragraph.

## Key Patterns

Code examples showing the correct way to do things in this project.

## Anti-Patterns

Story format for each:

- **What went wrong:** Description of the mistake
- **Why:** Root cause explanation
- **Fix:** The correct approach with code

## Decision Aids

Tables or flowcharts for common decisions (when applicable).
```

**Skills writing guide:**

- Description must be under 200 characters
- Key Patterns section should include real code examples from the project where possible
- Anti-Patterns use story format: what went wrong → why → fix
- Decision Aids are optional — only include when there are genuine multi-path decisions
- Cross-reference the relevant rules file so the skill and rules stay linked

### Step 4: Add Knowledge System section to L1

Read the template from this skill's references directory:
`${CLAUDE_SKILL_DIR}/references/knowledge-system-template.md`

Insert it into the project's L1 file (AGENTS.md or CLAUDE.md), replacing `{L1_FILE}` with the actual filename. Place it after the main project content but before any MCP/tools section if one exists.

If the L1 file doesn't exist yet, create it with the full project overview content followed by the Knowledge System section.

### Step 5: Staging area

Ensure the project's `MEMORY.md` (at `.claude/projects/<project-hash>/MEMORY.md`) is set up as the staging area for unvalidated learnings. Do NOT create a separate `.claude/staging.md` file.

Read the staging area template from this skill's references directory:
`${CLAUDE_SKILL_DIR}/references/memory-staging-template.md`

If `MEMORY.md` already has content, append the staging section structure. If it is empty or does not exist yet, write it fresh using the template content.

### Step 6: Critical patterns file

Create `.claude/rules/critical-patterns.md` for high-impact WRONG/CORRECT patterns. Read the template from this skill's references directory:
`${CLAUDE_SKILL_DIR}/references/critical-patterns-template.md`

Write the template content to `.claude/rules/critical-patterns.md`. This file starts with HTML comments documenting the format — actual entries are added as mistakes are discovered during work.

### Step 7: Summary

Present what was created:

- Number of rules files and total rules count
- Number of skills created (if any)
- L1 file location and sections
- Staging area status (`MEMORY.md`)
- Critical patterns file (`.claude/rules/critical-patterns.md`)
- Any migration notes (foreign config preserved, existing MEMORY.md content retained)

Suggest the user review each file and adjust as needed — the system is designed to evolve through use.
