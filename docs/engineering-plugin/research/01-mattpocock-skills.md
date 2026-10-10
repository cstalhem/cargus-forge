---
title: "Research: mattpocock/skills"
date: 2026-10-10
source: research subagent report, unedited
---

> Research subagent report from 2026-10-10, saved unedited. Paths under `/tmp/claude-1000/...` point to an ephemeral scratchpad and no longer exist.

# Research report: mattpocock/skills

I cloned it read-only to `/tmp/claude-1000/-home-calle-projects-cargus-forge/ea3ae446-4d33-5368-8304-92a9a4c30e4d/scratchpad/research/mattpocock`. Nothing was executed. The plugin is at v1.3.1 and ships 27 promoted skills.

## 1. Packaging and install

- **Layout.** Skills sit in buckets under `skills/`:
  - `engineering/` and `productivity/` are "promoted" and shipped.
  - `misc/` is frozen.
  - `in-progress/` is public beta and not shipped.
  - `deprecated/`.
- **Plugin manifest.** `.claude-plugin/plugin.json` uses an explicit `skills` array of 27 directory paths, which is how only the promoted set ships. `marketplace.json` is a single-plugin marketplace with `"source": "./"`.
  - Claude Code installs from the official marketplace: `claude plugin install mattpocock-skills@claude-plugins-official`.
  - Codex and Copilot install from the repo's own marketplace.
  - Other agents use `npx skills add` (skills.sh), which gives an editable copy.
  - ADR 0002 records the reasoning: Codex used to accept only a single skills path and drops symlinks.
- **Per-skill files.** Every skill also has an `agents/openai.yaml` (3–5 lines) for Codex UI metadata and the invocation policy.
- **Invocation split, the core architectural idea** (`.agents/invocation.md`):
  - **User-invoked** skills use `disable-model-invocation: true`. Their description is a human one-liner, they cost no context, and they are orchestrators.
  - **Model-invoked** skills have rich trigger descriptions and hold the reusable discipline.
  - Rule: *"A user-invoked skill may invoke model-invoked skills, but never another user-invoked one."*
  - Dependencies are written as *"Call the Skill tool with "grilling""*, not as `../other/FILE.md` links or bare `/name` mentions.
- **Repo governance.**
  - The repo has its own `CLAUDE.md`, `GLOSSARY.md`, ADRs, `SCOPE.md`, and an `.out-of-scope/` folder of rejected ideas.
  - Every promoted skill gets a human docs page (`docs/<bucket>/<skill>.md`) with the sections "What it does / When to reach for it / Common questions / It's working if".
  - The "Common questions" sections are an unusually honest record of known failure modes. I used them heavily below.
- **Philosophy** (README): *"Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process… they take away your control… These skills are designed to be small, easy to adapt, and composable."*

## 2. The main flow and handoffs

The `ask-matt` router (97 lines, plus `PHASE-BOUNDARIES.md` at 55) maps the flow:

```
grill-with-docs → [prototype via /handoff detour] → (multi-session?) to-spec → to-tickets → implement (per ticket, /clear between) | implement-spec (parallel) → tdd + code-review → retro
```

- **On-ramps:** `triage` (incoming issues), `diagnosing-bugs`, and `wayfinder` (work too big for one session, which then feeds into `to-spec`).
- **Upkeep:** `improve-codebase-architecture` produces ideas that go into `grill-with-docs`.
- **Vocabulary layers underneath:** `domain-modeling` and `codebase-design`.
- **Context hygiene rule:** *"Keep steps 1–3 in one unbroken context window (don't compact or clear until after `/to-tickets`)."* Each `/implement` then starts fresh from a ticket.
- **Phase-boundary decision tree** (applied only *at* boundaries): Continue → `/clear` → `/handoff` (only for a new harness, directory, colleague, or a side-fork) → subagent → `/compact` as the default of last resort.

## 3. Skill by skill (line counts are approximate)

