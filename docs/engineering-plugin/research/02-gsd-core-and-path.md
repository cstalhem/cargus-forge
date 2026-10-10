---
title: "Research: GSD core and GSD path"
date: 2026-10-10
source: research subagent report, unedited
---

> Research subagent report from 2026-10-10, saved unedited. Paths under `/tmp/claude-1000/...` point to an ephemeral scratchpad and no longer exist.

## GSD Core and GSD Path: research report

I cloned both repos (depth 1, read-only, no code run) into `/tmp/claude-1000/-home-calle-projects-cargus-forge/ea3ae446-4d33-5368-8304-92a9a4c30e4d/scratchpad/research/{gsd-core,gsd-path}`. I got repo stats from `gh api`.

---

## Part 1: gsd-core (open-gsd/gsd-core)

**Identity and maturity.**
- It is the renamed `get-shit-done-cc` (the original was by glittercowboy). The npm package is now `@opengsd/gsd-core` 1.16.0, released 2026-10-05.
- About **10,360 stars**, 744 forks, **~6,150 commits**, 100+ contributors and 218 open issues. Issue numbers go past #5,200.
- The top committer, trek-e, has 3,770 commits. It targets about 15 runtimes (Claude Code, Codex, Cursor, OpenCode, Copilot and others).
- Its tagline calls itself "light-weight". That claim is not credible (see the size section below).

### 1.1 Order of operations

The project lifecycle runs like this:

```
/gsd-new-project (greenfield)  |  /gsd-onboard (brownfield; optionally /gsd-map-codebase first)
  → per milestone, per phase:  Discuss → (UI design) → Plan → Execute → Verify → Ship
  → /gsd-complete-milestone → /gsd-new-milestone
```

The docs put it this way: *"Every unit of work — called a phase — moves through these steps in order… Each step exists because it guards against a specific class of failure that the previous step alone cannot prevent."*

**1. `/gsd-new-project`** (`workflows/new-project.md`, 1,243 lines)
- **Steps:** setup → offer brownfield mapping → deep questioning → write PROJECT.md → workflow preferences (writes config.json) → model profile → research decision → define requirements → create roadmap.
- **Agents:** 4 parallel `gsd-project-researcher`, then `gsd-research-synthesizer`, then `gsd-roadmapper`.
- **Outputs:** `PROJECT.md`, `REQUIREMENTS.md` (IDs like `AUTH-01`), `ROADMAP.md` (phases carrying goals, requirement IDs and success criteria), `STATE.md`, `config.json`, and `research/{STACK,FEATURES,ARCHITECTURE,PITFALLS,SUMMARY}.md`.
- **Exit:** a single commit, `docs: initialize [project] ([N] phases)`.

**2. `/gsd-map-codebase`** (brownfield)
- Spawns parallel `gsd-codebase-mapper` agents (haiku on the balanced profile).
- Writes `.planning/codebase/{STACK,INTEGRATIONS,ARCHITECTURE,STRUCTURE,CONVENTIONS,TESTING,CONCERNS}.md`, then scans them for secrets and commits.

**3. `/gsd-discuss-phase N`** (520-line spine plus 924 lines of modes and templates)
- **Inputs:** ROADMAP phase goal, prior CONTEXT files (or `DECISIONS-INDEX.md`), a codebase scout, and any blocking anti-patterns left in `.continue-here.md`.
- **Process:** it identifies "gray areas", prompted as *"identify 1-2 specific ambiguities that would change implementation"*, and asks the user about each.
- **Outputs:** `NN-CONTEXT.md`, which holds `<domain>`, locked decisions `D-NN`, `<canonical_refs>`, `<code_context>`, `<specifics>` and `<deferred>`. Also `NN-DISCUSSION-LOG.md`, a human-only audit file. Both are committed and STATE is updated.
- **Alternatives:**
  - `--prd` / `--ingest` (ADRs) skip discussion.
  - `/gsd-spec-phase` produces SPEC.md.
  - `discuss-phase-assumptions` uses `gsd-assumptions-analyzer`.

**4. `/gsd-ui-phase`** (optional): produces `UI-SPEC.md`, a design contract.

