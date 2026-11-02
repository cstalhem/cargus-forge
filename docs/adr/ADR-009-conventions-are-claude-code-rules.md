---
adr: 009
title: Conventions are Claude Code rules in the repo
status: active
---

# ADR-009: Conventions are Claude Code rules in the repo

- **Decision:** A repo's conventions live as one-line rules in `.claude/rules/`, which setup proposes from the repo, research agents and model knowledge, verify grades each PR against, and execute's reflect step extends from evidence in the work; nothing is kept in the memory directory.
- **Source:** [#217](https://github.com/cstalhem/cargus-forge/issues/217)

## Details
- A rule is one line with no code, no rationale and no source tag. A rule file has `paths:` frontmatter where its area maps to a folder.
- A source shows only on setup's screen, never in the rule file.
- Setup proposes no rule for what the repo's rule docs already say or a tool config enforces. A convention that one command can check becomes a pre-PR check row of `docs/agents/commands.md`.
- The repo owns `.claude/rules/` once it holds a file: setup reports it as kept and asks nothing. Deleting the folder and running setup again redoes the proposal.

## Rejected alternatives
- **A conventions file in the repo profile (`docs/agents/conventions.md`):** only the plugin's skills would read it, while Claude Code loads rules into every session.
- **A staging tier in the memory directory:** it is not in the repo and vanishes with a cloud container.
- **A PostToolUse hook on push that asks what is worth remembering:** it fires on every push in every session and cannot record its outcome, while a step in execute runs once, when the PR can name what it added.
- **A retrieve skill at session start:** Claude Code loads rules itself.
- **Skills written at setup:** a skill from research guesses which areas need depth, and one from a real miss has evidence.
- **Source tags in the rule files:** they cost tokens in every session for a fact that setup's screen already shows.

## Consequences
- Every rule costs tokens in each session that loads it, so each one has to earn its line.
- Rules are reviewed in the PR that adds them, like any other file of the repo.
