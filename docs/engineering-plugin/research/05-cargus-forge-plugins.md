---
title: "Research: existing cargus-forge plugins"
date: 2026-10-10
source: research subagent report, unedited
---

> Research subagent report from 2026-10-10, saved unedited. Paths under `/tmp/claude-1000/...` point to an ephemeral scratchpad and no longer exist.

# cargus-forge survey (repo root: /home/calle/projects/cargus-forge)

## Repo state
- **Branches:** local `main` only. Remote branches: `origin/main` plus four `origin/codex/*` branches, all of them obsidian/meeting work (`add-meeting-process-command-for-obsidian`, `convert-command-to-skill-and-outline-script`, `fix-unexpected-eof-error-in-script`, `github-mention-plugin-obsidian-add-argument-hints-to-/proce`). **No `plugins/engineering` directory exists and no engineering branch exists.**
- **Last 20 commits (newest first):** 0090fd9 Bump version, e90f064 Allow model to run skill on demand, e36a941 Fix README index, 8c9a2c9 Bootstrap repo knowledge system (L1/L2/L3), 1ba51c8 Add push-time knowledge reflection hook (3.2.0), d9de774 Align knowledge-system with docs, 89fb68f codex-review no HTML companion by default, a0b0087 Add adr-management, 3a64357/2ea66af/a0bf845 codex-review add + redesign (propose-and-verify), then obsidian work.
- **Missing:** no `.github/` (no CI), no `.claude/settings.json`, no project hooks in `.claude/`, no knowledge-system README. `.gitignore` holds only `__pycache__/` and `.DS_Store`.

## Root files
- **`CLAUDE.md` (70 lines):**
  - Repo layout: `plugins/<name>/.claude-plugin/plugin.json`, plus `skills/`, `agents/` and `hooks/hooks.json`, which are auto-discovered.
  - Dev loop: `claude --plugin-dir ./plugins/<name>`, `/reload-plugins`, `claude plugin validate ./plugins/<name> [--strict]`.
  - Defers component authoring to the installed `plugin-dev` plugin.
  - The second half is the knowledge-system template copied word for word (three tiers, staging, critical patterns, checkpoints, a 5-step update decision tree, cross-referencing, proactive maintenance).
- **`README.md` (19 lines):** plugin index plus a todo list of plugin ideas.
- **`.claude-plugin/marketplace.json` (29 lines):** owner "Carl Stålhem", 4 plugins.
  - Its descriptions **disagree** with the `plugin.json` descriptions for knowledge-system, codex-review and adr-management. This breaks the repo's own "keep descriptions identical" rule.
- **`.claude/rules/conventions.md` (21 lines):**
  - Bump the SemVer `version` in the same commit as the change.
  - Register a new plugin in both marketplace.json and the README; keep descriptions identical in plugin.json, marketplace.json and README; `source` must point to the real dir.
  - `author` is `{name, url}`.
  - Branch from main, rebase-merge, validate before the PR.
