# Codex Review

Pressure-test an implementation plan by looping it through the [Codex CLI](https://developers.openai.com/codex/cli) — a second, independent model — until Codex has no blocking feedback left.

## What it does

`/codex-review:review <plan-file>` runs an autonomous review loop in a forked context:

1. Claude sends the plan to Codex (`codex exec`, read-only sandbox), which explores the real codebase and the web to ground its critique.
2. Codex returns a structured verdict and a list of concerns (each with a severity, location, issue, and suggestion).
3. Claude accepts the valid concerns and edits the plan in place, rejecting ones it judges wrong — Codex is treated as a peer, not an authority.
4. Claude resumes the *same* Codex conversation (`codex exec resume`) so Codex remembers what it raised and what Claude rebutted, then re-reviews.
5. The loop ends when Codex approves, after five rounds, or at a reasoned standoff.

Claude reports which concerns it accepted and addressed, which it rejected and why, and the final verdict. The plan file is edited in place.

## Prerequisites

- The `codex` CLI installed and on `PATH`.
- Authenticated: run `codex login` once.

## Usage

```
/codex-review:review path/to/plan.md
```

The plan file must already exist; the skill refines it, it does not create one.
