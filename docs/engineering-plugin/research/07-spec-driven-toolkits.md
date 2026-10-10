---
title: "Research: spec-driven toolkits and critiques"
date: 2026-10-10
source: research subagent report, unedited
---

> Research subagent report from 2026-10-10, saved unedited. Paths under `/tmp/claude-1000/...` point to an ephemeral scratchpad and no longer exist.

# Spec-driven agentic engineering toolkits: survey as of 2026-10-10

**How this was verified.** I read primary sources wherever I could reach them: repo READMEs, changelogs, release pages, official docs, Böckeler's article and the HN threads. Where the only source was secondary, or I couldn't confirm something, it's marked **[unverified]**. Some live pages describe the 2026 state but no longer document the older layouts. Where I describe a layout from pre-2026 knowledge, I say so.

---

## 1. Tool-by-tool

### 1.1 GitHub Spec Kit
**Status:** Active and moving fast. Latest is **v1.1.3 (9 Oct 2026)**. The 1.0.x–1.1.x line (Sep–Oct 2026) added extensions, presets, bundles, a workflow engine, an experimental MCP server, and moved `taskstoissues` into a `github` extension (https://github.com/github/spec-kit/releases). Commands are now agent skills (`/speckit-<name>`), installed with `uv tool install specify-cli` and `specify init <proj> --integration <agent>` (https://github.github.com/spec-kit/).

**Process, in order:**
1. `/speckit-constitution`, once per project.
2. `/speckit-specify`: what and why, no tech stack.
3. `/speckit-clarify`: targeted questions folded back into the spec.
4. `/speckit-plan`: tech stack and design artifacts.
5. `/speckit-checklist`: "unit tests for your requirements".
6. `/speckit-tasks`: dependency-ordered task list.
7. `/speckit-analyze`: read-only consistency check across spec, plan and tasks.
8. `/speckit-implement`: refuses to proceed past unchecked checklist items without confirmation.
9. `/speckit-converge`: compares code against spec, plan and tasks, and appends gap tasks to `tasks.md`. You loop implement → converge until it reports "Converged".

Steps 1, 3, 5 and 7 are optional. Extensions add bug (`bug-assess`, `bug-fix`, `bug-test`) and assess workflows (https://github.github.com/spec-kit/quickstart.html).

**Artifacts:**
- `.specify/memory/` (constitution).
- Per feature: `spec.md`, `checklists/requirements.md`, `plan.md` plus other design artifacts, and `tasks.md`.
- The active feature is tracked in `.specify/feature.json`, not by git branch. Numbered branches such as `001-feature` are now opt-in via a git extension.
- The older `specs/NNN-feature/{research.md, data-model.md, contracts/, quickstart.md}` layout is from pre-2026 docs. **[unverified for current version]**
- Böckeler counted about 8 files for one spec (https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html). Marmelab counted 8 files and about 1,300 lines for a "show current date" feature (https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back).

**Research:** `plan` produces research and design artifacts, and the `assess` extension has a research step. Codebase research is weak in practice: Böckeler saw spec-kit regenerate classes it had already documented in research, creating duplicates.

**Verification:** Checklists validate the spec, not the code. `analyze` checks cross-artifact consistency. `converge` (added 2026) is the first code-versus-spec loop. Böckeler notes the agent interprets the checklists, so compliance isn't guaranteed.

**State and resumption:** The files plus `feature.json`, with checkbox state in `tasks.md`.

**Best idea:** Separate gates for *spec quality* (clarify, checklist) and *artifact consistency* (analyze), then a converge loop that turns spec-to-code gaps back into tasks.

**Criticisms:**
- Too many verbose, repetitive markdown files, some containing code, that are tedious to review. It felt like "overkill" for a 3–5 point feature (Böckeler).
- About 1,300 lines for a trivial feature, and "double review" of spec and then code (Marmelab).
- In 2025 practice the spec lived for one change, so it was spec-first rather than spec-anchored (Böckeler). Converge partly answers this, but only within a feature.
- "Rigid phase gates" and heavyweight Python setup (OpenSpec README, a competitor: https://github.com/Fission-AI/OpenSpec).
- An informal test measured about 121k tokens for Spec Kit versus about 58k for OpenSpec. This is one author's experiment, quoted via search; the source returned 403. **[unverified]** (https://pub.towardsai.net/spec-driven-development-with-ai-agents-spec-kit-vs-openspec-vs-bmad-plus-a-hands-on-openspec-7b6997074582)
- A Medium post claims a `/speckit.spec-drift` command shipped in May 2026. **[unverified; not in the release notes I read]**

### 1.2 AWS Kiro
**Status:** Active. Kiro CLI 2.29.0 (9 Oct 2026) and IDE 1.2.56 (8 Oct 2026). 2026 changelog items include V3 sessions, opt-in Workflows (Sep 30), a `SessionEnd` hook, "Powers", steering with live file references, and Claude Opus 5.5 and Sonnet 5.5 at credit multipliers. No 2026 changelog entry mentions specs (https://kiro.dev/changelog/).

**Process:** There are three spec types (https://kiro.dev/docs/specs/):
- **Feature spec:** Requirements → Design → Tasks (requirements-first), or Design → Requirements → Tasks (design-first, for strict non-functional requirements). Each phase is approved before the next.
- **Bugfix spec:** `bugfix.md` records current, expected and unchanged behaviour (regression guard), then design, then tasks.
- **Quick Spec:** all three artifacts in one pass with no gates.

**Analyze Requirements** flags gaps and ambiguity before design. "Run all tasks" builds a dependency graph and runs independent tasks in concurrent waves.

**Artifacts:** `requirements.md` (user stories plus EARS acceptance criteria, "WHEN [condition] THE SYSTEM SHALL [behaviour]"), `design.md` (architecture, sequence diagrams, data flow, error handling, testing strategy) and `tasks.md`. Three files per feature, conventionally in `.kiro/specs/<feature>/`. That path is from 2025 docs and not restated on the current pages. **[path unverified in 2026 docs]** (https://kiro.dev/docs/specs/feature-specs/)

**Steering:**
- Lives in `.kiro/steering/` (workspace) and `~/.kiro/steering/` (global).
- Default files are `product.md`, `tech.md` and `structure.md`.
- Inclusion modes are `always`, `fileMatch`, `manual` and `auto` (description-matched). `AGENTS.md` is always included (https://kiro.dev/docs/steering/).

**Hooks:** JSON files in `.kiro/hooks/`. Triggers include `PostFileSave`, `PreToolUse`, `PostToolUse`, `Stop` and `SessionEnd`. Actions are either a shell command or an injected agent prompt (https://kiro.dev/docs/hooks/).

**Research:** Steering supplies codebase context. Docs describe no external-research phase.

**Verification:**
- Tasks trace back to requirement IDs.
- **Correctness (IDE):** Kiro extracts properties from EARS requirements and generates property-based tests linked to the requirement and the task. Failures are shrunk to a minimal case, and you choose whether to fix the code, the test or the requirement. The docs admit weak properties can pass incorrect behaviour (https://kiro.dev/docs/specs/correctness/).

**State:** `tasks.md` status, plus "Refine and Sync Files" between spec files (per a third-party guide, https://www.verdent.ai/guides/agents/kiro-spec-driven-development). **[unverified in official docs]**

**Best idea:** EARS acceptance criteria turned mechanically into property-based tests. It is the most concrete bridge from prose spec to executable check of any tool here. Conditional steering inclusion is a close second.

**Criticisms:**
- A small bug fix became 4 user stories with 16 acceptance criteria, "like using a sledgehammer to crack a nut" (Böckeler). Bugfix and Quick specs look like the response.
- Mostly spec-first; specs are not maintained (Böckeler).
- Drift arises when `tasks.md` is hand-edited and never re-synced (Verdent guide).
- Locks you into Kiro's IDE and models (OpenSpec README, a competitor).
- HN users reported over-engineering, for example a roughly 5,000-line keyboard-shortcut helper (secondhand via https://glukhov.org/ai-devtools/ai-coding-assistants/spec-kit-vs-kiro-vs-claude-code/). **[unverified]**

### 1.3 BMAD Method
**Status:** Active, but heavily restructured in 2026 (https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/CHANGELOG.md):
- v6.1.0 (2026-03-12): everything becomes skills.
- v6.3.0: personas consolidated (Barry, Quinn and Bob folded into the Dev agent "Amelia").
- v6.8: `bmad-spec` and `bmad-ux` added.
- v6.10: `bmad-loop` for unattended epic loops.
- v6.11 (2026-08-09): Quick Dev renamed **Build**, core cut from 14 to 8 skills, `bmad-project-context` replaces the doc-generation skills.
- v6.12 (2026-09-03): Build "sizes a change's ceremony *after* investigating it".
- **v7 (unreleased draft):** initiative folders. The old `planning_artifacts` and `implementation_artifacts` keys are no longer read.

The famous 2025 roster (Analyst, PM, Architect, SM, Dev, QA with PRD, architecture, sharded story files) has largely given way to skills.

**Process:** "Choose a planning path" (https://docs.bmad-method.org/plan/choose-a-planning-path/):
- **Trivial:** no BMad.
- **One session:** `bmad-spec` → `bmad-build`.
- **Epic:** spec → `bmad-ticket` (stories in order in `tickets.toml`) → one Build per story → integration check → `bmad-retrospective`.
- **Project-sized (about 20+ sessions):** product brief, PRD, UX and architecture first, then a spec per epic.

Optional analysis skills come before any of these: brainstorming, forge-idea, deep-recon, PRFAQ.

**Artifacts:**
- Each skill writes to `<type>-<slug>/` under the initiative folder or `_bmad-output`.
- Examples: `prd-<slug>.md`, `addendum.md`, `.memlog.md`, `architecture-<slug>.md`, `spec-<slug>.md`, `DESIGN.md`, `EXPERIENCE.md`, `tickets.toml`, plus a plan file per story beside `tickets.toml`.
- A project-sized effort produces many documents.

**Research:** `bmad-deep-recon` writes `research-<topic>.md`. `bmad-investigate` and `bmad-project-context` cover existing codebases ("verified context on an inherited codebase", README).

**Verification:**
- Build includes review, and `bmad-review` has lenses. v6.12 made review triage log a verdict and evidence per finding.
- Integration checks and a retrospective run at each epic boundary.
- Test Architect (TEA) is an enterprise add-on.

**State:** `tickets.toml` status (`built` → done), plan files and `.memlog.md`.

**Best idea:** Scale-adaptive entry, where the *size of the change selects the path*. Since v6.12 the ceremony is sized after investigating the change rather than guessed beforehand.

**Criticisms:**
- Marmelab groups BMad with the "waterfall in markdown" tools.
- I found no independent, substantive critique of BMAD's context cost. Search surfaced only BMAD's own docs and a vendor case study. **[gap]**
- The 2026 changelog itself reads as an implicit critique: personas collapsed, core skills cut from 14 to 8, ceremony sized after investigation, and a v7 directory migration.

### 1.4 OpenSpec (Fission AI)
**Status:** Active. v1.14.1 (6 Oct 2026). 2026 work rebuilt the workflow around "OPSX" artifact guidance, added a `/opsx:verify` that reports only checks it actually ran (v1.13.2), capability retirement on archive, `show --diff`, and Stores (beta) for cross-repo shared specs (https://github.com/Fission-AI/OpenSpec/releases).

**Process:**
1. `/opsx:explore` (optional).
2. `/opsx:propose <name>`.
3. `/opsx:apply`.
4. `/opsx:verify` (expanded profile).
5. `/opsx:archive`.

Artifacts form a dependency graph that the project describes as "enablers, not gates": proposal → (specs, design) → tasks (https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md).

**Artifacts:**
- **Living truth:** `openspec/specs/<capability>/spec.md`, holding a Purpose section and requirements, each with `#### Scenario:` WHEN/THEN blocks.
- **Per change:** `openspec/changes/<id>/{proposal.md, design.md, tasks.md, specs/…}`, where the `specs/` files are *delta specs* with ADDED, MODIFIED and REMOVED requirements.
- **Archive:** merges the deltas into the main specs and moves the change to `changes/archive/<date>-<id>/`. About 3–4 files per change.

**Research:** The explore mode, which now asks before writing files (v1.11).

**Verification:** `/opsx:verify` checks implementation against the specs, and `validate` checks structure.

**State:** The change folder, `openspec status` (with a "Next" step line), and the dashboard.

**Best idea:** Delta specs plus archive-merge. It is the only widely used tool that is actually **spec-anchored**: one current-behaviour spec per capability, changed by reviewable diffs, brownfield-first.

**Criticisms:**
- One author found that "despite all the ceremony, it failed to deliver meaningful improvements" over a plain instructions file (https://medium.com/@mpholoane/spec-driven-development-sometimes-the-simpler-instructions-md-is-enough-b960fbda772b, via search). **[not read in full]**
- The living specs still depend on archive discipline. If changes aren't archived, the main specs go stale. This is my inference, not a cited critique.

### 1.5 Agent OS (Builder Methods, Brian Casel)
**Status:** Active, but **repositioned**. In **v3.0 (2026-01-20)** spec creation now "defers to Plan Mode — the industry-standard approach to SDD in 2026+". Task breakdown is left to Claude Code's todos, and implementation and orchestration phases were *retired* because "frontier models manage task delegation on their own" (https://raw.githubusercontent.com/buildermethods/agent-os/main/CHANGELOG.md).

**Process (v3):**
- `/discover-standards` extracts patterns from the codebase into standards files.
- `/inject-standards` loads relevant standards using `index.yml`.
- `/shape-spec` asks targeted questions inside plan mode and saves the plan to the spec folder.
- A sync script pushes project standards back to the base profile.

**Artifacts:** Files under `agent-os/` (standards plus `index.yml`, and spec folders). The exact subpaths aren't listed on the current pages. **[unverified]** v1/v2 had product mission and roadmap files, `decisions.md` (later "Recaps"), and per-spec task lists (https://buildermethods.com/agent-os).

**Verification:** Not a focus in v3. v2.0.3 "reduced excessive test writing" (an admission that over-testing is a real cost).

**State:** The saved plan and standards files.

**Best idea:** Mine *standards from existing code* and inject only the relevant ones through an index, rather than writing a monolithic constitution.

**Criticisms:** The author's own retreat is the strongest data point. He dropped spec, tasks and orchestration phases once native plan mode and todos arrived. I found no independent critique. **[gap]**

### 1.6 Tessl
**Status: effectively pivoted.**
- tessl.io now sells an "agent enablement platform" covering skills Context, a Registry, Loops and a "Factory". The homepage doesn't mention spec-driven development or spec-as-source (https://tessl.io/).
- A mid-2026 review on a competitor's blog says that on 29 Jan 2026 the Spec Registry was repositioned as a skills registry. The Tessl Framework (spec → code CLI and MCP) was still closed beta about 9 months after launch (https://codemyspec.com/blog/tessl-review, 3 Jun 2026). **[secondary; dates unverified against Tessl's blog]**

**Process (Framework, per Böckeler, 2025):**
- Write a spec with `@generate` and `@test` tags and an API section.
- `tessl build` generates code with a "GENERATED FROM SPEC — DO NOT EDIT" header, one spec per code file.
- `tessl document --code` reverse-engineers a spec from existing code.

**Best idea:** True spec-as-source, where code is a build artifact and the spec's API section pins the interface.

**Criticisms:**
- Regenerating from the same spec gave different code (Böckeler).
- It risks combining model-driven development's rigidity with LLM non-determinism (Böckeler).
- "Truest vision, least-proven execution"; observed output was JavaScript only (CodeMySpec).

### 1.7 Cline Memory Bank
**Status:** Still in Cline's docs. It is a prompt pattern, not a tool (https://docs.cline.bot/prompting/cline-memory-bank). I couldn't verify a 2026 change or replacement. **[unverified]**

**Artifacts:** `memory-bank/` with six files in a hierarchy. `projectbrief.md` feeds `productContext.md`, `systemPatterns.md` and `techContext.md`, which feed `activeContext.md` and `progress.md`. Optional extra files are allowed.

**Process:** "initialize memory bank". Cline must read **all** files at the start of every task. You say "update memory bank" after significant changes or before a context reset, then "follow your custom instructions" to resume.

**Verification:** None.

**State:** This is the entire purpose. `activeContext.md` and `progress.md` are the resumption cursor.

**Best idea:** Explicit separation of *slow-changing* context (brief, patterns, tech) from a *fast-changing cursor* (active context, progress).

**Criticisms:**
- The docs themselves concede that every task pays the cost of reading every file, and that accuracy depends on manual upkeep.
- Staleness and drift are raised mainly by vendors selling alternatives, for example https://www.memorylake.ai/blogs/cline-forgets-project-context. **[biased sources]**
- Böckeler classes it as a "memory bank", distinct from specs.

### 1.8 Other tools that became prominent by 2026
**obra/Superpowers.** A skills plugin for Claude Code (https://github.com/obra/superpowers):
- Flow: brainstorming (design doc for larger work) → git worktree with a clean test baseline → writing-plans (2–5 minute tasks with exact paths, code and verification steps) → subagent-driven development (fresh subagent per task, two-stage review for spec compliance then code quality) → strict TDD (red/green) → code review between tasks (critical issues block) → finish branch.
- Best idea: verification is built into every task, enforced by TDD and per-task review rather than a final checklist.
- Artifact paths are not shown on the README. **[unverified]**
- Star counts quoted by blogs (over 200k) are unverified.

**GSD ("Get Shit Done").**
- Commands: `/gsd:new-project`, `discuss-phase`, `plan-phase`, `execute-phase`, `verify-work`, `complete-milestone`, and `resume-work` to rebuild state in a new session.
- Everything lives in `.planning/`: `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `research/` and `SUMMARY.md`. Each task gets a fresh-context subagent, explicitly to fight "context rot", and each step is committed.
- **Provenance warning:** a May 2026 update says the original repo "can no longer be trusted" after a meme-coin and ownership incident. Use the open-gsd/get-shit-done-redux fork (https://www.codecentric.de/en/knowledge-hub/blog/the-anatomy-of-claude-code-workflows-turning-slash-commands-into-an-ai-development-system, Felix Abele, 3 Mar 2026, updated May 2026).

**Native plan mode.** Agent OS v3 explicitly treats Claude Code plan mode as the default spec step. HN commenters say the same, including fzaninotto: "plan mode already does the job".

---

## 2. Critiques of SDD in general

**Böckeler, "Understanding Spec-Driven-Development: Kiro, spec-kit, and Tessl" (martinfowler.com, 15 Oct 2025)** (https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html). HN: 128 points, https://news.ycombinator.com/item?id=45610996.

- **Taxonomy:**
  - *Spec-first:* write the spec, use it for the task, then discard it. All three tools did at least this.
  - *Spec-anchored:* keep the spec and evolve the feature through it.
  - *Spec-as-source:* humans edit only the spec. Only Tessl aimed here.
- **Specs versus memory bank:** specs are separate from the memory bank (steering files, constitution, rules).
- **Findings:**
  - One workflow for every problem size.
  - Markdown review burden: "I'd rather review code".
  - False sense of control: agents ignore instructions or over-apply the constitution.
  - Unclear split between functional and technical content in a spec.
  - Unclear user (developer or product person).
  - Poor fit for brownfield work.
- **MDD parallel:** model-driven development failed for business apps through rigidity and overhead. SDD risks both that rigidity and LLM non-determinism.
- **Closing word:** *Verschlimmbesserung*, making things worse while trying to improve them.
- **No 2026 follow-up article found** on martinfowler.com. She discussed SDD on a Thoughtworks podcast (~May 2026) (https://www.thoughtworks.com/insights/podcasts/technology-podcasts/what-is-spec-driven-development). **[content not verified]**

**Thoughtworks Radar:** SDD placed in **Assess** (Nov 2025), with the warning: "workflows remain elaborate and opinionated… some generate lengthy spec files that are hard to review… handcrafting detailed rules for AI ultimately doesn't scale." It is not on the current edition (https://www.thoughtworks.com/radar/techniques/spec-driven-development).

**"Waterfall Strikes Back" (François Zaninotto, Marmelab, 12 Nov 2025).** HN: 225 points and 191 comments, https://news.ycombinator.com/item?id=45935763.
- Big Design Up Front piles up hypotheses, and software is non-deterministic.
- Specs are blind to existing context, so experts still review twice.
- He calls it false confidence: an agent ticked "verify implementation" and wrote manual test instructions instead of tests.
- His alternative is a lean loop: test the riskiest assumption first, with no spec. He built a 3D sculpting tool in about 10 hours this way.
- **HN for:** specs are a "context entrypoint" (podgorniy); executable acceptance tests pay off (canterburry); "far too many specs than none" (cushychicken).
- **HN against:** "SDD is exactly waterfall", and consistency costs grow with size (constantcrying); "an unreliable compiler" (pipes); per-ticket specs already exist under agile (mattmanser).
- **HN consensus:** the real variable is how much to plan and how cheap it is to change the plan.

**Other critiques:**
- **"Spec-driven development doesn't work if you're too confused to write the spec"** (HN 46955747, https://publish.obsidian.md/deontologician/Posts/Spec-driven+development+doesn%27t+work+if+you%27re+too+confused+to+write+the+spec). fl0ki adds that no spec is complete, because real systems accrue behaviour that clients depend on.
- **Verified SDD (VSDD)** (HN 47197595, Feb 2026). Contracts and tests gate implementation. Critics warn that tests-first can lock in a hallucinated API, and that passing individual tests doesn't show progress toward a spec that only works as a whole.

**Spec-first vs spec-anchored vs spec-as-source in practice (Oct 2026):**
- Spec-first dominates.
- Spec-anchored is real only where there is a merge mechanism: OpenSpec archive or Spec Kit converge.
- Spec-as-source (Tessl) has not shipped generally, and its leading vendor has pivoted to skills. Tessl's pivot is the strongest market signal on that level.
- The heavier tools have all *retreated toward lighter defaults*: Kiro Quick and Bugfix specs, Spec Kit's optional steps, BMad's "trivial → no BMad" path and ceremony sized after investigation, Agent OS deferring to plan mode.

**Empirical evidence (thin):**
- **Tufano et al., arXiv 2608.17177 (SpecOps '26).** Spec-driven *test generation* on Google production bugs: +9.8 pp bug detection (p=0.035) and +2.5 pp branch coverage versus a baseline agent (https://arxiv.org/abs/2608.17177). This is evidence for *contract or spec reasoning before tests*, not for document-heavy workflows.
- **SpecMine (CMU, arXiv 2608.25202).** 470,795 spec files across 73,030 repos and 17 tools, plus 98,574 Kiro spec files across 12,910 repos. It shows adoption, but the abstract reports no drift or maintenance findings (https://arxiv.org/abs/2608.25202).
- **arXiv 2609.00252.** A conceptual paper built mostly on gray literature that explicitly says peer-reviewed evidence is limited (https://arxiv.org/abs/2609.00252).
- **Rosa et al., arXiv 2601.03878.** A study protocol; no results yet.
- **Net:** no controlled study yet shows SDD toolkits beat plan mode plus tests for delivery speed or quality.

---

## 3. Cross-tool synthesis

### Recurring ideas
1. **Always-loaded project context**, separate from per-change specs: Kiro steering, Spec Kit constitution, Agent OS standards, BMad project-context, Cline memory bank, GSD `PROJECT.md`, all equivalent to `CLAUDE.md`.
2. **A three-step pipeline per change: what (requirements or spec) → how (design or plan) → tasks.** Every tool has it.
3. **Acceptance criteria as structured scenarios:** EARS (Kiro), WHEN/THEN scenarios (OpenSpec), "Given/When/Then" (Böckeler on Kiro).
4. **A clarify or interrogate step before planning:** Spec Kit clarify, Superpowers brainstorming, Agent OS shape-spec, GSD discuss-phase, OpenSpec explore.
5. **Tasks as a checkbox file** that doubles as resumption state.
6. **Fresh context per task through subagents** (Superpowers, GSD, Kiro waves).
7. **Size-based routing:** Kiro Quick and Bugfix specs, BMad paths, OpenSpec's light default profile.
8. **A post-implementation spec-to-code check:** Spec Kit converge, OpenSpec verify, GSD verify-work, Kiro property-based tests.

### Proven valuable versus ceremony
**Supported by evidence or by convergence of practice:**
- **Short always-on context, injected selectively.** Kiro `fileMatch`/`auto` modes and Agent OS `index.yml` exist because monolithic context bloats.
- **Clarifying questions before planning.** Cheap, and the most commonly retained step.
- **Executable acceptance criteria and tests.** The Tufano evidence, HN practitioners and Superpowers TDD all point here; prose checklists ticked by the agent proved unreliable (Marmelab).
- **Delta-based change records against a small living spec,** only for stable, behaviour-critical capabilities (OpenSpec).
- **Fresh-context subagents and per-task review** for long work.
- **A converge/verify loop that writes gaps back as tasks.**

**Mostly ceremony for a solo developer:**
- Constitutions of "immutable articles", which agents over-apply.
- Separate `research.md`, `data-model.md`, `contracts/` and `quickstart.md` per feature.
- Persona role-play (BMad itself collapsed its personas).
- PRDs for single-session changes.
- Spec-as-source regeneration.
- Spec-quality checklists ticked by the same agent.
- Separate orchestration layers now that models and plan mode handle delegation (Agent OS's own conclusion).

### Recommended minimal artifact set: solo developer, Claude Code, GitHub issues, umbrella issues with sub-issues

Route by size, BMad-style, and decide the size *after* a quick investigation.

**0. Always on, for all work**
- `CLAUDE.md` plus path-scoped `.claude/rules/` as steering. Keep it short. Use path scoping as the analogue of Kiro's `fileMatch`.
- No constitution file.

**1. Trivial change**
- No artifact beyond the commit or PR.

**2. One-session change**
- **One GitHub issue is the spec.** It holds:
  - the problem and desired outcome;
  - acceptance criteria as 3–7 WHEN/THEN scenarios;
  - non-goals.
- The plan lives in **plan mode** and is not persisted.
- The PR links the issue, and tests encode the scenarios.

**3. Multi-session feature**
- **Umbrella issue = requirements and design.** It holds:
  - outcome and scenarios;
  - a short design section of key decisions and affected modules, written from a codebase investigation;
  - non-goals and open questions.
- **Sub-issues = `tasks.md`.** Each one:
  - is sized for one session;
  - has its own acceptance checks;
  - is ordered by dependency.
- **Resumption state is GitHub state:** open or closed sub-issues, plus a "where I stopped / next step" comment on the umbrella issue at session end. This replaces `activeContext.md`, `STATE.md` and `tickets.toml`.
- Before closing the umbrella issue, run a **converge pass**: ask Claude to compare the merged code against the umbrella scenarios, and open sub-issues for any gaps.

**4. Durable knowledge only, and only when it outlives the feature**
- **ADRs** for decisions with lasting consequences.
- An optional OpenSpec-style `specs/<capability>.md` for the few capabilities whose behaviour is a contract (APIs, billing, auth). Update it in the same PR as the code, as a delta.
- Everything else is spec-first and disposable. Let the closed issues be the history.

**Why this set:** It keeps the four ideas with evidence behind them: clarified acceptance criteria, executable tests, a verify/converge loop, and selective context. It reuses GitHub as the task and state store, so you don't keep parallel markdown that can drift. It avoids the documented failure modes: review overload, drift between spec files and code, and sledgehammer ceremony on small fixes.

---

## 4. Not verified, or flagged
- Kiro's `.kiro/specs/<name>/` path and Spec Kit's `specs/NNN-feature/` sub-artifact layout (from 2025 docs, not restated on current pages).
- A claimed `/speckit.spec-drift` command (May 2026).
- Superpowers artifact paths and star count.
- Tessl's 29 Jan 2026 pivot date (secondary source only).
- BMAD v6.0.0 stable release date.
- Thoughtworks Radar Vol 34 placement (the blip page reports Nov 2025, Assess, not current).
- The token comparison between OpenSpec and Spec Kit.
- Any independent critique of BMAD's or Agent OS's context cost; none found.
- A 2026 Böckeler article; none found.