**5. `/gsd-plan-phase N`** (1,606-line spine plus 829 lines of steps and detail; 26 flags)
- **Sequence:**
  1. Gates (git branch invariant, closed-phase, drift).
  2. `gsd-phase-researcher` → `NN-RESEARCH.md`.
  3. VALIDATION.md ("Nyquist" test strategy).
  4. Security threat-model gate.
  5. Optional `gsd-pattern-mapper` → `NN-PATTERNS.md`.
  6. `gsd-planner` → `NN-PP-PLAN.md` (one per plan).
  7. `gsd-plan-checker`.
  8. **Revision loop, max 3 iterations.**
- **PLAN.md format:**
  - YAML frontmatter: `wave`, `depends_on`, `files_modified`, `autonomous`, `must_haves: {truths, artifacts, key_links}`.
  - XML tasks, each with `<read_first>`, `<action>`, `<verify>` and `<acceptance_criteria>`.
- **Plan checker:** about 15 "dimensions":
  - requirement coverage, task completeness, dependency correctness, undeclared/temporal coupling, key links, scope sanity, verification derivation
  - CONTEXT compliance, scope-reduction detection, architectural tier, Nyquist, cross-plan data contracts
  - CLAUDE.md compliance, research resolution, pattern compliance, verify-command path resolvability
- **Severity:** BLOCKER, WARNING or INFO. *"INFO alone never forces a revision."*
- **Exit:** the checker passes, or the user overrides after the cap.

**6. `/gsd-execute-phase N`** (1,382-line spine plus 2,704 lines of steps and detail)
- **Steps:** safe-resume gate → branching → group plans into waves → execute waves in parallel (default `max_concurrent_agents: 3`) → checkpoint handling → aggregate → **verify phase goal** (spawns `gsd-verifier`) → update roadmap → copy learnings → close todos → transition.
- **Each `gsd-executor`** gets one PLAN.md, commits once per task, and writes `NN-PP-SUMMARY.md`. The summary records deviations, a self-check and `actuals` (tokens, tasks, commits) used to calibrate estimates.
- **Executor deviation rules** (worth stealing):
  - *"RULE 1: Auto-fix bugs / RULE 2: Auto-add missing critical functionality / RULE 3: Auto-fix blocking issues / RULE 4: Ask about architectural changes"*
  - plus *"When in doubt: Does this affect correctness, security, or ability to complete task? YES → Rules 1-3. MAYBE → Rule 4."*
- Code review (`REVIEW.md`) runs at `execute:post` by default.

**7. `/gsd-verify-work`** (human UAT)
- *"User tests, Claude records. One test at a time… Show expected, ask if reality matches."*
- It writes `NN-UAT.md`, which survives `/clear`. Gaps are diagnosed, fix plans are produced through planner and checker, and those feed `/gsd-plan-phase --gaps`.

**8. `/gsd-ship`**
- Preflight → push branch → generate PR body → `gh pr create` → optional review → track shipping.

**9. `/gsd-complete-milestone`**
- Audit → stats → archive the milestone → reorganise the roadmap → retrospective → handle branches → git tag `vX.Y` (default `create_tag: true`).

**Side paths:**
- `/gsd-quick` is ad-hoc work: planner (quick mode) plus executor, stored in `.planning/quick/<id>-PLAN.md` and `-SUMMARY.md`, logged in a STATE "Quick Tasks Completed" table. Flags `--discuss`, `--research`, `--validate` and `--full` add back the gates.
- `/gsd-fast` is the inline trivial path.
- Other commands:
  - **Navigation and drivers:** `/gsd-next`, `/gsd-progress`, `/gsd-autonomous` (unattended loop), `/gsd-manager` (dashboard).
  - **Diagnostics:** `/gsd-debug` (persistent DEBUG sessions), `/gsd-forensics`, `/gsd-undo`, `/gsd-health`.
  - **Exploratory:** spike, sketch, thread, inbox, workstreams, workspace.
  - **Memory integrations:** mempalace, graphify.
- In total: **72 commands** and **64 agent files** (33 roles, most with a `.compact.md` twin).

### 1.2 State model (`.planning/`)

