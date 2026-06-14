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

Refine the plan document at the path in `$ARGUMENTS` by looping with the Codex CLI — a second, independent model — until Codex returns no blocking concerns or the round cap is reached. Codex reviews in read-only mode and never edits the plan; you are the only writer, and you edit only the `.md` source.

The loop has three distinct roles, kept separate on purpose:
- **Codex** proposes concerns (read-only; never writes).
- **You, as proposer**, draft a fix for each accepted concern.
- **You, as verifier**, validate each drafted fix against the codebase *before* applying it — and the loop may only end on a Codex round that re-read your latest edits. You never declare the plan approved yourself.

## Setup

1. Resolve `$ARGUMENTS` to a plan file path and store it as `PLAN`. If no path was given, stop and ask for one. **Only ever edit this `.md` source.** If a generated companion exists (e.g. a same-named `.html`), do not hand-edit it — note at the end that it needs regeneration from the source.

2. Create one scratch file for Codex output and reuse it every round. Write it inside `$TMPDIR` (the harness-writable temp dir) and put the random token at the *end* of the template — BSD `mktemp` will not randomize `XXXXXX` if a suffix follows it:
   ```bash
   OUT="$(mktemp "${TMPDIR:-/tmp}/codex-review.XXXXXX")"
   ```

3. **Read `$OUT` exclusively** for Codex's verdict. Do not parse Codex's stdout: with `-o`, Codex writes the final message to the file *and* echoes it to stdout alongside a banner and a token-usage line, so stdout has noise and duplicates.

4. **Sandbox:** the `codex exec` calls below must run with the *harness* sandbox disabled — Codex needs to read the codebase and reach the web. Codex's own `-s read-only` flag is what keeps it from writing anything, so the read-only intent is preserved. (These are two different sandboxes; disabling the harness one does not give Codex write access.)

5. The review schema is at `${CLAUDE_PLUGIN_ROOT}/skills/review/schema.json`. Codex returns its verdict in that shape: a `verdict` of `approved` or `changes_requested`, a one-line `summary`, and a list of `concerns`, each with `severity` (`blocker`/`major`/`minor`), `kind` (`add`/`cut`/`change`), `location`, `issue`, and `suggestion`.

## Round 1 — first review

Run, with `$PLAN` set to the resolved path. Run this with the harness sandbox disabled (see Setup step 4):

```bash
codex exec -s read-only -c tools.web_search=true \
  --output-schema "${CLAUDE_PLUGIN_ROOT}/skills/review/schema.json" \
  -o "$OUT" \
  "Review the implementation plan at $PLAN. Read it, then explore the actual codebase to check the plan against reality: open the files, functions, and migrations it references and confirm they exist and behave as the plan assumes. Use web search where it helps ground a point in current best practice.

Judge the plan on: technical correctness; feasibility against the real codebase; missing steps or unhandled cases; risky ordering or dependencies between steps; unstated assumptions; whether success criteria are measurable; and whether each step has a verification that actually proves it.

Severity rubric — apply it strictly: blocker = the plan cannot be executed as written, or following it produces broken code. major = following the plan yields incorrect code or misses a goal the plan itself states. minor = clarity, rigor, or convention refinement the plan works without (test-assertion granularity, wording, naming, a tighter annotation in a final code block). When unsure between major and minor, choose minor.

Do a single, exhaustive conventions sweep now — do not hold convention nits back for a later round. Read CLAUDE.md / AGENTS.md / contributing docs in the repo and treat them as the authoritative convention source. Check the plan against them; common categories to verify include package-manager commands (e.g. bun/bunx, not npm), lint/test invocation form (e.g. 'bun run lint', not bare 'lint'), UI copy language, how tests are split/organized, and auth/credential references.

Code blocks in a plan are illustrative sketches that communicate intent; judge them for clarity of intent, not compiler-completeness (full type annotations, import blocks, exhaustive signatures) — unless the plan explicitly states a block is final, shippable code.

Also flag over-specification, redundancy, and bloat: mark these 'cut' and suggest what to remove. A shorter plan that still conveys intent is better; do not only propose additions.

For coverage gaps and process risks, recommend — do not mandate. Whether something becomes a required manual gate is the author's decision; phrase it as a suggestion, not as a rule the plan must adopt.

Ground every concern in a specific file or plan section and be concrete. Set verdict to approved only if no blocker or major concerns remain; minor concerns are acceptable. Otherwise set verdict to changes_requested."
```

Read `$OUT` for the verdict and concerns.

## Evaluate, propose, verify — each round

For each concern Codex returns:

1. **Decide accept or reject.** Accept valid `blocker` and `major` concerns. Accept `minor` and `cut` concerns when they clearly improve the plan. Reject any concern you judge wrong, and record the reason — Codex is a peer reviewer, not the authority; overrule it when you have sound grounds.

2. **Propose the fix.** Draft the smallest edit that resolves the accepted concern. Prefer the minimal change; when a concern is resolved by *removing* text (a `cut`), remove it — do not ratchet the plan toward verbosity round over round.

3. **Verify the fix against the codebase — before applying it.** This is a separate step from drafting, and it must check the source of truth, not your own draft. If your fix asserts anything about the code (a function signature, an error message, a test's assertion style, a migration), confirm it by re-reading that code — not by trusting the edit you just wrote. A fix that contradicts the codebase is worse than the original concern.

4. **Apply to the `.md` source only.** Never touch a generated companion file.

Keep a running ledger: concerns accepted (with the exact edit made), concerns rejected (with the reason), and `cut` concerns applied.

## Subsequent rounds — resume the same Codex conversation

Codex keeps the conversation across calls, so it remembers the concerns it already raised and your rebuttals. Resume the most recent session (harness sandbox disabled, as above):

```bash
codex exec resume --last -c tools.web_search=true \
  --output-schema "${CLAUDE_PLUGIN_ROOT}/skills/review/schema.json" \
  -o "$OUT" \
  "I revised the plan. Changes I made: <list them>. Concerns I did not act on, and why: <list them>. Re-read the plan at $PLAN and report any remaining concerns."
```

(`resume` has no `-s` flag; it inherits the read-only sandbox from the round-1 session.) Read `$OUT` and evaluate again.

## Stop conditions

- Stop when `verdict` is `approved`. The approval must be **Codex's**, returned from a resume round that re-read your latest edits — never your own judgement that the plan is now fine. Concretely: after any edit, the only way to reach `approved` is to send the plan back to Codex and have *it* return that verdict. This is the guard against grading your own patch; do not add a shortcut that ends the loop on edits Codex has not re-reviewed.
- Stop after 5 rounds.
- If the only remaining concerns are ones you reject with sound reasons, run one final resume round stating your rebuttals so Codex can reconsider. If it still requests changes on those same points, stop — the disagreement stands.

## Final report

When the loop ends, report:

- The plan file path (the `.md` source, edited in place) and the final verdict.
- If a generated companion (e.g. `.html`) exists: flag that it needs regeneration from the source — you did not edit it.
- Number of rounds used.
- Concerns accepted, with the exact edit made for each (so authorship stays legible — the author can see precisely what changed and why).
- Concerns rejected, with the reason.
- Over-specification removed (`cut` concerns applied).
- Any concerns left open at the round cap or standoff.