- **`.claude/rules/critical-patterns.md` (44 lines):** one WRONG/CORRECT entry: shipping without a version bump is a silent no-op, because Claude Code caches by version string.
- **`.claude/skills/plugin-release/SKILL.md` (28 lines):**
  - Steps: validate, bump version, sync descriptions, branch/commit, push/PR, rebase-merge.
  - Anti-patterns: a missing version bump; `git push`/`gh` hanging or getting publickey errors inside the sandbox (fix: run them unsandboxed, don't rewrite the remote to HTTPS).

## Plugin: knowledge-system (v3.2.1, 638 lines total)
**Purpose:** set up and maintain a three-tier project knowledge system (L1 `CLAUDE.md`/`AGENTS.md`, L2 `.claude/rules/`, L3 `.claude/skills/`), with retrieval, promotion and self-healing.

**Files:** plugin.json (9), hooks/hooks.json (28), hooks/retrieve-on-start.sh (7), hooks/reflect-on-push.sh (21), skills/init/SKILL.md (292), init/references/knowledge-system-template.md (45), memory-staging-template.md (43), critical-patterns-template.md (30), skills/retrieve/SKILL.md (53), skills/promote/SKILL.md (69), skills/heal/SKILL.md (71).

**Hooks**
- **SessionStart** (matcher `*`, 5s timeout): echoes "run the retrieve-knowledge skill…" into the context.
- **PostToolUse(Bash)** `reflect-on-push.sh`:
  - Reads the payload from stdin and greps for `git\s+push` or `gh\s+pr\s+create`.
  - On a match it emits `hookSpecificOutput.additionalContext`: "Work was just published. Reflect on whether anything… warrants a knowledge-system update — rule, skill, critical pattern, or staging entry. If so capture and commit as a follow-up."
  - Every other Bash command is a no-op. It fires only after the command succeeds.

**Skills**
- **`init-memory`** (dir `init`; opus, `context: fork`, `agent: general-purpose`, `disable-model-invocation: true`; tools include Agent, WebSearch, WebFetch, AskUserQuestion, TaskCreate). Five phases:
  1. Project scan with 4 parallel Explore subagents (structure, existing docs, tech stack, code conventions). Builds a profile and classifies the project as greenfield, partial, existing or foreign-ai-config.
  2. Gap analysis and interview, adapted to the classification:
     - Greenfield: 3–4 AskUserQuestion rounds (purpose, environment/conventions, gotchas, whether to share an AGENTS.md via symlink or `@AGENTS.md`).
     - Partial: a migration map. Existing: offer an audit instead. Foreign config: migrate but never delete the originals.
     - Also covers staging analysis and monorepo path-scoped rules.
  3. Stack research with parallel web subagents, one per technology. Filter: "Would Claude plausibly make this mistake without the rule?"
  4. Plan presentation (L1 outline, L2 rules grouped by file with `paths:`, L3 skills listed with description and when_to_use). Approval options: full plan, L1+L2 only, or modify.
  5. Implementation: create dirs; write rules (one line each, start with a verb, no code, no rationale, `##` groups); write skills (frontmatter `name`/`description`/`when_to_use`; sections Key Patterns, Anti-Patterns in "what went wrong / why / fix" form, Decision Aids); insert the template into L1 with `{L1_FILE}` substituted; note the staging convention (no files created); write critical-patterns.md from its template; print a summary.
- **`retrieve-knowledge`** (sonnet; Read/Grep/Glob; `user-invocable: false`). Process:
  - Extract keywords from the task.
  - Grep rules for matching lines.
  - Read only the `description` frontmatter of each skill.
  - Check the `- [staging:` index lines in MEMORY.md, without opening the staging files.
  - Return a summary of rules, critical patterns, skills and staging entries (flagged as unvalidated). Don't force matches.
- **`promote-staging`** (sonnet; `user-invocable: false`). Process:
  - Find the staging index lines and read the files.
  - A candidate is ready if it is tagged `[promotion-candidate]`, has recurred in 2+ sessions, or is actionable.
  - Ask the user per entry: rule, skill, critical pattern, keep, or discard.
  - Execute; add a `(see skill: x)` cross-reference to promoted rules.
  - Delete the file and its index line when an entry is promoted or discarded.
- **`heal-knowledge`** (sonnet; `argument-hint`). Process:
  - Detection signals: tests fail after following a rule, a lint/type error comes from a skill's pattern, the user corrects behaviour, or a rule contradicts what the project actually does.
  - Severity: **critical** (build, data loss, security, silent failure) gets a proposed diff, AskUserQuestion approval, the fix, and optionally a critical-pattern entry. **Minor** becomes a staging file.

**Conventions**
- Staging files are `staging_<slug>.md` in the auto-memory directory. Frontmatter: `name`, `description: "[staging] [type:gotcha|pattern|decision] [area:x] summary"`, `type: project`.
- Index line format: `- [staging: name](staging_slug.md) — [type] [area:x] summary`.
- Writing rule: entries are durable facts plus a reason; no session narration or phase/plan numbers; rules stay one line and link to a skill.

**Quirks**
- The heal skill text says `/heal`, but the skill is named `heal-knowledge`.
- The dir/name mismatch (`init` vs `init-memory`).
- `retrieve`/`promote` are `user-invocable:false` and depend on the model invoking them.

## Plugin: adr-management (v1.0.0, 428 lines)
**Purpose:** ADRs as living documents. **Files:** plugin.json (9), skills/adr-management/SKILL.md (216, model-invoked; the description is a list of trigger phrases), references/best-practices.md (203).

**Process**
- **Convention resolution:**
  - Fast path: glob `docs/adr/`, `docs/decisions/`, `docs/architecture/decisions/`, `adr/`; if ADRs exist, match their pattern.
  - Slow path: default to `docs/adr/ADR-NNN-<kebab>.md` with a `README.md` index table. The first ADR then becomes the convention, so there is no config file.
- **Companion files:** design docs go in `docs/designs/`. Glossary alignment: if `GLOSSARY.md`/`CONTEXT.md` exists, use its terms and update it in the same edit.
- **Core principles:**
  - One ADR per decision area, and it must have rejected alternatives.
  - Living document: edit in place; a reversed choice moves to Rejected alternatives; git is the changelog; no "amended by" notes.
  - Written as current-fact statements with no narration.
  - Not a design guide: readable in about 5 minutes.
- **Litmus test (4 checks):** clear one-sentence decision, real trade-off, hard to reverse, surprising without context. Adapted from Matt Pocock's grill-with-docs.
- **Edit-or-new table**, keyed on "does it answer the same question?":
  - Refinement: edit in place.
  - Reversal: rewrite, and move the old approach to Rejected alternatives.
  - New question: new ADR, and edit any ADR it narrows.
  - Obsolete: `status: deprecated` with one line. Numbers are never reused.
- **Create steps:**
  1. Next number via `ls … | tail -1`.
  2. Write from the template: frontmatter `adr`, `title`, `status: active|deprecated`; H1 `ADR-NNN: Title`; bullets Decision / Builds on / Design notes; optional subsections. Slug is ASCII, ≤40 chars, frozen. Add a row to the README index.
  3. Length check: simple 4–15 lines, moderate 20–45, complex 60–100; above ~100, move detail to a design doc.
  4. Keep related ADRs currently true.
  5. Update any open-questions log ("Addressed by ADR-NNN").
- **best-practices.md:** sources (AWS, GCP, Azure, Fowler, adr.github.io), what qualifies / when to skip, living vs immutable model (prefer immutable for compliance, readers outside git, or large orgs), ADR vs design-doc table.

## Plugin: codex-review (v1.1.1, 191 lines)
**Purpose:** a second-opinion plan review by OpenAI Codex CLI, run in a loop. **Files:** plugin.json (9), README.md (28), skills/review/SKILL.md (105; `context: fork`, `disable-model-invocation`, `argument-hint <plan-file>`, tools Bash/Read/Edit/Write), skills/review/schema.json (49).

**Process**
- **Setup:**
  - Resolve PLAN and only ever edit that file. If it is generated or has a generated companion, edit the source and flag the companion for regeneration.
  - Create a scratch file with `mktemp "${TMPDIR:-/tmp}/codex-review.XXXXXX"` (the X's go at the end, for BSD).
  - Read only the `-o` file, never stdout.
  - Run with the harness sandbox disabled; Codex's own `-s read-only` keeps it from writing.
- **Round 1:** `codex exec -s read-only -c tools.web_search=true --output-schema schema.json -o $OUT "<prompt>"`. The prompt asks Codex to:
  - Ground every point in the real codebase.
  - Judge correctness, feasibility, missing steps, ordering, assumptions, measurable success criteria and verification.
  - Apply a strict severity rubric; when unsure between major and minor, choose minor.
  - Do one exhaustive conventions sweep against CLAUDE.md/AGENTS.md.
  - Treat code blocks as illustrative sketches.
  - Actively flag bloat as `cut`.
  - Recommend rather than mandate gates.
- **Each round:** accept or reject each concern (Codex is a peer, not an authority); draft the smallest fix; **verify the fix against the source code before applying it**; apply it; keep a ledger.
- **Later rounds:** `codex exec resume --last …` with the changes made and the rebuttals.
- **Stop:** only when Codex itself approves after re-reading the latest edits (no self-approval), after 5 rounds, or at a standoff after one rebuttal round.
- **Report:** verdict, rounds used, accepted concerns with the exact edits, rejected concerns with reasons, cuts applied, open items.

**schema.json:** `verdict` approved|changes_requested; `summary`; `concerns[]` with `severity` blocker|major|minor (rubric in descriptions), `kind` add|cut|change, `location`, `issue`, `suggestion`; strict `additionalProperties:false`.

## obsidian (summary only)
Obsidian is a personal-productivity plugin (v3.2.1) for an Obsidian vault plus Todoist. It has six skills and one agent:
- `today`: closes yesterday's daily note and opens today's, syncing tasks, meetings and memory.
- `new-note`, `process-meeting` (with a transcript-outline shell script), `create-new` (client/project scaffolding), `update-memory`.
- `task-conventions`: a reference skill, not user-invocable.
- `task-manager` agent: bridges Todoist and the vault.

It is unrelated to engineering workflows. The one overlap is its pattern of "memory files" per client/project.

## Ideas worth carrying into a self-contained "engineering" plugin
1. **Push-time reflection hook:** a cheap PostToolUse(Bash) regex for push / PR create that injects `additionalContext` and is a no-op otherwise. Generalise it to "reflect on knowledge + ADR impact" in one hook.
2. **Three-tier knowledge model:** always-loaded orientation, one-line rules (path-scoped), on-demand skills. Keep:
   - rules are one line with a `(see skill:)` link;
   - skills carry the Key Patterns / Anti-Patterns (what / why / fix) / Decision Aids skeleton;
   - `description` vs `when_to_use` split, with the 1,536-character limit;
   - the "durable facts + reason, no session narration" writing rule.
3. **Critical patterns WRONG/CORRECT file**, with its severity bar (build-breaking, data loss, security, silent failure).
4. **Severity triage for healing:** critical issues get a direct fix after user approval; minor ones get staged.
5. **Staging inside auto-memory** (`staging_*.md` + MEMORY.md index), with the promote-at-2+-occurrences rule. Worth keeping as a concept; possibly simplify.
6. **Init methodology:** parallel scan subagents, project classification, adaptive interview, and the research filter "would Claude plausibly make this mistake?". Also the rules for never deleting foreign config, AGENTS.md symlink, and approval before writing.
7. **Lazy retrieval:** read only rule lines, skill descriptions and staging index lines, never full bodies.
8. **ADR doctrine, which is fully portable:**
   - convention discovery from existing files, so no config is needed;
   - living-document model and the 4-part litmus test;
   - the edit/rewrite/new/deprecate table and proportional length targets;
   - ADR vs design-doc split, glossary alignment;
   - "edit the owning ADR the moment a discussion settles it";
   - never reuse numbers; frozen slugs.
9. **Codex second-opinion loop:** strict output schema (severity rubric, `add/cut/change`), propose/verify role separation, verifying fixes against the code, approval only from the external reviewer, a round cap, standoff handling, `resume --last` for memory, the ledger-style report, and the scratch-file and sandbox notes. It could be extended beyond plans (diffs, ADR drafts).

## Ideas tied to the old plugins' specifics (drop or adapt)
- Hard-coded skill names in hook text ("retrieve-knowledge skill") and the `/heal` wording mismatch. A new plugin should namespace these consistently.
- The SessionStart hook that tells the model to run a skill every session: it costs tokens even when unneeded. Consider dropping it, or making it conditional (e.g. only if `.claude/rules` exists).
- `user-invocable:false` on retrieve/promote: these depend on model invocation and the recent commit loosened this. Revisit the invocation design.
- The knowledge-system template is pasted verbatim into L1 (this repo's CLAUDE.md is about 60% boilerplate). A new design could keep it shorter, or ship it as a rule file instead of an L1 insert.
- Model pins (`opus`/`sonnet`) per skill. These are choices specific to the old plugins.
- Codex specifics: requires the `codex` CLI and login, `-c tools.web_search=true`, and the harness sandbox disabled. Keep these as an optional component with a prerequisite check. The prompt's bun/npm convention examples come from a specific stack.
- ADR defaults (`docs/adr/`, `docs/designs/`, `open-design-areas.md`): fine as fallbacks only.
- Repo housekeeping that a new plugin must follow:
  - bump `version` in every commit;
  - register in marketplace.json and the README with an **identical** description (currently out of sync for three plugins);
  - author `{name: "Carl Stålhem", url: "https://github.com/cstalhem"}`;
  - validate with `claude plugin validate ./plugins/engineering --strict`;
  - branch from main and rebase-merge.
  - There is no CI to enforce any of it.
