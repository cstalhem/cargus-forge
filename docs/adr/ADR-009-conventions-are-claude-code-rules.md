---
adr: 009
title: Conventions are Claude Code rules in the repo
status: active
---

# ADR-009: Conventions are Claude Code rules in the repo

- **Decision:** A repo's conventions live as one-line rules in `.claude/rules/`, which setup proposes from the repo, research agents and model knowledge, verify grades each PR against, and execute's reflect step extends from evidence in the work; nothing is kept in the memory directory. A rule has no code, passes the rule test, may end with a short reason clause, and ends with `(see skill: <name>)` when a skill in `.claude/skills/` holds what its line cannot; the plugin defines this once in `references/repo-rules.md`, which setup, execute, anneal and verify load.
- **Source:** [#217](https://github.com/cstalhem/cargus-forge/issues/217)

## Details
- A rule is one line with no code and no source tag that passes the rule test. It may end with a short reason clause when the reason tells a session when the rule bends. A rule file has `paths:` frontmatter where every rule in it applies to files under one folder.
- A rule ends with `(see skill: <name>)` when a skill in `.claude/skills/` holds the steps or examples that its line cannot. Execute alone decides whether a rule gets one, and anneal writes no skills.
- The plugin defines the rule, the rule test, when a rule goes and how to write a backing skill once, in `references/repo-rules.md`, which setup, execute, anneal and verify load.
- A source shows only on setup's screen, never in the rule file.
- Setup proposes no rule for what the repo's rule docs already say or a tool config enforces. A convention that one command can check becomes a pre-PR check row of `docs/agents/commands.md`.
- The repo owns `.claude/rules/` once it holds a file: setup reports it as kept and asks nothing. Deleting the folder and running setup again redoes the proposal.

## Rejected alternatives
- **A conventions file in the repo profile (`docs/agents/conventions.md`):** only the plugin's skills would read it, while Claude Code loads rules into every session.
- **A staging tier in the memory directory:** it is not in the repo and vanishes with a cloud container.
- **A PostToolUse hook on push that asks what is worth remembering:** it fires on every push in every session and cannot record its outcome, while a step in execute runs once, when the PR can name what it added.
- **A retrieve skill at session start:** Claude Code loads rules itself.
- **Skills written at setup:** a skill from research guesses which areas need depth, and one from a real miss has evidence.
- **No rationale in a rule:** Claude needs the reason to judge when a guideline bends, and Claude Code's docs put a short reason in the line.
- **A skill behind every rule:** each model-invocable skill costs context on every turn in the skill listing, and a line that passes the rule test needs none.
- **A skill found only by its description:** a description match is a guess, while a pointer costs a few tokens on the few rules that have one.
- **Each skill's own wording of the definition:** the copies drifted apart.
- **The definition in the repo's glossary:** it reaches only one repo.
- **Source tags in the rule files:** they cost tokens in every session for a fact that setup's screen already shows.

## Consequences
- Every rule costs tokens in each session that loads it, so each one has to earn its line.
- Rules are reviewed in the PR that adds them, like any other file of the repo.
