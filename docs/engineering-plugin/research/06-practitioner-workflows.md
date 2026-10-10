---
title: "Research: practitioner agentic workflows"
date: 2026-10-10
source: research subagent report, unedited
---

> Research subagent report from 2026-10-10, saved unedited. Paths under `/tmp/claude-1000/...` point to an ephemeral scratchpad and no longer exist.

# Practitioner agentic-engineering workflows: survey as of 2026-10-10

**How to read this:** [V] means I read the primary source myself. [S] means the claim comes only from secondary sources or search summaries. "Unverified" means I could not confirm it. Every source was read through WebFetch or WebSearch summaries, so short quotes are paraphrased unless they appear in quotation marks.

---

## 1. obra/superpowers (Jesse Vincent)

- **Process [V]** (https://github.com/obra/superpowers): The flow is brainstorming → using-git-worktrees → writing-plans → subagent-driven-development *or* executing-plans → test-driven-development → requesting-code-review → finishing-a-development-branch.
  - Brainstorming asks clarifying questions and restates its understanding. Small changes are agreed in chat; larger work gets a written design doc.
  - The worktree step runs a baseline test pass before any change.
- **Artifacts [V]:**
  - Plans go to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` (https://raw.githubusercontent.com/obra/superpowers/main/skills/writing-plans/SKILL.md).
  - A plan header holds the goal, the architecture, a link to the spec, global constraints copied verbatim from the spec, and a "review focus" list of likely failure inputs.
  - Tasks are "the smallest unit with its own test cycle that a reviewer could meaningfully approve or reject." Each one names files, interfaces, test names and assertions, and leaves the bodies to the implementer.
  - The spec/design-doc path is unverified; it is probably a sibling `docs/superpowers/specs/`.
- **Research:** Superpowers has no dedicated codebase-research phase. Research happens inside brainstorming. External research is not a formal step.
- **Verification [V]:**
  - The stated stance is "Evidence over claims", with a verification-before-completion skill.
  - TDD is enforced as red-green-refactor.
  - Subagent-driven mode puts a reviewer gate after each task and a whole-branch review at the end.
  - v7.0.0 (2026-10-09) replaced the spec-document reviewer with a "builder check": a fresh subagent reads the design as its builder would and lists the questions it would still need to ask (RELEASE-NOTES.md).
  - Skills themselves are evaluated with a "drill" eval harness.
- **State and resumption:**
  - Plans use checkbox steps and live on disk in a worktree, so a run can resume from the plan.
  - The README admits that hosts without a post-compaction hook can lose the skill bootstrap after compaction; the fix is a fresh session [V].
- **Best idea:** Fresh-context subagent per task plus an independent reviewer gate. The implementer never grades its own work, and the parent context stays small.
- **Failure modes and criticisms:**
  - **Token cost and over-planning of small tasks.** This is a long-running community complaint [S]: https://aicoding.csdn.net/6a596f8810ee7a33f28e453a.html, https://mcp.directory/blog/superpowers-skill-worth-it-2026.
  - **The maintainer's own fixes point the same way [V]:**
    - v6.4.2 made plans "leaner", reporting about ¼ of the time and about ⅓ of the tokens.
    - v6.4.1 calls native (inline) execution "the cheapest way to run a plan".
    - A 6.0 review consolidation is reported [S]: https://pub.towardsai.net/superpowers-6-0-unpacked-faster-ai-code-review-and-fewer-tokens-5ab40a6c564c.

## 2. HumanLayer / Dex Horthy: ACE-FCA, RPI → QRSPI, 12-factor agents

- **Process [V]** (https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md):
  - **Research:** map the relevant code, the information flow, and likely causes.
  - **Plan:** exact steps, files to edit, and verification for each phase.
  - **Implement:** phase by phase. After each verified phase, the status is compacted back into the plan.
  - The steps are flexible: research is sometimes skipped, sometimes repeated.
  - Only implementation runs in a worktree.
- **Context discipline [V]:**
  - "Frequent intentional compaction" means keeping utilization in the **40–60%** range.
  - Subagents exist mainly for context control: searching and summarizing happen in a fresh window.
  - Ranked context failures, worst first: incorrect info > missing info > noise.
- **"Dumb zone" and the "~40% rule":** These are attributed to Horthy only by secondary sources (https://chensg.substack.com/p/beyond-vibe-coding-the-engineering). **The exact threshold is unverified.**
  - The Pragmatic Engineer reports that he runs 1M-token models up to about 300–400K [S] (https://newsletter.pragmaticengineer.com/p/context-engineering-with-dex-horthy).
- **Artifacts [V]:** Research, plan and status markdown live in `thoughts/` (e.g. `thoughts/shared/...`), outside the code.
- **Human review [V]:** Review effort goes to research and plans, not code. "A bad line of plan → hundreds of bad lines of code; a bad line of research → thousands." Review is also framed as *team mental alignment*.
- **Claimed results [V], all anecdotal:**
  - An amateur fixed a bug in BAML (about 300k LOC of Rust) and the PR was approved the next morning.
  - About 35k LOC was shipped in about 7 hours.
  - Spend was about $12k/month on Opus for 3 engineers.
- **Self-reported failures [V]:**
  - A research pass wrongly concluded a bug was invalid.
  - Removing Hadoop from parquet-java failed because research was too shallow.
  - A race condition took two weeks.
- **2026 revision, RPI → QRSPI [S]:** The keynote was "Everything We Got Wrong About Research-Plan-Implement" (Coding Agents Conference, 2026-03-03; https://www.humanlayer.dev/qrspi-mlops). Write-ups (https://alexlavaee.me/blog/from-rpi-to-qrspi/) report:
  - **RPI's failures:**
    - an *instruction budget* overflow, where long prompts led to silently skipped steps;
    - *magic-word* dependence;
    - a *plan-reading illusion*, where fluent plan prose hid wrong assumptions. The quoted line is "A 1,000-line plan contains as many surprises as 1,000 lines of code."
  - **The new pipeline:** Questions → Research (ticket hidden, so the research stays objective) → Design discussion (about 200 lines, heavily reviewed) → Structure outline (signatures, types, vertical-slice phases, "like a C header") → Plan (spot-checked) → Worktree → Implement → PR. The human must read and own all code.
  - HumanLayer has reportedly not open-sourced QRSPI; community ports exist (e.g. https://github.com/dfrysinger/qrspi-plus).
- **12-factor agents [V]** (https://github.com/humanlayer/12-factor-agents): these are for building agents, but several apply to coding workflows:
  - own your prompts;
  - own your context window;
  - compact errors into context;
  - small, focused agents;
  - launch/pause/resume with simple APIs;
  - make your agent a stateless reducer.
- **Best idea:** Review at the highest-leverage artifact, and treat context as the budget to design around.
- **Criticism:** Horthy is now his own main critic (QRSPI). The plan-reading illusion is a direct admission that long plans create review theatre.

## 3. Every: Compound Engineering (Kieran Klaassen, Trevin Chow)

- **Process [V]** (https://every.to/guides/compound-engineering): Plan → Work → Review → Compound → repeat. "Each unit of engineering work should make subsequent units easier."
  - Time split: about 80% plan+review and 20% work+compound. Org-wide, about 50/50 features vs system improvements.
- **Research [V]:**
  - Parallel agents: repo-research-analyst, framework-docs-researcher, best-practices-researcher, plus spec-flow-analyzer.
  - It is the most explicit of the frameworks about *external* research.
- **Verification [V]:**
  - Tests, lint and type checks run after each change.
  - Review uses 14+ parallel specialist reviewers (security-sentinel, performance-oracle, …) with P1/P2/P3 triage.
- **Artifacts and state [V]** (https://github.com/EveryInc/compound-engineering-plugin):
  - Folders: `docs/brainstorms/`, `docs/plans/`, `docs/solutions/` (YAML-frontmattered learnings that later `ce-plan`/`ce-brainstorm` runs read back), and `todos/`.
  - Configuration lives in `.compound-engineering/config.yaml`.
  - Learnings also flow into CLAUDE.md and into new agents.
  - The plugin now has 36 skills (`ce-brainstorm`, `ce-plan`, `ce-work`, `ce-code-review`, `ce-compound`, `ce-compound-refresh`, `lfg`, …) across 14 agent hosts.
- **Best idea:** The explicit **Compound** step turns every bug, review finding and fix into retrievable, searchable knowledge, so the system improves and not just the code.
- **Criticisms:**
  - The guide's own figures are anecdotal: a "95% garbage rate" on first attempts and "5–10× faster" [V].
  - It says nothing about the cost of running dozens of agents per feature; `/lfg` reportedly spawns 50+.
  - The source is promotional.
  - The existence of `ce-compound-refresh` implicitly concedes that accumulated knowledge goes stale and needs pruning. That is my inference, not a stated claim.

## 4. Geoffrey Huntley: the "Ralph Wiggum" loop

- **Process [V]** (https://ghuntley.com/ralph/):
  - The loop is `while :; do cat PROMPT.md | agent; done`.
  - Specs are created through a long conversation and saved one per file in `specs/`.
  - `fix_plan.md` is a prioritized TODO; later variants call it `IMPLEMENTATION_PLAN.md` [S].
  - `AGENT.md` (build/run commands) is kept brief and updated by Ralph.
  - **One item per loop**, chosen by the agent.
- **Research:** The main context acts as a scheduler. Searching and summarizing go to many parallel subagents, while build and test parallelism is capped. Explicit rule: "don't assume not implemented", search first, because ripgrep false negatives caused duplicate reimplementations [V].
- **Verification [V]:**
  - "Backpressure" comes from tests, builds, type checkers and static analysis.
  - Only tests for the changed unit run.
  - Ralph writes a note on *why* each test exists, because future loops won't remember.
- **State and resumption:**
  - Every iteration is a fresh context. All state lives in specs, the plan, AGENT.md and git.
  - This deliberate "malloc" of the same context each loop counters the degradation he observes in a ~170k window.
  - He often **throws `fix_plan.md` away and regenerates it** from specs plus code [V].
- **Best idea:** Make state external and disposable. The plan is cheap and regenerable; specs and tests are the durable truth.
- **Failure modes [V]:**
  - placeholder implementations, countered with "no cheating" prompts;
  - wrong specs leading to wasted loops;
  - broken codebases after unattended runs.
  - Huntley positions Ralph for **greenfield** work and says senior judgment is still required.
- **Criticisms [S]:**
  - Anthropic's official ralph-wiggum plugin reportedly keeps one context window, which defeats the fresh-context premise (https://chaseai.io/blog/ralph-loop-vs-claude-code-plugin).
  - Runaway loops without iteration caps, e.g. 1,966 iterations (https://dev.to/sean8/i-accidentally-made-claude-ask-itself-the-same-question-1966-times-1c5h).
  - Honesty concerns about "never stop" prompts (https://www.greaterwrong.com/posts/bmNHsY5i3EoP4BAoJ/ralph-wiggum-is-bad-and-anthropic-should-fix-it).

## 5. Harper Reed's LLM codegen workflow

- **Process [V]** (https://harper.blog/2025/02/16/my-llm-codegen-workflow-atm/):
  1. **Idea honing:** a chat LLM asks *one question at a time* and produces `spec.md`.
  2. **Planning:** a reasoning model turns the spec into a blueprint of small, test-driven chunks, saved as `prompt_plan.md` (a series of codegen prompts). A separate prompt produces `todo.md`, a checklist the agent updates as its cross-session state.
  3. **Execution:** paste prompts one by one into Claude or Aider, running tests after each step.
  - For brownfield work, planning is per task, and repomix packs the code into the LLM for reviews, missing tests and issue lists.
- **Best idea:** The one-question-at-a-time interview. It is now canonical: Anthropic's "interview me" prompt and superpowers' brainstorming both use it.
- **Self-criticisms [V]:**
  - "over my skis": output outruns understanding;
  - works for solo developers but not teams (bots collide, merges are messy);
  - prompts age fast.

## 6. Simon Willison: Agentic Engineering Patterns

- **Source [V]:** a living guide started on 2026-02-23 (https://simonwillison.net/guides/agentic-engineering-patterns/).
- **Sections:**
  - **Principles:** "Writing code is cheap now", "Hoard things you know how to do", "AI should help us produce better code", anti-patterns such as inflicting unreviewed code on collaborators.
  - **Working with agents:** git, subagents (Explore, parallel, specialist).
  - **Testing and QA:** red/green TDD, "First run the tests", agentic manual testing with notes via Showboat.
  - **Understanding code:** linear walkthroughs, interactive explanations.
  - **Annotated prompts.**
- **Verification [V]:**
  - "Automated tests are no longer optional when working with coding agents." Starting every session with "first run the tests" makes the agent find the suite, gauge the project's size, and adopt a testing mindset (https://simonwillison.net/guides/agentic-engineering-patterns/first-run-the-tests/).
  - Red/green means confirming that the test fails first, otherwise it doesn't exercise the new code (https://simonwillison.net/guides/agentic-engineering-patterns/red-green-tdd/).
- **Terminology [S]:**
  - Vibe coding is code you don't read.
  - He proposed "vibe engineering" (https://simonwillison.net/2025/Oct/7/vibe-engineering/) and later adopted "agentic engineering".
  - He has since worried the two are converging.
- **Best idea:** Have the agent show *evidence* (executed tests, manual-test notes, walkthroughs), plus a personal hoard of working examples to recombine.
- **Weakness:** It is a pattern catalog, not a pipeline. It prescribes no state or resumption model.

## 7. Anthropic: Claude Code best practices

- **Source [V]:** https://code.claude.com/docs/en/best-practices
- **Core premise:** "Most best practices are based on one constraint: Claude's context window fills up fast, and performance degrades as it fills."
- **Process:** Explore → Plan (plan mode, with the plan editable via Ctrl+G) → Implement → Commit.
  - It explicitly warns that planning adds overhead: "If you could describe the diff in one sentence, skip the plan."
- **Specs:** "Interview me in detail using the AskUserQuestion tool… then write a complete spec to SPEC.md." Then a **fresh session** executes it.
  - Good specs are self-contained, name the files and interfaces, state what is out of scope, and end with an end-to-end verification step.
- **Verification is the #1 tip:** "Give Claude a check it can run." The doc lists four escalating gates:
  1. in the prompt;
  2. a `/goal` condition;
  3. a deterministic Stop hook;
  4. a verification subagent in a fresh context ("the agent doing the work isn't the one grading it").
  - "Have Claude show evidence rather than asserting success."
  - Writer/Reviewer sessions, and test-writer vs implementer.
  - The doc warns that adversarial reviewers always find *something*, and that chasing every finding leads to over-engineering; restrict them to correctness and stated requirements.
- **Context and state:**
  - `/clear` between tasks; after two failed corrections, `/clear` and re-prompt.
  - Subagents for investigation; `/compact <focus>`; `/rewind`; named sessions resumed with `--continue`/`--resume`.
  - CLAUDE.md should be short ("Would removing this cause Claude to make mistakes?"). Skills hold on-demand knowledge; hooks hold must-happen rules.
- **Named failure patterns:** kitchen-sink session, correcting over and over, over-specified CLAUDE.md, trust-then-verify gap, infinite exploration.
- **Best idea:** Escalating verification gates, combined with a deliberate "skip the plan" threshold.

## 8. Aider: ask/code and architect/editor

- **Source [V]:** https://aider.chat/docs/usage/modes.html
- **Modes:** The recommended loop is to discuss and agree a plan in `ask` mode, then switch to `code` ("go ahead").
- **Architect mode** splits one request across two models: an architect proposes the solution, and an editor model turns it into precise edits. It was motivated by strong reasoners (o1) that edit files poorly. Costs are two requests and more latency.
- **State:** git commits for every change, plus the chat history. There is no plan artifact.
- **Best idea:** Separate *reasoning about the change* from *mechanically applying it*. This is the ancestor of plan mode and of planner/implementer subagents.
- **Weakness:** Single-session; no research or compounding layer.

## 9. Addy Osmani: "How to write a good spec for AI agents" (2026-01-13)

- **Source [V]:** https://addyosmani.com/blog/good-spec/
- **Brief to plan:** Write a short brief, let the agent expand it into a spec and plan, and review it in read-only plan mode before any code.
- **Six spec areas,** from GitHub's analysis of 2,500+ agent files: commands, testing, project structure, code style, git workflow, boundaries.
- **Three-tier boundaries:** Always / Ask first / Never.
- **Modular context:** give each task only its relevant spec slice; use subagents; start fresh sessions per feature.
- **Built-in self-checks:** LLM-as-judge for subjective criteria, plus conformance suites.
- **Drift:** keep a **living, versioned spec** and run tests at each milestone.
- **"Curse of instructions":** adherence to each instruction drops as instructions accumulate.
- **Proportionality:** "simple tasks don't need a full PRD."
- **Best idea:** Proportional specs plus boundaries. He also observes that underspecifying leads to surprises, while overspecifying means you could have written the code yourself [S].

## 10. Kent Beck: augmented coding (the B+ tree)

- **Source [V]:** https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes
- **Process:**
  - A system prompt says: follow `plan.md`; on "go", implement the next unmarked test, then only enough code to pass it.
  - Strict red-green-refactor.
  - **Tidy First:** never mix structural and behavioural changes in one commit, and label each commit.
  - Commit only when all tests are green and there are no warnings.
- **Oversight:** Beck chose the next tests himself and watched intermediate output.
- **Warning signs he names:**
  1. loops;
  2. unrequested functionality;
  3. **cheating by disabling or deleting tests.**
- **Outcome:**
  - Over about 4 weeks, a correct and competitive Rust/Python B+ tree (BPlusTree3).
  - Beck is unhappy with its accidental complexity.
  - Stalled Rust work was rescued by writing Python first and having an agent transliterate it.
- **Best idea:** Augmented coding means holding the *same quality bar as hand coding*, with the plan as a list of tests.

## 11. Amp (Sourcegraph spin-off)

- **Earlier guidance [S]:** "200k Tokens Is Plenty" (https://ampcode.com/notes/200k-tokens-is-plenty) and the Context Management guide (https://ampcode.com/guides/context-management):
  - short threads that each do one thing;
  - **Handoff** distills a thread into a fresh one instead of compacting (https://ampcode.com/news/handoff);
  - threads can reference other threads.
- **2026 reversal [S, unverified]:** The "Amp, Rebuilt" post (https://ampcode.com/news/neo) reportedly **removed Handoff in favour of compaction**, citing the complexity of many linked threads. My fetch of that page failed, so this rests on a search summary.
- **Takeaway:** Even context-management *mechanisms* are model-era dependent, and the guides themselves carry "written for an earlier model" caveats.

## 12. Spec-driven development tools, and the main critique

Birgitta Böckeler (Thoughtworks), on Kiro, spec-kit and Tessl [V] (https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html):

- **Verbosity and review burden:** markdown that is "very verbose and tedious to review". "I'd rather review code than all these markdown files."
- **Agents ignored specs:** they produced duplicates from notes about existing classes and over-applied "constitution" rules.
- **Ceremony:** a small bug became 4 user stories with 16 acceptance criteria.
- **Lifecycle problems:** specs are tied to a branch, and regeneration from a spec is non-deterministic.
- **Historical warning:** spec-as-source echoes model-driven development, which failed.
- **Her closing question:** do these tools "amplify existing challenges like review overload and hallucinations"?

This is the most rigorous practitioner critique of over-documentation.

---

## Empirical evidence and critiques

- **METR RCT, 2025** (https://arxiv.org/pdf/2507.09089): 16 experienced OSS developers on their own repositories were **19% slower** with AI (CI +2% to +39%), while *believing* they were about 20% faster. The perception gap is the most durable finding.
- **METR follow-up, 2026-02-24 [V]** (https://metr.org/blog/2026-02-24-uplift-update/):
  - Scope: 57 developers, 143 repositories, 800+ tasks.
  - Returning developers: −18% (CI −38% to +9%); new recruits: −4% (CI −15% to +9%). Both are *speedups*, i.e. the slowdown has shrunk or reversed, and both intervals include zero.
  - METR calls the data unreliable:
    - 30–50% of developers withheld tasks they didn't want to do without AI;
    - pay was cut from $150/h to $50/h;
    - developers multitasking while agents ran broke time-tracking.
  - METR thinks developers are "likely more sped up" in early 2026, but calls its own data "very weak evidence". It is redesigning the study.
  - A related note argues per-issue RCTs miss agent concurrency (https://metr.org/notes/2026-02-17-exploratory-transcript-analysis-for-estimating-time-savings-from-coding-agents/).
- **DORA 2025** (https://research.google/pubs/dora-2025-state-of-ai-assisted-software-development-report/; summary at https://www.infoq.com/news/2025/09/dora-state-of-ai-in-dev-2025):
  - About 90% adoption; more than 80% perceive higher productivity.
  - AI now correlates positively with **throughput but instability keeps rising**.
  - "AI's primary role… is that of an amplifier" of existing org strengths and dysfunctions.
  - The AI Capabilities Model lists seven practices; I could not verify the full list (it includes clear AI policy, a healthy data ecosystem, quality internal platforms, user-centricity).
  - It is a self-selected survey.
  - Stack Overflow 2025, as cited there: 46% distrust AI output, 3% "highly trust".
- **Anthropic skill-formation RCT, 2026-01-29 [V]** (https://www.anthropic.com/research/AI-assistance-coding-skills; https://www.arxiv.org/pdf/2601.20245):
  - 52 mostly junior engineers learning the Trio library.
  - Quiz scores: AI group 50% vs 67% hand-coding (d≈0.74, p=0.01). The largest gap was in **debugging**.
  - The speed gain was not significant.
  - Pure delegation scored below 40%; conceptual-inquiry or "generate-then-comprehend" users scored 65% or higher (correlational, small n).
  - Relevance to process design: workflows where humans never read research or code erode the very skill needed to review it.
- **Vibe coding vs agentic engineering:**
  - Karpathy called vibe coding passé in February 2026 and promoted "agentic engineering" as the term [S] (https://thenewstack.io/vibe-coding-is-passe-karpathy-has-a-new-name-for-the-future-of-software/).
  - Willison's line is whether you read and own the code.
  - Beck's line is whether you hold the hand-coding quality bar.
  - Every's guide itself advises against vibe coding for production, security-sensitive or performance-critical systems.

---

## Synthesis

### Recurring principles

1. **Context is the scarce resource.** Every framework is built around it:
   - Anthropic's founding premise;
   - Horthy's 40–60% utilization and intentional compaction;
   - Ralph's fresh context per loop;
   - superpowers' fresh subagent per task;
   - Amp's short threads;
   - Osmani's per-task spec slices.

   The shared mechanics are fresh sessions, subagents for search, and on-disk artifacts as the hand-off medium. Specific thresholds ("dumb zone" at about 40%) are practitioner heuristics, not measured constants, and Amp's handoff → compaction reversal shows they drift with the model.
2. **Research before planning, kept separate from opinion.** Examples: RPI/QRSPI (QRSPI hides the ticket during research), Every's parallel researchers, Ralph's "search before assuming missing", Anthropic's Explore.
3. **Human review at the highest-leverage point, in small artifacts.** The consensus has moved: review the research and design, not 1,000-line plans. Supporting evidence:
   - Horthy's plan-reading illusion;
   - Böckeler preferring to review code over markdown;
   - superpowers v6.4.2 producing leaner plans and v7.0's "builder check" replacing document review.

   The 2026 position is a short design (about 200 lines) plus a structure/interface outline, a spot-checked plan, **and** a human still reads and owns the PR.
4. **Externalized state, and disposable plans.** Specs, tests and code are durable. Plans and todos are cheap and regenerable (Ralph discards `fix_plan.md`; Harper's `todo.md`; RPI compacts status into the plan). Drift is handled by making tests the arbiter and regenerating plans, rather than by maintaining documents in sync.
5. **Verification loops with independent grading.** TDD or backpressure is universal (Beck, superpowers, Ralph, Willison, Harper, Anthropic). The implementer should not grade itself: fresh-context reviewers, Stop hooks, conformance suites. Two known pathologies:
   - agents cheating on tests (Beck);
   - reviewers that always find something (Anthropic).
6. **Compounding knowledge, with pruning.** Every's `docs/solutions/`, AGENT.md self-updates in Ralph, CLAUDE.md "compounds" (Anthropic), Willison's hoarding. The counterweight comes from Anthropic ("bloated CLAUDE.md files cause Claude to ignore your actual instructions"), Osmani's curse of instructions, and Horthy's instruction-budget failure. Captured knowledge must be short, retrievable on demand, and periodically refreshed.
7. **Proportionality, to fight ceremony.** Anthropic ("describe the diff in one sentence → skip the plan"), Osmani ("simple tasks don't need a full PRD"), and Böckeler's 16-acceptance-criteria bug. Heavy pipelines (superpowers, compound engineering, QRSPI) are all *adding* lighter paths in 2026.

### Strength of evidence

- **Strongest (controlled studies):**
  - Self-perception of AI speedup is unreliable (METR, replicated in its own follow-up and survey). Measure outcomes; don't trust feel.
  - Passive delegation impairs comprehension and debugging skill (Anthropic RCT, small n). This supports workflows that keep humans engaged in research and design.
  - At the organizational level, AI amplifies existing practice, and instability rises without strong foundations (DORA; large but self-selected survey).
- **Moderate (broad convergence plus mechanistic plausibility, no RCTs):**
  - Executable verification and TDD as the backbone of agent loops: universal practitioner agreement and vendor guidance, but no controlled comparison of TDD vs non-TDD agent workflows that I found.
  - Context degradation with fill level: vendor-stated (Anthropic), with "curse of instructions" research cited by Osmani. Exact thresholds are unverified.
- **Weakest (anecdotal and often promotional):**
  - Specific multipliers: HumanLayer's 35k LOC in 7 hours, Every's 5–10×, the value of 14+ reviewer agents, and compounding-knowledge ROI.
  - No published outcome data compares teams using these frameworks against teams that don't.

**Bottom line for process design:** Invest first in executable verification, context hygiene and short reviewable design artifacts. Treat heavy documentation pipelines and agent swarms as unproven costs to scale up only where task size justifies them.

**Unverified items, flagged:**
- the exact "dumb zone" threshold;
- QRSPI details (secondary sources only);
- Amp's removal of Handoff (fetch failed);
- superpowers' spec path;
- the full list of DORA's seven capabilities;
- Huntley's critique of the official plugin (secondary sources only).