**Root files:** `PROJECT.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, `config.json`, and optionally `MILESTONES.md`, `BACKLOG.md`, `LEARNINGS.md`, `DECISIONS-INDEX.md`, `METHODOLOGY.md`, `HANDOFF.json`. Also the directories `codebase/` (7), `research/` (5), `onboarding/`, `intel/`, `quick/`, `async-jobs/`, `spikes/` and `debug/`.

**STATE.md:**
- YAML frontmatter: `status`, `active_phase`, `next_action`, `next_phases`, `progress.{total_phases, completed_phases, total_plans, completed_plans, percent}`, `current_phase`/`plan`, `stopped_at`, `paused_at`, and `state_head`. `state_head` is the git SHA the file was written against, used for a freshness check.
- Body sections: position, decisions, todos, blockers, session continuity, quick tasks.
- *"intentionally small (target: under 100 lines)… a digest… not an archive."*
- Rule: *"Read at the start of every workflow run. Updated after every significant action."*
- Writes go through a `gsd-tools` CJS CLI (`state.*`, `syncStateFrontmatter`) rather than free-form edits. That is good design.

**Progress is derived from files on disk.** A phase is complete when every PLAN has a matching SUMMARY. A `status: passed` VERIFICATION.md locks the phase against replanning.

**Per-phase file count** (`phases/NN-slug/`, default config: research, plan_check, verifier, nyquist, security and code_review all `true`):
- Fixed files (9): CONTEXT, DISCUSSION-LOG, RESEARCH, VALIDATION, PATTERNS, VERIFICATION, REVIEW, SECURITY, UAT.
- Per plan (2 each): PLAN and SUMMARY.
- **That is 9 + 2N files per phase**, so a typical 3-plan phase holds about **15 files**.
- Situational extras: UI-SPEC, UI-REVIEW, SPEC, AI-SPEC, REVIEWS, REVIEW-FIX, PLAN-OUTLINE, LEARNINGS, `.continue-here.md`.

**A 5-phase milestone with 3 plans per phase** totals about 17 root and map files plus 75 phase files, **≈90+ markdown artifacts**. All of it is committed by default (`commit_docs: true`) and archived at milestone close.

**Pause and resume:**
- `/gsd-pause-work` writes two files:
  - `HANDOFF.json`, machine state: phase, plan, task, completed and remaining tasks with commit hashes, blockers, human actions, decisions, `next_action`, `context_notes`, and `uncommitted_files`. The last is *"measured, never asserted… a narrated `[]` over a dirty tree is how 14 plans' worth of uncommitted code went invisible"*.
  - `.continue-here.md`, human-readable, with **blocking anti-patterns**. The next discuss or execute run must *"demonstrate understanding"* of these before it proceeds.
  - Both are committed.
- `/gsd-resume-work` reads STATE, PROJECT and HANDOFF, checks for incomplete work (a PLAN without a SUMMARY, async jobs), presents status and routes on. HANDOFF is *"consumed exactly once"*.
- `/gsd-progress` and `/gsd-next` handle routing without a pause.
- Executors resume safely at the plan level: plans that already have a SUMMARY are skipped.

### 1.3 Subagent orchestration and context strategy

**Core roles:** project-researcher ×4, research-synthesizer, roadmapper, codebase-mapper, assumptions-analyzer, phase-researcher, pattern-mapper, planner, plan-checker, executor, verifier, debugger, code-reviewer, code-fixer, integration-checker, nyquist-auditor, security-auditor, ui-researcher/checker/auditor, and doc-writer/verifier, among others.

**Model profiles** (`references/model-profiles.md`):

| Profile | Assignment |
|---|---|
| `balanced` (default) | opus for planner only; sonnet for executor, researchers, verifier and plan-checker; haiku for the codebase mapper |
| `quality` | opus everywhere it matters |
| `budget` | sonnet and haiku |
| `adaptive` | opus for planner and debugger; haiku for checkers and auditors |
| `inherit` | follows the session model |

These can be overridden per phase type (`models.planning`) or per agent (`model_overrides`).

**Lean-orchestrator rules** (`references/context-budget.md`):
- *"Never read agent definition files… `subagent_type` auto-loads them"*
- *"Never inline large files into subagent prompts — tell agents to read files from disk instead"*
- With a 200k window, read only the **frontmatter** of SUMMARY, VERIFICATION and RESEARCH.
- Context degradation tiers: PEAK 0–30%, GOOD, DEGRADING 50–70%, POOR 70%+. At POOR, execute-phase auto-pauses at a wave boundary.
- The rationale: *"The orchestrator — your main session — never touches source files. It spawns agents, collects their results, updates shared state, and routes."*
- A `gsd-context-monitor` hook runs on PostToolUse, SubagentStop, Stop and PreCompact and warns as context fills.
- Subagents are isolated, *"so anything the subagent needs must be on disk before it is spawned"*. `.planning/` is the shared substrate.

**Verifier design (the best idea in the repo):**
- *"SUMMARY.md claims are not evidence… Assume the phase goal was not achieved until codebase evidence proves it."*
- It checks the `must_haves` derived from the plan at three levels: **Exists → Substantive (not a stub) → Wired (imported and used)**, plus "data flows" (HOLLOW means wired but disconnected).
- Behaviour-dependent truths without a test become `PRESENT_BEHAVIOR_UNVERIFIED` and route to a human.
- The plan checker uses the same goal-backward method, but before execution.

### 1.4 Git, GitHub, verification and hooks

**Git:**
- *"Commit outcomes, not process."*
- One commit per task, `{type}({phase}-{plan}): {task}`, plus a metadata commit per plan (SUMMARY, STATE, ROADMAP).
- PLAN and RESEARCH files are not committed on their own.
- It does not use `--no-verify` by default.
- `git.branching_strategy`: `none` (default) | `phase` | `milestone`, with templates `gsd/phase-{phase}-{slug}` and `gsd/{milestone}-{slug}`.
- The executor refuses to commit on the default branch unless `allow_default_branch_commits` is set.
- Parallel executors can run in worktrees, with path guards.

**GitHub:**
- `/gsd-ship` uses `gh pr create`.
- There is **no native issue-tracker integration**. `docs/issue-driven-orchestration.md` is *"documentation only. No new commands, no daemon, no tracker integration"*. It maps Symphony-style issue → workspace → PR onto existing commands.

**Verification layers:** plan-checker (pre-execution) → executor self-check → `gsd-verifier` (goal-backward, writes VERIFICATION.md) → code review → security audit → `/gsd-verify-work` human UAT → gap-closure plans.

**Hooks:** 28 JS/shell hooks, about 11k lines.
- SessionStart: update check, canonical path.
- PreToolUse: prompt-injection guard, read-before-edit guard, worktree path guard, write guard, secret-read guard, agent-isolation guard.
- PostToolUse: context monitor, read-injection scanner.
- SubagentStop, Stop and PreCompact: context monitor.
- Also a statusline and a commit-message validator.

### 1.5 Prompt surface and context cost

| Area | Files | Lines | Bytes |
|---|---|---|---|
| commands/gsd | 72 | 4,116 | 182 KB |
| skills/ (mirror of commands) | 72 | 4,111 | 184 KB |
| agents/ (incl. compact twins) | 64 | 23,168 | 1.05 MB |
| gsd-core/workflows | 182 | 44,931 (md) | — |
| gsd-core/references | 132 | 14,669 | — |
| gsd-core/templates | 40 | 7,344 | — |
| hooks | 42 | 11,147 | 539 KB |
| src + bin (CJS/TS tooling) | — | ~207k | — |

There are also **628 docs files** and 461 changesets.

**Cost per invocation** (the part that matters):
- **plan-phase:** the spine is 98 KB (~24k tokens), plus 52 KB of `detail/`. The detail is read in full by default because `workflow.compact_content=false`. So **about 35–40k tokens land in the main "lean" orchestrator before any work starts**.
- **execute-phase:** the spine is 88 KB, plus up to 217 KB of steps and detail, much of it conditional.
- **Core agents:** each is about **47 KB (~12k tokens)**. The verifier also `@`-includes 54 KB of references, so a spawn is about 25k tokens of system prompt.
- **Fan-out:** a phase spawns roughly researcher + planner + checker ×(1–3) + 3 executors + verifier + reviewer + security auditor. That is about 10 or more spawns at 12–25k tokens of prompt each, before they read any project files.

---

## Part 2: gsd-path (open-gsd/gsd-path)

**What it is.** A second product from the same org: *"A disk-backed project pipeline… gated phases — inspect, define, research, decide, roadmap, plan, build, and ship — with every handoff written to `.project/` so any session can resume from disk alone."*

**Maturity:**
- **27 stars**, 7 forks, ~1,423 commits, created 2026-08-01.
- It is essentially a solo project: jeremymcs has 1,273 commits. He is also a top-5 Core contributor; the remaining commits are mostly Cursor agent bots.
- npm 1.5.0, released 2026-10-09.
- The docs are extensive and precise but dense: DOCS, QUICK, FULL, WORKFLOW (749 lines), AGENTS, RUNTIME, HOOKS, a domain glossary in CONTEXT.md, and 5 ADRs.
- It also ships a desktop app, a monitor daemon and a dashboard.

**How it differs from Core:**
1. **The unit is the milestone, not the phase.** It runs one linear pipeline per milestone, with an optional "program flow" of CHARTER plus ROADMAP above it. Core runs a repeated phase loop inside milestones.
2. **Deterministic Python helpers enforce the gates** instead of prose:
   - `pipeline_state.py status` is *"the only status authority"*.
   - `check_handoffs.py` gates plan, wave and final.
   - `check_task_briefs.py` lints briefs against the real base tree.
   - `isolation.py` owns worktrees: *"it never invents `git worktree add` or `--detach`"*.
   - In all there are about 36.5k unique lines of Python. **A project-local runtime is installed into `.gsd-path/`.**
3. **Strict git model:**
   - `origin` default must be `main`.
   - One branch per milestone, `gsd-path/M00N`; parallel tasks run on `gsd-path-task/<id>` worktrees; landing is serial.
   - Each task's Verify reruns in an isolated worktree at its base SHA plus only that task's patch.
   - Ship produces an archive commit, then a two-parent merge (direct, or a PR the user merges), then the tag `milestone/NNN-slug`.
   - Approvals are checkpoint commits.
4. **Task contracts replace XML plans.** Each `tasks/T###-slug.md` carries:
   - frontmatter: `files` (used for overlap checks), `deps`, and orchestrator-owned `base`, `worktree` and `status`
   - Context, Approach, a binding **Interface contract** shared verbatim with sibling tasks, Intent coverage (SC ids), Acceptance criteria, and one Verify command
   - Coders who meet ambiguity return `NEEDS-ORCHESTRATOR` instead of guessing.
