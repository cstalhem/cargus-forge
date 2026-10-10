---
title: "Engineering plugin: synthesis"
date: 2026-10-10
status: draft, waiting on the five decisions in the plan
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
