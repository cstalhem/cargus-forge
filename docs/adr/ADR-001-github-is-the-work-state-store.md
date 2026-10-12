---
adr: 001
title: GitHub is the only store of work state
status: active
---

# ADR-001: GitHub is the only store of work state

- **Decision:** The engineering plugin keeps work state only in GitHub issues, PRs and git. It derives each status from facts that GitHub and git record. Labels show the status, and only automation writes them.
- **Design notes:** [process.md, Status](../engineering-plugin/process.md#status)

## Details
- The **umbrella issue** is the one record of a feature: goal, scenarios, decisions, out of scope. Shape writes it once. It has no progress section.
- A **sub-issue** is one session of work. GitHub parent links and "blocked by" links hold the structure, not text.
- **Facts decide the status:** closed, blocked by an open issue, a merged PR, a ready PR, a linked branch, a draft PR.
- **Two labels show what GitHub does not show:**
  - `status: in progress`, which execute sets;
  - `status: needs review`, which verify sets on pass.
- GitHub already shows blocked issues (a Blocked icon and the `is:blocked` filter) and closed issues, so neither gets a label.
- A script (`status.sh`) recomputes every status and repairs labels that differ.
- Each repo describes its tracker in `docs/agents/issue-tracker.md`. Skills read that file, so the tracker can change without a change to the skills.

## Rejected alternatives
- **State files in the repo** (GSD's `.planning/` and `STATE.md`): GSD writes about 15 files for each phase, and the files drift from what is true.
- **Issues plus one `STATE.md`:** two sources that can disagree.
- **Hand-written stop notes or status sections in issues:** people miss them, and they go out of date.
- **Labels for blocked and done:** GitHub shows both already.
- **A GitHub Action that sets labels from events:** it is extra setup in each repo, and the repair script covers the drift.

## Consequences
- Each repo must be on GitHub, with `gh` 2.94 or later, which reads parent, sub-issue and dependency data as JSON.
- A different tracker needs a new tracker profile and a new status script.
- Work can resume from any device that can read GitHub, including Remote Control on a phone.
- The Blocked icon shows in the GitHub web issue list, but not in the GitHub mobile app.
- `status.sh` reads each issue's `blockedBy` field. GitHub's search API did not return `is:blocked` results.