5. **Authority order is explicit:** user > CHARTER > INTENT > SYNTHESIS > task. *"If two sources disagree, stop and surface the conflict. Never average."*
6. **Fixed user gates:** define, roadmap, plan, patch selection and ship. Everything else auto-advances. `--pre-approve intent,plan` exists for unattended quick lanes; ship always needs manual approval.

**Process:** router (`/path`) → 0 inspect (brownfield: codebase mapper and docs auditor, concurrent) → 1 define (INTENT.md, user gate) → 2 research (parallel evidence dimensions) → 3 decide (SYNTHESIS.md) → [3.5 roadmap] → 4 plan (PLAN.md plus task files, user gate) → 5 build (wave loop with streaming dispatch, then a wave review at depth full, verify-only or deep) → 6 ship (final review, archive, integrate).
- A **quick lane** skips research and decide.
- A discuss sidecar records to `.project/discuss/` without advancing.
- Wave 1 is ordered to *"burn down assumptions that could invalidate the plan"* and wave 2 to deliver *"the thinnest running end-to-end slice"*.

**State model:**
- `STATE.md` frontmatter holds phase, status, branch, archive and integration, plus an append-only Log.
- *"If this file and the artifacts disagree, the artifacts win — fix this file."*
- The active milestone has about 12 fixed files (INTENT, codebase evidence, DOCS-AUDIT, RESEARCH, up to 4 evidence files, SYNTHESIS, PLAN, FINAL, final-gap). It adds T task files and W×cycles wave reviews, plus PATCH-FINDINGS and the discuss logs.
- At ship, everything moves into `archive/NNN-slug/` with a MANIFEST. Only STATE, REPOSITORY, LESSONS and the program files stay live.
- So the working set resets each milestone, which is the main structural improvement over Core.

