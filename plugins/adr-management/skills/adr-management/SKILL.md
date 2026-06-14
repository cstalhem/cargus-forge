---
name: adr-management
description: >
  This skill should be used when the user asks to "create an ADR",
  "add an architecture decision", "update an ADR", "amend an ADR",
  "supersede an ADR", "write an architecture decision record",
  or when working on architecture decisions for a project.
  Also activate when evaluating whether something warrants an ADR
  or belongs in a design document instead.
---

# ADR Management

Guide for creating and maintaining Architecture Decision Records (ADRs).
ADRs are stored as one file per decision under a decisions directory, with a
`README.md` index in that directory. Companion design documents live alongside
in a separate designs directory.

## Conventions

The project's existing files are the source of truth for where ADRs live and how
they look — there is no separate config to maintain. Resolve the convention with
one cheap check, taking the first branch that applies:

- **Fast path — ADRs already exist.** Glob the likely locations
  (`docs/adr/`, `docs/decisions/`, `docs/architecture/decisions/`, `adr/`). If
  any contain ADRs, that directory *is* the convention: match its filename
  pattern and frontmatter, and you're done. This is the common case, and it
  cannot go stale — it reads the truth directly. (When creating a new ADR, Step 1
  of *Creating a New ADR* runs this same glob to find the next number, so the
  check is already paid for.)
- **Slow path — no ADRs yet.** Only when none exist, establish the convention:
  default to `docs/adr/`, filenames `ADR-NNN-<kebab-title>.md`, and the
  frontmatter shown below, and create `docs/adr/README.md` as the index. This
  one-time decision is self-recording — the first ADR you write becomes what the
  fast path matches on every run thereafter.

Two related conventions:

- **Companion design documents** live in `docs/designs/` (or the project's
  existing equivalent).
- **Glossary alignment.** If the project maintains a canonical-terms document
  (e.g. `GLOSSARY.md`, `CONTEXT.md`, or an `AGENTS.md`/`CLAUDE.md` glossary
  section), ADRs use its terms; when an ADR settles or changes a term, update
  the glossary in the same edit.

The rest of this guide uses `docs/adr/` and `docs/designs/` as placeholders —
substitute the project's actual paths.

## When to Activate

- Creating a new architecture decision.
- Evaluating whether a decision warrants an ADR or a design document.
- Updating an existing ADR because a decision was refined, extended, or reversed.
- Reviewing ADR quality or structure.

## Core Principles

1. **One ADR = one decision area.** Each ADR owns one question the architecture
   answers ("how are events stored?", "what is the sharing boundary?"). The
   decision must have rejected alternatives. If there are no meaningful
   alternatives, it belongs in a design document, not an ADR.
2. **ADRs are living documents.** The body always states the **current**
   decision. When a decision is refined or changed, edit the ADR in place; when
   an earlier choice is abandoned, move it into Rejected alternatives with the
   reason it was dropped. Git history is the changelog — never keep
   "amended by" annotations, change markers, or discussion artifacts in the text.
   (See `references/best-practices.md` for when this living-document model fits
   and when the classical immutable model is the better choice.)
