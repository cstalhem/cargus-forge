---
adr: 004
title: Skills load on demand, and scripts fetch the facts
status: active
---

# ADR-004: Skills load on demand, and scripts fetch the facts

- **Decision:** Skills that orchestrate a phase run only when you type them. Skills that hold a reusable discipline are called by other skills. Each skill gets its facts from scripts that Claude Code runs before the model reads the skill. The plugin aims at about 1,500 lines of instructions in total.

## Details
- **Typed skills** (`disable-model-invocation: true`, so they cost no context until typed): `setup`, `discuss`, `execute`, `ship`, `next`, `autopilot`. `research` is not built (#200), and neither is the plan page (#201).
- **Called skills:** `slice`, `verify`. `reflect` is not built (#202). `grill`, `tdd` and `ste-writing` are not built and have no request.
- **Calls go one way.** A typed skill calls called skills. It never calls another typed skill. Autopilot starts a Build phase through a child session whose prompt is the typed `/engineering:execute #<n>` or `/engineering:ship #<u>` ([ADR-008](ADR-008-autopilot-builds-ready-issues-unattended.md)): the prompt types the skill, so execute keeps its required argument and `disable-model-invocation`, and no skill calls a typed skill.
- **Scripted facts:**
  - A line such as `` !`${CLAUDE_SKILL_DIR}/status.sh` `` runs when the skill is invoked, and the model sees only its output.
  - Each command is pre-approved in `allowed-tools`.
  - Scripts exit 0 and print errors as text, because a non-zero exit stops the skill.
  - Scripts use bash, `gh` and `jq`.
- **Size and placement:**
  - No skill body is longer than about 150 lines.
  - Critical rules go at the top, because only the start of a skill is restored after compaction.
  - The glossary rules live in `references/domain-model.md`, which discuss and execute read in their Load step instead of calling a skill.
  - Rules that several skills share live in `references/rules.md`. Each skill pulls it in with `` !`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"` `` as the first line of its Rules section, pre-approved in `allowed-tools`, so the rules are part of the skill body. A missing file stops a typed skill with no output, makes the Skill tool return the error for a called skill, and is not caught by `claude plugin validate`.
  - The plugin has no `CLAUDE.md`, because Claude Code does not load one from a plugin.
  - Facts about a repo live in `docs/agents/`, which skills read on demand.

## Rejected alternatives
- **All skills invoked by the model:** every description is always in context, and phases start without you.
- **execute invocable by the model, so that Autopilot could call it as a skill:** every description is always in context, and phases start without the user. A child session's typed prompt starts the phase instead.
- **The model fetches facts with tool calls:** it can skip a fact or fetch it a different way, and it uses more turns and context.
- **A large framework:** GSD core has about 95,000 lines of instructions and loads 35,000 to 40,000 tokens before its plan phase starts.

## Consequences
- Each new fact that a skill needs, needs a script, and each script needs a pre-approval line.
- The model cannot start a Build phase on its own. Autopilot can start one, through a child session whose prompt types the skill, and only once you created its scheduled task ([ADR-008](ADR-008-autopilot-builds-ready-issues-unattended.md)).
- Scripted facts work in Remote Control sessions.