**Size:**
- The `skills/` tree has 564 files but only **117 unique**. The router skill and the phase skills are generated mirrors of each other.
- Unique markdown is about 7,100 lines; SKILL files total about 3,300 lines.
- Measured build-entry instructions fell *"from 17,637 to 4,399 tokens"*.

**Evidence of performance** (rare and honest; from `docs/token-evaluation.md`):
- A small task (add JSON output to a Python CLI, quick lane) used 29,005 output tokens. *"The coder accounts for 10.1% of output."*
- *"The retained direct-coding baseline completed the same fixture in 3,347 output tokens. The pipeline run used about 8.7 times as much."*
- *"It is not universally optimized."*
- The host trust matrix records full live-milestone receipts that pass on 7 hosts for 1.5.0. Several hosts were excluded for API-credit reasons.
- Core has nothing comparable. It has tests, but I found no published end-to-end cost or quality evaluation.

---

## Part 3: Critical assessment

### Worth borrowing (ranked)

1. **Goal-backward verification with an adversarial stance.** The idea is "summaries are claims, not evidence". The verifier checks plan-declared `must_haves` (truths, artifacts, key_links) at three levels: exists → substantive → wired. Behaviour claims without a test go to a human. Doing this pre-execution as well, through the plan checker, is cheap and high-value. A compact version fits in about 100 lines.
2. **Discuss before plan as "gray areas".** Ask about 1–2 ambiguities per area that would *change implementation*, and record them as locked `D-NN` decisions plus a `<deferred>` list. This is the cheapest rework prevention in either system.
3. **Executor deviation rules 1–4.** They are the clearest statement I have seen of what an agent may fix autonomously and when it must stop and ask.
4. **Disk as the only memory, with progress derived from artifacts.** A PLAN without a SUMMARY means incomplete. Path adds that artifacts beat STATE when they disagree. Keep STATE small (under 100 lines) with `next_action` in frontmatter, so resume and "what next" are mechanical.
5. **Pause hygiene.** A measured `uncommitted_files` list (from `git status --porcelain`, never narrated), and "blocking" anti-patterns the resuming agent must acknowledge.
6. **Path's task contract.** Declared `files` for overlap checks, a binding interface contract shared verbatim between sibling tasks, one Verify command that must fail if the task was skipped, and `NEEDS-ORCHESTRATOR` instead of guessing. This beats Core's XML-heavy plans.
7. **Path's wave ordering.** Risk burn-down first, then the thinnest end-to-end slice, then features and polish.
8. **Path's authority order and "never average".** Plus archiving at the milestone boundary so the live working set stays small.
9. **Lean-orchestrator rules.** Pass paths, not contents. Read only the frontmatter of subagent outputs. Never read agent definitions. Use a cheap model for mapping and checking and a strong model only for planning.