### grilling (30 lines, model-invoked), grill-me (7), grill-with-docs (7)

- **The wrappers.** `grill-me` is literally one line: "Call the Skill tool with "grilling"." `grill-with-docs` is "Call the Skill tool twice, for "grilling" and "domain-modeling"."
- **Process in `grilling`:**
  - Model the plan as a **design tree**.
  - Work it in **rounds**. Each round asks the whole **frontier** at once: every decision whose prerequisites are already settled.
  - Questions are numbered, and each comes with a recommended answer, in the format `❓ **Q1** - **title**: body` / `➡️ recommendation`.
  - *"Word each question so "yes" accepts your recommended answer."*
  - A question that depends on another question in the same round waits for a later round.
  - *"Finding facts is your job, never the user's… dispatch a sub-agent to find it… Don't block on it."* *"The decisions are the user's."*
  - Exit criterion: *"done when the frontier is empty… Do not act on it until the user confirms you have reached a shared understanding."*
- **Artifacts.** `grilling` writes nothing itself. `grill-with-docs` writes `GLOSSARY.md` and ADRs through `domain-modeling`.
- **Deliberate refusals** (in `.out-of-scope/`):
  - No cap on the number of questions (someone reported "Codex just asked me 200 questions").
  - No harness question tool. *"Structured pickers push the model towards multiple-choice questions… I've tried the AskUserQuestion UI and don't want it in these skills."*

### domain-modeling (74 lines, plus GLOSSARY-FORMAT 60 and ADR-FORMAT 47)

- **Purpose.** The *active* discipline: challenging terms, sharpening fuzzy language, inventing edge-case scenarios, and cross-checking claims against the code. Passive reading of the glossary is explicitly *not* this skill.
- **Writes:**
  - `GLOSSARY.md` at the repo root, **inline, the moment a term resolves** (*"Don't batch these up"*).
  - In multi-context repos, a root `GLOSSARY-MAP.md` pointing at per-context `src/<ctx>/GLOSSARY.md` files.
  - ADRs in `docs/adr/NNNN-slug.md`.
  - Everything is created lazily.
- **Glossary rules:** be opinionated; each term carries an `_Avoid_:` synonym list; definitions are 1–2 sentences; project-specific terms only; *"totally devoid of implementation details… a glossary and nothing else."*
- **ADR gate.** An ADR is offered only when all three hold: **hard to reverse, surprising without context, the result of a real trade-off.** The template is minimal: *"An ADR can be a single paragraph."*
- **Rename history.** The file was called `CONTEXT.md` until a recent rename to `GLOSSARY.md`.

### setup-matt-pocock-skills (118 lines, plus seed templates: github 46, gitlab 46, local 30, triage-labels 15, domain 51)

1. **Explore:** git remote, `CLAUDE.md`/`AGENTS.md`, glossary and ADR files, `docs/agents/`, `.scratch/`, whether `triage` is installed, monorepo signals.
2. **Present findings, then ask one section at a time,** leading each with the recommended answer:
   - A: issue tracker (GitHub, GitLab, local, or "other", described in free prose).
   - B: triage labels, asked only if `triage` is installed, as a single yes/no.
   - C: domain layout. Single-context is written without asking; multi-context is offered only when monorepo signals exist.
