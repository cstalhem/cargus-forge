---
name: review
description: Iteratively review and refine a plan document by getting feedback from the Codex CLI (a second, independent model) until Codex returns no blocking concerns or a round cap is reached. Use to pressure-test an implementation plan before starting the work it describes.
argument-hint: <plan-file>
context: fork
agent: general-purpose
disable-model-invocation: true
allowed-tools: Bash Read Edit Write
---

# Codex Plan Review

Refine the plan document at the path in `$ARGUMENTS` by looping with the Codex CLI — a second, independent model — until Codex returns no blocking concerns or the round cap is reached. Codex reviews in read-only mode and never edits the plan; you are the only writer.

## Setup

1. Resolve `$ARGUMENTS` to a plan file path and store it as `PLAN`. If no path was given, stop and ask for one.
2. Create one scratch file for Codex output and reuse it every round:
   ```bash
   OUT="$(mktemp -t codex-review.XXXXXX.json)"
   ```
3. The review schema is at `${CLAUDE_PLUGIN_ROOT}/skills/review/schema.json`. Codex returns its verdict in that shape: a `verdict` of `approved` or `changes_requested`, a one-line `summary`, and a list of `concerns`, each with `severity` (`blocker`, `major`, or `minor`), `location` (a file path or plan section), `issue`, and `suggestion`.

## Round 1 — first review

Run, with `$PLAN` set to the resolved path:

```bash
codex exec --search -s read-only \
  --output-schema "${CLAUDE_PLUGIN_ROOT}/skills/review/schema.json" \
  -o "$OUT" \
  "Review the implementation plan at $PLAN. Read it, then explore the actual codebase to check the plan against reality: open the files, functions, and migrations it references and confirm they exist and behave as the plan assumes. Use web search where it helps to ground a point in current best practice. Judge the plan on technical correctness; feasibility against the real codebase; missing steps or unhandled cases; risky ordering or dependencies between steps; unstated assumptions; whether success criteria are measurable; and whether each step has a verification that actually proves it. Ground every concern in a specific file or plan section and be concrete. Set verdict to approved only if no blocker or major concerns remain; minor concerns are acceptable. Otherwise set verdict to changes_requested."
```

Read `$OUT` for the verdict and concerns.

## Evaluate each round

For each concern Codex returns, decide accept or reject:

- Accept valid blocker and major concerns and fix them by editing `$PLAN` in place.
- Reject a concern you judge wrong, or a minor one not worth acting on, and record the reason. Codex is a peer reviewer, not the authority — overrule it when you have sound grounds.

Keep a running record of concerns accepted (with how each was addressed) and concerns rejected (with the reason).

## Subsequent rounds — resume the same Codex conversation

Codex keeps the conversation across calls, so it remembers the concerns it already raised and your rebuttals. Resume the most recent session:

```bash
codex exec resume --last --search \
  --output-schema "${CLAUDE_PLUGIN_ROOT}/skills/review/schema.json" \
  -o "$OUT" \
  "I revised the plan. Changes I made: <list them>. Concerns I did not act on, and why: <list them>. Re-read the plan at $PLAN and report any remaining concerns."
```

Read `$OUT` and evaluate again.

## Stop conditions

- Stop when `verdict` is `approved`.
- Stop after 5 rounds.
- If the only remaining concerns are ones you reject with sound reasons, run one final resume round stating your rebuttals so Codex can reconsider. If it still requests changes on those same points, stop — the disagreement stands.

## Final report

When the loop ends, report:

- The plan file path (edited in place) and the final verdict.
- Number of rounds used.
- Concerns accepted, with how each was addressed.
- Concerns rejected, with the reason.
- Any concerns left open at the round cap or standoff.
