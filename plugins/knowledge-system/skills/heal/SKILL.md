---
name: heal-knowledge
description: "Fix incorrect or outdated rules and skills — critical issues get direct fixes, minor issues get staged"
model: sonnet
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Heal Knowledge System

Fix rules or skills that are wrong, outdated, or causing incorrect behavior. Can be triggered by the user (`/heal <description>`) or auto-detected during work.

## Detection heuristics

Flag a rule or skill for healing when:
- Tests fail after following a documented rule or skill pattern
- Linter or type checker errors result from applying a skill's code pattern
- User explicitly corrects behavior that a rule or skill recommended
- A rule contradicts observed project behavior

## Steps

### 1. Identify the issue

**If user-invoked:** Parse the `<description>` to identify which rule or skill is affected and what's wrong.

**If auto-detected:** Identify the specific rule or skill that led to incorrect behavior and describe the discrepancy.

### 2. Classify severity

**Critical** — the issue causes one of:
- Build or test failures
- Data loss or corruption
- Security vulnerabilities
- Silent failures that are hard to debug

**Minor** — the issue causes one of:
- Suboptimal but working code
- Edge cases not covered
- Style inconsistencies
- Outdated but non-breaking patterns

### 3a. Handle critical issues

1. Locate the incorrect rule or skill content
2. Propose a specific diff showing the fix
3. Use AskUserQuestion to present the diff and ask for approval
4. If approved, apply the fix directly to the rule or skill file
5. If the fix involves a high-impact pattern, also add a WRONG/CORRECT entry to `.claude/rules/critical-patterns.md`

### 3b. Handle minor issues

1. Stage the correction in `MEMORY.md` with these tags:
   - `[type:gotcha]`
   - `[area:<relevant-area>]`
   - `[promotion-candidate]`
2. Include in the staging entry:
   - Which rule or skill is affected
   - What's wrong and what the correct behavior should be
   - Context for when this was discovered
3. The promote skill will pick this up at end-of-session for proper resolution