3. **Show drafts** so the user can edit them.
4. **Write:**
   - An `## Agent skills` block in whichever of `CLAUDE.md`/`AGENTS.md` already exists, updated in place if present. If neither exists, it asks.
   - `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and `docs/agents/triage-labels.md`.
   - Labels are created with `gh`/`glab`.
- **Key technique: an indirection layer.** Skills say "publish to the issue tracker" or "fetch the relevant ticket", and the tracker doc defines what that means for that repo (including "Wayfinding operations": map, child, blocking, frontier query, claim, resolve).
- ADR 0001 splits dependents into **hard-dependency** skills (`to-spec`, `to-tickets`, `triage`), which say "run `/setup-matt-pocock-skills` if not provided", and **soft** ones, which degrade silently.
- `domain.md` tells consumers: *"If any of these files don't exist, proceed silently."*
- It does **not** collect stack, commands, test runner, or conventions. It is purely about tracker, labels, and doc layout.

### tdd (38 lines, plus tests.md 77 and mocking.md 59)

- **Process:**
  - Red→green only. *"Refactoring is not part of the loop"*: it belongs in code-review.
  - **Test only at pre-agreed seams.** *"Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam."* Each proposed seam gets a one-line note on what it catches and what it misses.
  - Vertical slices, with each test a "tracer bullet".
- **Named anti-patterns:** implementation-coupled, tautological (`expect(add(a,b)).toBe(a+b)`), horizontal slicing.
- Mock only at system boundaries.
- Calls `codebase-design` when the shape of the interface is itself in question.
- Reads `GLOSSARY.md` for test names. Writes only code.

### to-spec (75 lines)

- **Description:** *"Turn the current conversation into a spec… no interview, just synthesis."*
- **Process:**
  1. Explore the repo, using the glossary vocabulary and respecting ADRs.
  2. Sketch the test **seams** (*"prefer existing… highest seam possible… the ideal number is one"*) and check them with the user. This is the one interactive gate.
  3. Write from the template, publish to the tracker, and label it `ready-for-agent`.
- **Template sections:** Problem Statement, Solution, User Stories (*"A LONG, numbered list… extremely extensive"*), Implementation Decisions (modules and interfaces, no file paths or code, except decision-dense snippets from a prototype), Testing Decisions, Out of Scope, Further Notes.
- **Docs-page framing:** *"The spec is a decision record… If the spec states something you never said, that is a defect."*
- **Admitted gaps:**
  - The `ready-for-agent` label on the spec makes AFK pollers try to build the whole spec at once (the most-reported problem).
  - Nothing keeps the spec in sync; it is "disposable after the work ships", and lasting knowledge belongs in the glossary and ADRs.
  - The user-story template fits refactors poorly.
  - It does not search the tracker for duplicates or cite the ADRs it respects.
  - A large spec gets truncated when re-fetched from the tracker, and there is no local copy.

### to-tickets (105 lines)

- **Input:** the conversation, or a spec or issue reference (fetches body and comments).
- **Process:**
  1. Gather context.
  2. Explore (optional), including **prefactoring**: *"Make the change easy, then make the easy change."*
  3. Draft **tracer-bullet vertical slices**: each cuts through every layer, is demoable on its own, *"sized to fit in a single fresh context window"*, with prefactoring first.
  4. Every ticket gets **blocking edges**.
  5. Wide refactors are the exception and use **expand–contract** (expand, migrate in batches sized by blast radius, contract, optionally a final integrate-and-verify ticket).
  6. **Quiz the user** with a numbered list of title, blocked-by, and what it delivers. Ask about granularity, edges, merge or split, and *"Iterate until the user approves."*
  7. **Publish in dependency order** (blockers first, so real IDs exist):
     - Local: `.scratch/<feature>/issues/NN-slug.md`, one file per ticket, with `Status: ready-for-agent` and checkbox acceptance criteria.
     - Real tracker: native blocking links and sub-issues of the source issue, labelled `ready-for-agent`.
     - *"Do NOT close or modify any parent issue."*
- **Admitted gaps** (docs page):
  - Over-decomposition ("twelve tickets for a three-line change").
  - It still sometimes slices by layer. The docs suggest a "what can I demo?" check.
  - Acceptance criteria that "graded nothing": some were already true at the base commit.
  - *"The skill stops at the artifact, and there is no auto-dispatch mode."*
  - *"implement does not reliably close or check off the ticket when it finishes… you update the ticket's state yourself."*

### implement (17 lines) and implement-spec (40 lines)

- **implement:** fetch the ticket and state its title; drive `tdd` "at pre-agreed seams"; typecheck and run single test files regularly, the full suite once at the end; run `code-review`; commit to the current branch. There is no step that closes the ticket.
- **implement-spec:**
  - Treats tickets as a **task graph** with a ready **frontier**.
  - An optional exploration subagent saves notes *outside the repo* for later subagents.
  - Creates an integration branch.
  - One implementer subagent per ticket, each in its own worktree, each using `tdd`, merging the integration tip in before reporting done.
  - A merger subagent merges finished work; newly unblocked tickets get new implementers.
  - A final `code-review`, with one fixer subagent.
  - Then mark the draft PR ready, or close the tickets, and clean up worktrees.
  - *"Communicate primarily through context pointers."*

### improve-codebase-architecture (71 lines, plus HTML-REPORT.md 123)

- **Uses:** `codebase-design` vocabulary (module, interface, depth, seam, adapter, leverage, locality), with the rule *"don't drift into 'component,' 'service,' 'API,' or 'boundary'"*.
- **Process:**
  1. Scope first (YAGNI): take the user's direction, or mine `git log` for hot spots. Read the glossary and ADRs.
  2. A subagent explores "organically", noting friction, and applies the **deletion test**.
  3. Write a self-contained HTML report (Tailwind and Mermaid from CDN) to `$TMPDIR/architecture-review-<ts>.html` and open it. Each candidate card has Files, Problem, Solution, Benefits, a before/after diagram, and a Strong / Worth exploring / Speculative badge, ending with a Top recommendation. ADR conflicts are surfaced only when the friction is real.
  4. *"Do NOT propose interfaces yet"*: ask which one to explore.
  5. Grill it (`grilling` + `domain-modeling`). If the user rejects a candidate for a lasting reason, offer an ADR *"so future architecture reviews don't re-suggest it."* Optionally run Design-It-Twice.
- **codebase-design** (114 lines, plus DEEPENING 37 and DESIGN-IT-TWICE 44):
  - Dependency categories: in-process, local-substitutable, remote-owned (ports and adapters), true external.
  - *"One adapter means a hypothetical seam. Two adapters means a real one."*
  - "Replace, don't layer" tests.
  - Design-It-Twice: 3 or more parallel subagents with opposing constraints (minimal, flexible, common-caller, ports), then an opinionated comparison.

### Other promoted skills (briefly)

- **wayfinder (128):** for efforts bigger than one session.
  - A `wayfinder:map` issue holds Destination, Notes, Decisions so far (an index of one-line gists plus links), *Not yet specified* (the "fog of war"), and Out of scope.
  - Child **decision tickets** are typed research, prototype, grilling, or task, with native blocking.
  - A session claims a ticket by assigning it. *"Never resolve more than one ticket per session"* (research excepted).
  - Two modes: chart the map, or work through it.
  - *"Plan, don't do."*
  - This is the repo's only genuinely cross-session state mechanism for planning.
- **triage (112, plus AGENT-BRIEF 207 and OUT-OF-SCOPE 105):**
  - A label state machine.
  - Checks redundancy and prior rejection, verifies the claim, grills, then writes durable agent briefs: behavioural, no file paths, testable acceptance criteria, explicit scope.
  - Resumes from prior triage notes left on the issue.
- **code-review (89):** two parallel subagents, Standards (repo docs plus a baseline of 12 Fowler smells) and Spec (finds the spec via commit refs, then a path, then `.scratch`/`docs`). Reports are not merged or reranked.
- **diagnosing-bugs (138):** six gated phases. Phase 1 must produce a **tight, red-capable** command that has already run. Then 3–5 falsifiable hypotheses, `[DEBUG-xxxx]`-tagged logs, a regression test only at a correct seam (*"If no correct seam exists, that itself is the finding"*).
- **retro (44):** suggests environment improvements (navigation, checks, standards, tool economy, no-ops). Mechanical rules become linters; judgement calls go to `CODING_STANDARDS.md`.
- **prototype (26, plus LOGIC 67 and UI 112):** throwaway; kept on a `prototype/<name>` branch as a primary source.
- **research (12):** a background agent writes a cited markdown file into the repo.
- **pr (170), wizard (44, plus template.sh 223).**
- **handoff (16):** writes to `$TMPDIR` with a "suggested skills" section and references other artifacts instead of duplicating them.
- **teach (140, plus four format files):** a stateful workspace with `MISSION.md`, `learning-records/NNNN`, lessons, `NOTES.md`.
- **to-questionnaire (54):** *"Grill the send, not the subject."*
- **wait-what (7).**
- **writing-for-agents (81, plus SKILL-MECHANICS 22).**

## 4. Prompting techniques worth stealing

1. **Leading words** (from writing-for-agents): compact pretrained concepts repeated as tokens, such as *tracer bullet, frontier, fog of war, tight / red loop, seam, deep module*. *"Prompt the positive"*, because negation primes the forbidden behaviour.
2. **Completion criteria** on every step, judged on clarity and how much they demand. diagnosing-bugs and wizard use explicit "Done when" checklists.
3. **Facts versus decisions.** The agent looks up facts (through subagents, without blocking); the user owns decisions. Questions are batched by frontier and come with a recommended answer that "yes" accepts.
4. **Progressive disclosure.** SKILL.md files are short, with reference split into sibling files. Shared reference lives in a model-invoked skill and is reached by calling the Skill tool, never by cross-folder links.
5. **Context pointers instead of duplication**, in handoff, implement-spec, and the wayfinder map as "an index, not a store".
6. **A tracker abstraction.** Generic verbs ("publish to the issue tracker") are resolved through a per-repo `docs/agents/issue-tracker.md`.
7. **Subagents used for isolation**, not just parallelism: code-review's two axes, Design-It-Twice, research, implement-spec workers.
8. **Durable docs exclude file paths and line numbers**, which go stale. Behaviour and interfaces are described instead.

## 5. Critical assessment

### Strengths

- Very small, composable orchestrators over a few shared primitives (`grilling`, `domain-modeling`, `codebase-design`, `tdd`). The total promoted-skill body is about 1,900 lines.
- The user-invoked versus model-invoked split is principled and keeps context load low. Only the model-invoked descriptions, about 4.3 KB (~1.1k tokens) in total, are always loaded; the 17 user-invoked skills cost nothing until typed.
- Strong engineering content: seams agreed up front and threaded through to-spec, tdd, and code-review; vertical slicing with an expand–contract exception; feedback-loop-first debugging; a strict ADR gate.
- The knowledge that lasts goes into `GLOSSARY.md` and ADRs, written inline during conversation. That is a low-friction way to accumulate domain knowledge.
- Unusually candid docs listing known failure modes, plus an `.out-of-scope/` log of rejected ideas.

### Weaknesses and gaps in the to-spec / to-tickets process

- **Inputs are loose.** Both depend on "the current conversation". `to-spec` explicitly refuses to interview, so the spec is only as good as the earlier grilling. Nothing checks that grilling actually happened or reached an empty frontier.
- **Outputs are clear (templates), but exit criteria are weak:**
  - `to-spec` has no completeness check beyond confirming seams.
  - `to-tickets`' only gate is user approval of the breakdown. Acceptance criteria are not required to be falsifiable; the docs admit some pass at the base commit.
  - There is no "definition of ready" per ticket and no check that a ticket really fits one context window.
- **Handoff to execution is the weakest link:**
  - No dispatch; the user opens sessions by hand.
  - `implement` has no step to close the ticket or tick its checkboxes; the docs say the user must update state.
  - No step re-checks acceptance criteria before commit; code-review's Spec axis partly covers this.
  - The `ready-for-agent` label on the parent spec misleads AFK pollers.
- **State between sessions:**
  - Lasting state is the glossary, ADRs, and tracker issues (or `.scratch/` files). No progress log, no session journal, no "where we are" file.
  - The spec is a snapshot with no sync. If implementation teaches something, the spec goes stale by design.
  - Grilling state lives only in the context window. That is why the router insists on a single unbroken window from grill through to-tickets, and why a large spec that has to be re-fetched gets truncated.
  - `handoff` writes to `$TMPDIR`, so it is ephemeral and outside the repo.
  - Only `wayfinder` (map plus decision tickets with claim/resolve) and `teach` (learning records) carry structured state across sessions.
- **Context cost:**
  - The heaviest single loads are pr (170), diagnosing-bugs (138), teach (140), wayfinder (128), plus AGENT-BRIEF (207) when triage pulls it in.
  - The main flow is cheap. grill-with-docs loads grilling (30) and domain-modeling (74, plus formats when writing, about 107). to-spec is 75 and to-tickets 105. implement (17) pulls in tdd (38, plus 136 of references) and code-review (89, and its baseline is pasted into the subagent).
  - The real cost is the convention of keeping grilling, spec, and tickets in one window, which pushes toward the "smart zone" limit of about 150k tokens.
- **Other gaps:**
  - The setup skill captures nothing about build, test, or lint commands or repo conventions; retro and code-review rediscover them every time.
  - User stories in the spec template fit refactors poorly.
  - No duplicate search against the tracker.
  - Over-decomposition, and horizontal slicing still occurs.
  - No guards against subagent recursion; this is deliberately left to the harness.
  - Grilling has no question cap or structured question UI, by design. That is good for depth but can produce very long sessions.

### Relevance to cargus-forge

- The design overlaps conceptually with this repo's `adr-management` and `knowledge-system` plugins: inline glossary and ADR capture, and a strict ADR gate.
- Ideas most worth borrowing:
  - The frontier-batched grilling primitive.
  - The user-invoked versus model-invoked composition rule.
  - The tracker-indirection doc.
  - Seams agreed up front and threaded across spec, tdd, and review.
- Places to improve on it:
  - Explicit exit criteria and ticket closure in implement.
  - Persisted spec and ticket state locally.
  - A setup step that also records the repo's commands.

## 6. Line counts (SKILL.md + supporting files)

| Skill | SKILL.md | Supporting files |
| --- | --- | --- |
| ask-matt | 97 | PHASE-BOUNDARIES 55 |
| codebase-design | 114 | DEEPENING 37, DESIGN-IT-TWICE 44 |
| code-review | 89 | |
| diagnosing-bugs | 138 | hitl-loop.template.sh 44 |
| domain-modeling | 74 | ADR-FORMAT 47, GLOSSARY-FORMAT 60 |
| grill-with-docs | 7 | |
| implement | 17 | |
| implement-spec | 40 | |
| improve-codebase-architecture | 71 | HTML-REPORT 123 |
| pr | 170 | |
| prototype | 26 | LOGIC 67, UI 112 |
| research | 12 | |
| retro | 44 | |
| setup-matt-pocock-skills | 118 | domain 51, github 46, gitlab 46, local 30, labels 15 |
| tdd | 38 | tests 77, mocking 59 |
| to-spec | 75 | |
| to-tickets | 105 | |
| triage | 112 | AGENT-BRIEF 207, OUT-OF-SCOPE 105 |
| wayfinder | 128 | |
| wizard | 44 | template.sh 223 |
| grill-me | 7 | |
| grilling | 30 | |
| handoff | 16 | |
| teach | 140 | four format files, 144 total |
| to-questionnaire | 54 | |
| wait-what | 7 | |
| writing-for-agents | 81 | SKILL-MECHANICS 22 |

Repo docs: README 258, docs pages roughly 36–113 each.