### What causes bloat

- **Self-contradicting "lean main context".** Core's orchestrator workflows are 90–150 KB each and load into the main session. Each core agent is about 47 KB, and every one of the dozen or so spawns per phase pays that cost. The prompt surface (~95k lines of markdown, 1 MB of agents, 72 commands mirrored as 72 skills) is enormous next to the "light-weight" label.
- **Patch-accretion prompting.** The prompts are full of issue numbers and edge-case clauses, for example *"(#3304)"*, *"(#3724)"*, *"Hyrum's Law"* and async HPC job manifests. Each fix added prose rather than code. The VERIFICATION.md reference entry alone is a single paragraph of more than 200 words of exceptions.
- **File sprawl:** about 15 files per phase and about 90 per milestone, plus DISCUSSION-LOG ("Not consumed by automated workflows"), VALIDATION, PATTERNS and SECURITY generated by default. Much of this is ceremony for small phases. The docs admit *"The overhead is real"* and warn that small phases make *"planning overhead that dwarfs the execution cost."*
- **Gate stacking.** Research, pattern mapper, planner, checker ×3, executors, verifier, code review, security, UAT and gap loop. Every gate is defensible on its own, but together they multiply cost. Path's own measurement of 8.7× tokens versus direct coding is the honest number for this class of system, and Core is likely heavier.
- **Path-specific overhead.**
  - A 36k-line Python runtime installed per project, hard requirements (`main`, GitHub.com for PRs), a daemon, a desktop app and multi-repo coordination.
  - These are robust but heavyweight; it is a product, not a pattern.
  - The single maintainer and 27 stars mean adoption risk.

### Bottom line

Borrow the ideas, not the systems. For a lightweight plugin, one design would combine:
- Core's **discuss → plan(+check) → execute → verify** loop
- with Path's task-contract shape, artifact-wins-over-state rule and milestone archiving.

It would keep about 4–5 artifacts per unit of work: CONTEXT, PLAN with must_haves, SUMMARY, and VERIFICATION, with STATE as the index. Core's quick mode (a quick folder and STATE table, with gates opt-in by flag) is the right default for a small repo like cargus-forge. The full loop is only worth it for multi-session features.