3. **ADRs read as current fact statements.** No conversational or historical
   narration ("we decided", "as per the discussion", "this refines what ADR-N
   said"). Rationale for the current choice is stated inline as fact; the story
   of how the text evolved is not recorded at all.
4. **ADRs are not design guides.** Keep them assertive, factual, and readable in
   ~5 minutes. Link to `docs/designs/` for walkthroughs, edge cases, and
   detailed reasoning.
5. **ADRs speak the glossary's language.** Use the project's canonical terms;
   when an ADR settles or changes a term, update the glossary in the same edit.

## The Litmus Test

Before creating an ADR, verify the decision passes all four checks:

1. **Clear decision** — Can it be stated in one assertive sentence?
2. **Real trade-off** — Was at least one genuine alternative considered and
   discarded, with rationale?
3. **Hard to reverse** — Is the cost of changing the choice later meaningful?
4. **Surprising without context** — Would a future reader look at the result
   and wonder "why was it done this way?"

If any check fails, the content likely belongs in a design document instead.
(If a decision is easy to reverse, you'll just reverse it; if it isn't
surprising, nobody will wonder why; if there was no real alternative, there is
nothing to record beyond "the obvious thing was done.")

## Edit or New ADR?

The decisive question: **does the change answer the same question an existing
ADR answers?**

| Scenario                                                    | Action                                                                                  |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| New info, refinement, or extension of an existing decision  | Edit the ADR in place so it states the current decision                                 |
| Decision reversed or replaced                               | Rewrite the ADR; move the old approach to Rejected alternatives with why it was dropped |
| New question with its own alternatives (passes litmus test) | New ADR; if it narrows what an existing ADR says, edit that ADR too                     |
| Decision area no longer relevant                            | Set `status: deprecated`; keep the file with one line saying why                        |

A reversal is not lost history: the abandoned approach becomes the strongest
kind of rejected alternative — one with empirical evidence ("initially built
this way; replaced because …"). State it factually, in the Rejected
alternatives section, not as narration in the decision text.

Numbers are never reused. A deprecated ADR keeps its file so references from
code, migrations, and other docs don't break.

This applies during design and planning sessions too: when a discussion settles
a decision, edit the owning ADR right then — not as a batched cleanup
afterwards.

## Creating a New ADR

### Step 1: Determine the next ADR number

Run `ls docs/adr/ADR-*.md | tail -1` to find the highest existing number;
increment by one.

### Step 2: Write the ADR

Create `docs/adr/ADR-NNN-<kebab-title>.md` using the per-file template below.
Slug rules: lowercase ASCII, ≤ ~40 chars, frozen at commit time (the path
becomes git history; only the title text inside the file may be clarified later).

```markdown
---
adr: NNN
title: Title (matches the H1 below)
status: active                  # active | deprecated
---

# ADR-NNN: Title

- **Decision:** One-sentence summary of what was decided.
- **Builds on:** [ADR-XXX](ADR-XXX-slug.md) (optional, when this decision rests on another)
- **Design notes:** See `../designs/feature-name.md` for detailed discussion.

### Subsections as needed
```

Then add a row to the table in `docs/adr/README.md`. The Notes column holds at
most a terse "builds on ADR-N" pointer.

### Step 3: Length check

Sections beyond the **Decision** bullet are optional. The floor is the
frontmatter, the Decision, and a one-line rejected alternative; add Context and
Consequences sections only when the decision's weight demands them. Disclosure
is proportional to decision weight — a simple choice is complete at a few lines.

| Category               | Target length |
|------------------------|---------------|
| Simple choice          | 4-15 lines    |
| Moderate architecture  | 20-45 lines   |
| Complex cross-cutting  | 60-100 lines  |

If exceeding ~100 lines, move detailed content to a companion design document
in `docs/designs/` and reference it from the ADR.

### Step 4: Keep related ADRs currently true

If the new decision narrows or changes what an existing ADR states, **edit that
ADR's body so it states the current truth**, linking to the new ADR where the
rationale lives. Never leave an existing ADR asserting something the new
decision has made false, and never patch it with an "amended by" annotation —
fix the text itself.

### Step 5: Update any open-questions log

If the project tracks open design questions (e.g. an `open-design-areas.md` or a
backlog of unresolved decisions) and the ADR addresses one, update that entry
with a reference: "Addressed by ADR-NNN" or "Partially addressed by ADR-NNN —
remaining questions: ..."

## Companion Design Documents

When an ADR needs supporting detail (walkthroughs, service mappings, edge case
analysis, implementation specifics), create a companion design document:

- Location: `docs/designs/feature-name.md`
- Reference from ADR: `- **Design notes:** See docs/designs/feature-name.md`
- Design documents are living documents — update them as implementation evolves.
- Design documents have no format constraints. Optimise for usefulness during
  implementation.

## ADR vs Design Document — Quick Reference

| Question                                          | ADR | Design Doc |
|---------------------------------------------------|-----|------------|
| "What did we decide and why?"                     | Yes | No         |
| "What alternatives were rejected?"                | Yes | No         |
| "How does the logging flow work end to end?"      | No  | Yes        |
| "What are the per-type `details` payload shapes?" | No  | Yes        |
| "Why managed service X over a custom build?"      | Yes | No         |
| "What edge cases exist in the onboarding flow?"   | No  | Yes        |

## Additional Resources

### Reference Files

For detailed best practices, industry sources, and the full rationale behind
these guidelines (including when the living-document model fits and when the
classical immutable-ADR model is the better choice):

- **`references/best-practices.md`** — ADR best practices compiled from AWS,
  Google Cloud, Microsoft Azure, Martin Fowler, and the ADR GitHub organisation,
  adapted to a living-document model. Includes the decision table for when to
  create/edit/deprecate and length guidelines.
