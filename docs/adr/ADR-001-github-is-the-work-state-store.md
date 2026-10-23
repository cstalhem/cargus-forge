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
- A **sub-issue** is one session of work. A GitHub parent link holds its place under the umbrella. Its blockers are GitHub "blocked by" links, which slice sets through REST. The `Blocked by #<a>, #<b>` text in its first line mirrors them for readers ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- **Facts decide the status:** closed, blocked by an open issue, a merged PR, a ready PR, an issue branch, a draft PR.
- **Labels show only what GitHub does not show.** Each skill sets one label:
  - `umbrella`: discuss sets it when the size test fails;
  - `status:ready`: discuss (single issue) or slice (sub-issues) sets it when the size test passes;
  - `status:in-progress`: execute sets it when it gets onto the issue branch;
  - `status:needs-review`: verify sets it when it passes a PR.
- **Each status label replaces the one before it,** and `umbrella` replaces every status label. A skill adds a label with `POST issues/<n>/labels`, removes each one it replaces with `DELETE issues/<n>/labels/<name>`, reads the labels back, and leaves every other label as it was. It never uses the `labels` field of a `PATCH`, which replaces every label.
- **The label names are fixed** in the plugin's `references/rules.md`. A name holds no space, so no path needs encoding. Adding a label that the repo lacks creates it, so no skill has a create step.
- **A merged sub-issue is closed.** A workflow closes it when its PR merges into the feature branch ([ADR-002](ADR-002-feature-branch-per-umbrella.md)), so "merged" needs no label.
- **No label means a request that needs discuss.** An issue made by hand is therefore never mistaken for shaped work.
- GitHub already shows blocked issues (a Blocked icon and the `is:blocked` filter) and closed issues, so neither gets a label. slice sets every blocker as a link, so the Blocked icon shows for each one ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- A script (`status.sh`) recomputes every status and repairs labels that differ. It never sets `status:ready`, because only the size test can.
- Each repo describes its tracker in `docs/agents/issue-tracker.md`. Skills read that file, so the tracker can change without a change to the skills.

## Rejected alternatives
- **State files in the repo** (GSD's `.planning/` and `STATE.md`): GSD writes about 15 files for each phase, and the files drift from what is true.
- **Issues plus one `STATE.md`:** two sources that can disagree.
- **Hand-written stop notes or status sections in issues:** people miss them, and they go out of date.
- **Labels for blocked and done:** GitHub shows both already.
- **No label means ready:** an issue made by hand then looks ready before discuss has shaped it.
- **A "new" label from an issue template:** a template labels only the issues made through it. It misses issues made with `gh`, the API or a blank form, so those would look ready again.
- **A GitHub Action that sets labels from events:** it is extra setup in each repo, and the repair script covers the drift. The one workflow the plugin ships closes sub-issues and sets no label.

## Consequences
- Each repo must be on GitHub. Skills read and write issues, PRs, parent, sub-issue and dependency data through `gh api` REST, so they need no minimum `gh` version and work in cloud sessions ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- A different tracker needs a new tracker profile and a new status script.
- Work can resume from any device that can read GitHub, including Remote Control on a phone and a cloud session.
- The Blocked icon shows in the GitHub web issue list, but not in the GitHub mobile app.
- `status.sh` reads each issue's blocked-by links through REST (`issues/<n>/dependencies/blocked_by`). GitHub's search API did not return `is:blocked` results.
