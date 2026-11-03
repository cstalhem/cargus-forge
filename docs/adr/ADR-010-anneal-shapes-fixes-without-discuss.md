---
adr: 010
title: An anneal shapes behaviour-preserving fixes without discuss
status: active
---

# ADR-010: An anneal shapes behaviour-preserving fixes without discuss

- **Decision:** An anneal writes each fix that passes the size test as a ready sub-issue under one umbrella issue, without discuss or a yes, and the final PR into `main` is the human review.
- **Builds on:** [ADR-008](ADR-008-autopilot-builds-ready-issues-unattended.md)
- **Source:** [#264](https://github.com/cstalhem/cargus-forge/issues/264)

## Details
- **Typed, by hand.** `anneal` has `disable-model-invocation: true`, and the user starts each run. A scheduled anneal is a later request, once hand-started runs have shown that the routes can be trusted.
- **Agents, not files.** One investigator on Opus for each area, at most six, returns its findings as its answer. One fresh-context checker on Sonnet for each finding returns confirmed, corrected or refuted with evidence. The run keeps the findings in its own context.
- **Two routes out.** A confirmed finding that is behaviour-preserving, passes the size test and has a verify command that fails before the work is a fix. Any other confirmed finding, every bold rewrite included, is a request. A refuted finding is dropped.
- **Fix sub-issues are ready as written.** Each has scenarios and a verify command, so Autopilot or execute builds it with no discuss and no slice. They have no "blocked by" link, because each fix stands alone.
- **A rule for each fix.** A fix carries the rule that would have made it unneeded, as a scenario that its sub-issue's PR writes into `.claude/rules/`, so the fixes needed shrink over time.
- **No code from the run.** An anneal writes issues and a feature branch to GitHub and changes no file in the repo.

## Rejected alternatives
- **The anneal's own execute agents:** they copy Autopilot, which already builds ready issues.
- **A yes on the plan before writing:** a plan is weaker evidence than the code in the final PR, and the yes blocks an unattended run.
- **Findings in temporary files:** a second copy of what an agent returns.
- **Finer classes such as trivial or mechanical:** each class needs a route, and there are only two.
- **A stored record of counts per run:** it copies what the issues' titles already hold.
- **A scheduled anneal from the start:** automation comes last ([ADR-007](ADR-007-question-delete-simplify-first.md)), after hand-started runs have proven the routes.

## Consequences
- A fix sub-issue reaches the feature branch with no human review of its shape. The review happens on the final PR into `main`.
- A wrong finding costs one sub-issue that the user can close, or a final PR that the user can refuse.
- Each run costs one Opus agent for each area and one Sonnet agent for each finding.
