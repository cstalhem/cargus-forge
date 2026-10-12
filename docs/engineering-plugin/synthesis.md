---
title: "Engineering plugin: synthesis"
date: 2026-10-10
status: draft v4 — one open decision (PR flow); see sections 7–9
---

# Engineering plugin: synthesis

This is the synthesis of the seven research reports in `research/`. It has five parts: what we learned, the proposed workflow, where the proposal pushes back on the original brief, the open questions, and how to build it in stages.

- The interactive version is [the HTML plan](https://claude.ai/artifact/GiMwcbCXxzz1RaNmcDrHMr), a private artifact. Its source is `plan.html`.
- Packing that source into the published page needs the `html-plan` plugin's runtime. That plugin lives in `anthropics/claude-plugins-community`.

## 1. What we learned

### Source by source

| Source | Best idea to borrow | Its failure mode |
|---|---|---|
| **Matt Pocock** | The *grilling* primitive (Section 4 of `research/01`):<br>• questions come in rounds;<br>• each round asks every question whose earlier answers are already settled;<br>• each question carries a recommendation, so "yes" accepts it;<br>• facts are the agent's job, decisions are the user's.<br><br>Two kinds of skill: skills you invoke cost no context until typed; skills the model invokes carry the reusable rules.<br><br>A tracker indirection doc, so skills say "publish to the tracker" and a per-repo file defines what that means.<br><br>Test seams agreed up front, then reused in the spec, in TDD and in review. | `to-spec` and `to-tickets`:<br>• have no check on their input;<br>• have weak exit criteria (acceptance criteria that already passed at the base commit);<br>• have no step that closes a ticket.<br><br>State lives in one unbroken context window. |
| **GSD core** | Goal-backward verification. It assumes the summary is a claim, not evidence, and checks each must-have at three levels: exists → substantive → wired.<br><br>Executor deviation rules: rules 1–3 auto-fix; rule 4 asks before an architecture change.<br><br>Progress read from the files themselves (a PLAN with no SUMMARY means unfinished).<br><br>Pause hygiene: the uncommitted-files list is *measured*, never narrated. | About 95k lines of instructions. The plan phase loads 35–40k tokens into the "lean" orchestrator. About 15 files per phase and about 90 per milestone. Instructions grow by patch accretion. |
| **GSD path** | Task contracts:<br>• declared files;<br>• an interface contract shared between sibling tasks;<br>• one verify command that must fail if the task is skipped;<br>• `NEEDS-ORCHESTRATOR` instead of guessing.<br><br>Authority order, with "never average" conflicting sources.<br><br>Milestones archived at the boundary.<br><br>Wave ordering: risk burn-down first, then the thinnest end-to-end slice. | It measured itself at 8.7× the tokens of direct coding on a small task. It is essentially a solo project with 27 stars. |
| **Karpathy and Thariq** | ASD-STE100 at about 80% for output humans must review.<br><br>Diagrams and HTML as the review medium.<br><br>The "unknowns" field guide: four quadrants, a blind-spot pass, prototypes, interviews, source code as the reference, plans that lead with the decisions you are most likely to change.<br><br>`implementation-notes.md` deviations, and a quiz before merge.<br><br>Session hygiene: a new session per task, rewind instead of correcting, a subagent when you only need the conclusion. | Over-tooling. Thariq warned against a `/html` skill, then shipped one once the components saved tokens. |
| **html-plan** | The plan is a tree of claims, split by behaviour, with one exhibit per claim. Decisions sit on the claim they change and come with defaults.<br><br>The reader sends back one structured response. That response is data, not instructions.<br><br>Lint catches the known failure modes. | Each packed page carries a 209 KB runtime. |
| **Spec-driven toolkits** (Spec Kit, Kiro, OpenSpec, BMAD, Agent OS, Tessl) | WHEN/THEN or EARS acceptance criteria.<br><br>A converge pass: code against spec, with gaps turned into tasks.<br><br>OpenSpec's delta specs, merged into a small living spec. | Böckeler: "I'd rather review code than all these markdown files." A small bug became 16 acceptance criteria. Every toolkit is retreating to lighter defaults in 2026. Tessl has pivoted away from spec-as-source. |
| **Practitioners** (HumanLayer, Huntley, Superpowers, Every, Anthropic) | Review the research and design, not 1,000-line plans.<br><br>Plans are disposable; specs, tests and decisions last.<br><br>The implementer never grades itself.<br><br>An explicit "compound" step that feeds lessons back into the setup. | Horthy's correction of his own earlier advice: "A 1,000-line plan contains as many surprises as 1,000 lines of code." |
| **Evidence** | METR: developers' own sense of speedup is unreliable.<br><br>Anthropic's 2026 trial: pure delegation weakened understanding, most of all debugging, while conceptual inquiry kept it.<br><br>DORA: AI amplifies existing practice. | No controlled study shows that heavy spec toolkits beat plan mode plus tests. |

### What the Claude Code docs change (v2.1.296, `research/03`)

- **Remote Control** has a diff pane but no plan or file viewer.
  - Artifacts are the way to read plans on a phone.
  - `claude remote-control` sessions can publish them from v2.1.281.
- **Mods** draw only in the local terminal, so they never reach the phone. They are out of scope.
- **State** belongs in `${CLAUDE_PLUGIN_DATA}`, which survives updates.
  - A `CLAUDE.md` inside a plugin is never loaded.
  - The Task tools (formerly TodoWrite) are off by default on Claude 5 models.
- **After compaction**, skill bodies come back at most 5k tokens each and 25k in total. Critical instructions go at the top of each skill.
- **Plugins** can ship `workflows/`, for parallel research and adversarial verification.
- **`claude plugin eval`** compares a run with the plugin against a run without it.

A provenance note: a codecentric write-up says the original GSD repo "can no longer be trusted" after an ownership and meme-coin incident (source only, not verified; see `research/07`).

## 2. Seven principles the sources agree on

1. **Context is the budget.** Start a fresh session per phase, and hand work over through files and issues, not chat history.
2. **Research before planning.** Facts are the agent's job; decisions are the user's.
3. **Review the smallest, highest-leverage artifact.** That is a short design with its decisions, not a long plan.
4. **Separate what lasts from what is disposable.** ADRs, the glossary, tests and issues last. Plans and notes are disposable.
5. **The implementer never grades itself.** Tests give backpressure, and a separate agent checks the work against the goal.
6. **Size the ceremony after a short investigation.** If you can describe the diff in one sentence, skip the plan.
7. **Compound, and prune.** Captured knowledge stays short, is retrieved on demand, and gets refreshed.

## 3. Proposed workflow (draft)

```
setup (once per repo)
  │
  ▼
size check ── trivial ──► do it ──► ship
  │ one session ──► issue as spec ──► execute ──► verify ──► ship
  │ multi-session
  ▼
discuss ─► research ─► plan ─► to-issues ─► [execute ─► verify]×N ─► converge ─► ship
 grill +    parallel    HTML     umbrella +        fresh session each           gaps → new
 unknowns   code + ext  page,    sub-issues                                     sub-issues
 pass       research    STE
```

### Where state lives

- **GitHub** is the only cross-session state.
  - **Umbrella issue:** the goal, WHEN/THEN scenarios, decisions, what is out of scope, open questions, and a stop note updated at session end.
  - **Sub-issues:** each fits one session, has blocking edges, acceptance criteria and one verify command.
  - **`next`** reads the open issues and says where you stopped.
- **The repo** holds only knowledge that lasts:
  - ADRs, following the adr-management doctrine;
  - `GLOSSARY.md`;
  - a short `docs/agents/` profile (commands, tracker, checks).
- **Nowhere else.** There is no `.planning/` folder and no STATE.md. Plans are artifacts, and their decisions are copied into the umbrella issue and ADRs.

### Skills

- **Skills the model invokes** hold the reusable discipline: `grill`, `domain-model` (glossary and ADRs), `tdd` (at agreed seams), `verify` (goal-backward), `ste-writing`.
- **Skills you type** cost no context until you call them: `setup`, `discuss`, `research`, `plan`, `to-issues`, `execute`, `ship`, `next`. Later stages add `diagnose` and `improve-architecture`.
- **Budget:** about 1,500 instruction lines in total, with no skill body over about 150. `claude plugin eval` proves each skill's value.

### Guardrails and compounding

- `setup` audits the repo's checks (pre-commit hooks, CI, the test runner, linters) and offers to add the missing ones.
- `ship` ends with a short pass that asks what the setup should change. This generalises the existing push-time reflection hook.

### Learning

- `discuss` always ends with a blind-spot pass that maps known and unknown unknowns.
- `verify` can end with a quiz on the change.

## 4. Where the proposal challenges the brief

- **"Every feature backed by research" must scale.** Research on every bug rebuilds GSD. Run it after the size check.
- **STE everywhere would hurt the conversation.** Use it at about 80% for artifacts (plans, issues, ADRs) and keep normal prose in chat.
- **Don't commit plans.** HTML diffs are noisy and plans go stale by design. What lasts goes into issues and ADRs. This first plan is the exception, kept with the research.

## 5. Open questions

The plan carries these as five decisions. The first five below are those decisions; the rest wait for the stage that needs them.

1. **State store.** GitHub issues only, behind one tracker profile file? *Recommended: yes. Are all repos on GitHub, with `gh` working on the always-on host?*
2. **html-plan.** Depend on it, copy and adapt it (MIT), or write a lighter page of our own? *Recommended: depend on it, and replace it only if it hurts.* Note that a dependency on another marketplace needs `allowCrossMarketplaceDependenciesOn` in `marketplace.json`.
3. **The old plugins.** Does engineering take over knowledge-system and adr-management, which are then deprecated? *Recommended: yes. Otherwise two skills answer the same ADR trigger.*
4. **When research runs.** *Recommended: only on the long path, after the size check.*
5. **Where to start.** *Recommended: the contract first, then a thin end-to-end path* (Section 6).
6. **Solo or team?** This changes review and the issue templates. *Decided at stage 1.*
7. **Autonomy.** Do Routines or parallel workflow runs work on sub-issues unattended? *Recommended: start each ticket by hand at first. Decided at stage 5.*
8. **Codex second opinion** as an optional verifier. *Decided at stage 5.*
9. **Stacks** that `setup` equips first. *Decided at stage 4.*
10. **Plugin name.** The default is `engineering`. *Decided at stage 0.*

## 6. How to build it: stages

The question was: is it right to start from the work process and the architecture that follows from it?

**Yes, with two adjustments.**

1. **Specify the process as contracts at the seams, not as descriptions of phases.**
   - For each phase, write down what it *gets*, what it *gives*, where the output is *stored*, its *exit gate*, and when it *stops to ask*.
   - The seams are the architecture: the umbrella issue format, the sub-issue format, the ADR and glossary, the repo profile.
   - The skills are replaceable behind those seams.
   - This applies Matt Pocock's "test at the seams" and GSD path's task contract to the plugin itself.
2. **After the contracts, build vertically, not phase by phase.**
   - Building `discuss` perfectly first and `ship` last is horizontal slicing. The handoff faults only show up once the last phase exists.
   - So stage 1 is a walking skeleton: the one-session path from `setup` to a merged PR, on a real issue in this repo.

Two practices run through every stage:

- **Dogfooding.** The plugin build is the first umbrella issue, with one sub-issue per stage, once the state-store decision is made. That tests the state model at once.
- **Measurement from day one.** Every stage adds `claude plugin eval` cases, and each release bumps the version.

| Stage | Scope | Done when |
|---|---|---|
| **0 · Contract** | Answer the decisions. Write `process.md`, one contract per phase. Write the first ADRs: state store, skill invocation model, plan format, writing standard, relationship to the old plugins. | No plugin code exists. The contracts and ADRs are reviewed. |
| **1 · Skeleton** | Scaffold the plugin, then `setup` (repo profile), `execute` (one issue, TDD, deviation rules, closes the issue), `verify` (goal-backward), `ship` (PR and reflection).<br><br>Dogfood issue: CI for cargus-forge. It runs `claude plugin validate --strict`, checks that descriptions match, and checks for a version bump. Three plugins have drifting descriptions today, so the CI fails at first. | One real issue goes from setup to a merged PR using only the plugin. The eval cases pass. |
| **2 · Front end** | `grill`, `discuss` (with the unknowns map), `domain-model` (the adr-management doctrine and the glossary), `ste-writing`. | One discuss session leaves a correct umbrella-issue draft, ADRs and glossary entries. |
| **3 · Long path** | `research` (parallel, cited), `plan` (HTML artifact), `to-issues` (umbrella, sub-issues, blocking edges), `next` (resume), converge pass. | A multi-session feature can be resumed from the phone via `next`. |
| **4 · Guardrails and compounding** | `setup` audits and adds hooks, CI and tests for the chosen stacks. A reflection hook runs after push. A retro feeds lessons into rules and skills. | A fresh repo gets working checks from `setup`. |
| **5 · By need** | `diagnose`, `improve-architecture`, an optional Codex verifier, the quiz, parallel execution via workflows, unattended runs. | Each addition has an eval case and a real use. |

### Alternatives considered

- **Phases in order, starting with discuss.** It feels natural, but the handoff faults appear only when the last phase is built. That is the most expensive moment to find them.
- **The thinking front end first** (`grill`), so it can help design the rest. Grill is cheap: Matt's version is 30 lines. We can still use it informally from stage 0 without building it first.
- **Guardrails first** (CI and pre-commit). These are valuable, but they are generic. They show up in stage 1 as the dogfood issue rather than as a stage of their own.

## 7. Review 1: decisions and what changed (plan v2)

The response to plan v1 is saved word for word in `responses/v1-response.md`. All five recommendations were kept. The fifth decision (where to start) was not opened, so it stands as a default rather than a confirmed choice.

### Decisions made

| # | Decision | Answer |
|---|---|---|
| 1 | When research runs | Only on the long path, after the size check |
| 2 | State store | GitHub issues only, through one tracker profile |
| 3 | HTML plans | Depend on the `html-plan` plugin |
| 4 | Old plugins | Engineering takes over knowledge-system and adr-management. They are deprecated later. |
| 5 | Start | The contract first, then one thin end-to-end path (default; not opened) |

### What each comment changed

**Size check vs. the long path (comments on claims 1 and 1.1).**
- v1 drew two separate diagrams and never showed how they connect. The comment was right: slicing between plan and issues *is* a size check.
- v2 has **one size test, applied in three places**. An issue fits one session when all four hold:
  1. It delivers one behaviour you can demo or test on its own.
  2. One verify command proves it, and that command fails before the work.
  3. After a short read, the agent can name every file it changes.
  4. It has no open design question.
- The three places:
  - **Intake** routes the request: pass → one issue; fail → the front end.
  - **Slice** (to-issues) splits the work until every sub-issue passes.
  - **Execute** stops and sends an issue back to slice if it turns out to fail the test (deviation rule 5).
- As a result, the one-session path is no longer a separate path. It is the same **loop** (execute → verify → merge) that every sub-issue runs. The front end (discuss → research → plan → slice) exists only to produce issues that pass the size test.

**Grading placement (comment on claim 1.4).**
- v1 grouped claims by topic, but the reader reads siblings as a sequence, which was misleading.
- v2 orders the process claims chronologically. Verify now sits inside the loop, after execute, once per issue.

**State without status text (comment on claim 2.3).**
- The stop note is gone. Every status is *derived* from facts GitHub and git record:
  - **done:** the issue is closed by its PR.
  - **blocked:** a GitHub "blocked by" link points to an open issue.
  - **active:** the issue has a linked branch (created by `gh issue develop`) or an open PR.
  - **ready:** none of the above.
- How "next" is chosen:
  1. If the current branch links an issue, resume that issue.
  2. Otherwise, list the ready issues per open umbrella, and you pick.
- This follows GSD's "measured, never narrated" rule.
- **New decision:** how to run parallel features. Recommended: one worktree per active issue, which Remote Control's `--spawn worktree` supports.
- The `/next` mockup now explains itself: it shows the branch-to-issue link and labelled status groups.
- **Spike in stage 0:** confirm that `gh` can read sub-issues and "blocked by" links (via `gh api graphql`).

**`docs/agents/` (comment on claim 2.4).** v2 shows two examples:
- `commands.md`: install, test all, test one, typecheck, lint, run, the pre-PR check.
- `issue-tracker.md`: repo, umbrella label, blocking links, branch naming, PR closing keywords, priority.
- Why a separate folder: `CLAUDE.md` loads in every session, while skills read these files only on demand. `CLAUDE.md` gets a one-line pointer.

**`tests/` and the grading report (comment on claim 2.4).** These are two different things:
- **The project's own tests are committed** and last forever. The WHEN/THEN scenarios become real tests there, which is what "tests are the judge of done" means.
- **The verify report** is per-issue and not committed. It is posted as a **PR comment**, so it stays attached to the change, is readable on the phone, and leaves no files behind.

**Cross-marketplace dependency (comment on claim 3).** This is possible, and the docs describe it (`research/03` and the plugin dependencies page):
- `plugin.json` declares `"dependencies": ["html-plan@claude-community"]`. `claude-community` is the marketplace name in `anthropics/claude-plugins-community`.
- The root `marketplace.json` adds `"allowCrossMarketplaceDependenciesOn": ["claude-community"]`. Without it, the install skips html-plan and engineering fails to load.
- Do not set a version range. html-plan has no release tags, so a range would only disable our plugin.
- Open point: the docs do not say whether `claude-community` must already be added on the machine. A test install in stage 1 answers it.

**STE 20-word limit (comment on claim 3.1).**
- No hard enforcement. STE rules become defaults, and the lengths become targets.
- html-plan's linter only *warns* (at 25 words), and nothing blocks.
- **New decision:** strictness. Recommended: rules as defaults, lengths as targets.

**Orphaned plan pages (comment on claim 3.3).** Each plan page now has a lifecycle:
1. `plan` publishes it, and revisions update the same link.
2. `to-issues` writes the link into the umbrella issue.
3. When the umbrella closes, `ship` asks you to confirm and deletes the page. Artifact deletes always need your confirmation.

Two supporting rules:
- `/next` also lists plan pages whose umbrella is closed, which catches abandoned work.
- **New decision:** when a page goes away. Recommended: when the umbrella closes.
- Technical note for stage 3: to revise a plan in a later session, the plan's *source* must be retrievable. Publish the source as a supporting file of the artifact, rather than keeping it in local state.

**Evals (comment on claim 2.2).**
- Parked for their own discussion before stage 1 ends.
- The sub-issue example now uses a plain test command instead of `claude plugin eval`.

### Consequences for the stages

- **Stage 0** grows. It now covers:
  - the size test;
  - the phase contracts;
  - the status-derivation rules;
  - the plan-page lifecycle;
  - the first ADRs;
  - a `gh` spike for sub-issues and blocking links.
- **Stage 1:** `execute` claims an issue by creating a linked branch, because the derived state depends on it. The test install of the html-plan dependency also happens here.
- **Stage 3:** `next` (status derivation and orphan listing) and plan-page deletion in `ship`.
- **Open topics:**
  - evals (before stage 1 ends);
  - the plugin name (stage 0);
  - solo or team (stage 1);
  - stacks (stage 4);
  - autonomy and Codex (stage 5).

## 8. Review 2: decisions and what changed (plan v3)

The response to plan v2 is saved in `responses/v2-response.md`. All three recommendations were kept:

| Decision | Answer |
|---|---|
| Parallel features | One worktree per active issue |
| STE strictness | STE rules are defaults; sentence lengths are targets |
| Plan-page cleanup | Deleted when the umbrella issue closes, after confirmation |

### What each comment changed

**"Front end" was the wrong word.** It collides with front-end development.
- The two halves of the process are now **Shape** (discuss → research → plan → slice) and **Build** (execute → verify → merge).
- The terms come from Basecamp's *Shape Up*, a known practice, rather than invented vocabulary.

**Where discuss output goes, and why slicing is separate.** The plan never said where Shape's output lands. It now does: **everything goes into one umbrella issue.**
- **discuss** creates the umbrella issue: goal, WHEN/THEN scenarios (these *are* the acceptance criteria), decisions, and out of scope. It also writes ADRs and glossary terms to the repo.
- **research** adds one comment with cited notes to the umbrella.
- **plan** publishes the page, and your answers go into the umbrella's decisions.
- **slice** creates the sub-issues. Each gets its share of the scenarios, plus "blocked by" links and status labels.

Slicing is a separate step for three reasons:
1. It needs the plan, because you cut along the modules and seams that the plan decides.
2. Execute re-enters it under rule 5, long after discuss has finished.
3. It is the single owner of GitHub structure (sub-issues and links).

It is no longer a command you type. It is renamed from `to-issues` to `slice`, plan calls it after your answers, and execute calls it under rule 5.

**Converge vs. verify.** The question exposed redundancy, and they merge.
- Converge was "verify on a larger scope". There is now **one verify skill with two scopes**:
  - **issue scope:** at PR time, against that issue's scenarios;
  - **umbrella scope:** when the last sub-issue merges, against the umbrella's scenarios on `main`.
- Umbrella scope catches what no single issue owned. Example: cancel stops the job (#41), and the upload belongs to #39, so nobody cleaned up the partial file.
- Gaps found there go through slice and become new sub-issues.
- The plugin drops from 14 skills to 13.

**The disconnected second diagram, and the "to verify" label.**
- "Loop / to verify" meant "execute *through* verify", and it read like a destination.
- The diagram is replaced by a **read/write table** that uses the same phase names as the process diagram: for each phase, what it reads and what it writes. This is a preview of the stage 0 contract.

**/next looked like a separate CLI.**
- The mockup now shows the real UI: you type `/engineering:next` in Claude Code, and Claude replies in the conversation.
- That reply looks the same in the terminal, the desktop app, and Remote Control on the phone.
- A small script inside the skill (`status.ts`) reads GitHub, so the result is deterministic. Claude only explains it.

**Status labels on GitHub.** The user wants the status to be visible when browsing issues on GitHub. This is adopted, and it refines the "derived, never written" rule rather than replacing it:
- Labels: `status: ready | active | review | blocked`. Closed issues lose their status label.
- **The facts stay the truth.** These are: closed by a PR, a "blocked by" link to an open issue, a linked branch, and whether the PR is a draft.
- **Labels are a projection, set only by automation.**
  - slice sets ready or blocked;
  - execute sets active;
  - verify sets review when it passes, by marking the PR ready;
  - `/next` recomputes every status and repairs labels that drift, for example after a manual merge.
- **New decision:** what keeps the labels correct. Recommended: skills set them and `/next` repairs drift. A GitHub Action that reconciles labels from events can follow in stage 4, after a spike to check which events Actions can see.
- **Setup consequence:** `setup` creates the status labels in each repo, and `issue-tracker.md` documents them.

### Consequences for the stages
- **Stage 0:** the contract now includes the status-label rules and the reconcile logic.
- **Stage 1** (renamed "Build"): `execute` creates a worktree and a linked branch and sets `status: active`. `verify` marks the PR ready and sets `status: review`. `setup` creates the labels.
- **Stage 3** ("Shape, part 2"): `slice` and umbrella-scope `verify` replace `to-issues` and `converge`.

## 9. Review 3: what changed (plan v4)

The comments are saved in `responses/v3-comments.md`. **Shape → Build** is confirmed as the vocabulary.

### PR flow: a decision that had been left implicit

v3 said "verify on each PR". That implied one PR per sub-issue without ever deciding it. The user expected one PR per umbrella. The three options:

| Option | Branches | Consequences |
|---|---|---|
| **One PR per sub-issue into main** (recommended) | `39-export-job` → `main` | • Small PRs that are easy to review on a phone.<br>• `Closes #n` works, because GitHub closing keywords fire only on PRs into the default branch.<br>• One worktree per issue (already decided) fits.<br>• Trunk-based, small-batch flow, which DORA's research consistently links to delivery performance.<br>• Cost: half a feature can sit on main. Mitigation: size test 1 makes each slice useful on its own, and a slice that would expose unfinished UI hides behind a flag. |
| Feature branch per umbrella | `39-export-job` → `38-export-to-s3` → `main` | • main only ever sees whole features.<br>• Two levels of PRs.<br>• Closing keywords don't fire on PRs into the feature branch, so `ship` must close sub-issues itself (more mechanics).<br>• The long-lived branch drifts from main. |
| One branch and PR per umbrella | `38-export-to-s3` → `main` | • One big review.<br>• A branch can't be checked out in two worktrees, so sub-issues of one feature run one after another.<br>• The verify report goes on the sub-issue, because there is no PR to put it on. |

The plan carries this as a decision with recommended option 1. Under option 1:
- issue-scope verify runs on each sub-issue's PR into `main`;
- umbrella-scope verify runs on `main` after the last sub-issue PR merges;
- the umbrella stays open until that check passes, and then `ship` closes it, which in turn triggers the plan-page cleanup.

### The /next script runs deterministically

The script is not something the model may or may not call. It uses **dynamic context injection**: a line of the form `` !`${CLAUDE_SKILL_DIR}/status.sh --fix-labels` `` in `SKILL.md`.
- Claude Code runs it at invocation, *before* the model sees the skill.
- The model only receives the output, and the skill tells it not to query GitHub again.

Constraints from the docs (`research/03`):
- The command must be pre-approved in `allowed-tools`, for example `Bash(${CLAUDE_SKILL_DIR}/status.sh *)`. Otherwise the invocation aborts.
- A non-zero exit aborts the skill, so the script always exits 0 and prints errors as text.
- Each command has a 2-minute timeout.

This becomes a **general pattern**: scripts fetch facts, the model judges.
- `execute` injects the issue (`gh issue view … --json`) and `docs/agents/commands.md` the same way.
- This also saves turns and context.

The script language is bash with `gh` and `jq`, so there is no extra runtime. `gh` v2.94.0 added JSON fields and flags for parent, sub-issues and dependencies (the GitHub changelog of 2026-06-10). `setup` checks the `gh` version.

### Labels cut to two

GitHub already shows:
- **blocked:** a "Blocked" icon on the Issues page, and the filters `is:blocked`, `is:blocking`, `blocked-by:` (GitHub docs and the 2025-08-21 changelog). The docs state no plan restriction but do not confirm the free plan. The stage 0 spike checks it on the user's private repos.
- **done:** the issue is closed.

So only two labels remain, for what GitHub does not show in the issue list:

| Label | Set by (its only option) | Meaning |
|---|---|---|
| `status: in progress` | `execute`, when it claims the issue | A session works on it |
| `status: needs review` | `verify`, on pass; this replaces "in progress" | It waits for you. Filtering on this label is your review queue. |

- No label means ready.
- Labels left on closed issues do no harm, because every list uses `is:open`.
- `slice` sets no label.
- `status.sh` repairs drift on open issues.
- No GitHub Action. The user does not want one, and drift repair covers the gap.

### Smaller changes
- The read/write table now names the PR target and which labels each phase writes.
- The `/next` reply mock adds a "Review" row.
- The skill tree adds `next/status.sh`.
- A new claim (4.2) covers the "scripts fetch the facts" pattern.
- The stage 0 spike now tests three things:
  - `gh` 2.94+ relationship data;
  - the Blocked icon on the user's plan;
  - a dynamic-context script under Remote Control.

### Note on the plan's own size

The page is now about 860 words of prose, against html-plan's budget of 350. It is outgrowing its format, which is the same bloat this plugin is meant to avoid. Once the remaining decision is made, stage 0 replaces this page with `process.md` (the phase contracts) and ADRs. The plan then stops growing.
