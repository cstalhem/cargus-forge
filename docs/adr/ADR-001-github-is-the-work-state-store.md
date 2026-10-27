---
adr: 001
title: GitHub is the only store of work state
status: active
---

# ADR-001: GitHub is the only store of work state

- **Decision:** The engineering plugin keeps work state only in GitHub issues, PRs and git. It derives each status from facts that GitHub and git record: an issue's body, links, branches and PRs. No skill writes or reads a status label.

## Details
- The **umbrella issue** is the one record of a feature: goal, scenarios, decisions, out of scope. Shape writes it once. It has no progress section.
- A **sub-issue** is one session of work. A GitHub parent link holds its place under the umbrella. Its blockers are GitHub "blocked by" links, which slice sets through REST. Its body lists neither its parent nor its blockers, so no text copies a link ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- **Facts decide the status.** A script (`status.sh`) works out the status of each open issue for `next`, the first of these that applies:
  - umbrella: the body has a `## Goal` section. Its feature branch is a `<n>-*` branch, so this comes before the branch fact;
  - needs review: an open ready PR whose first line names the issue;
  - in progress: an open draft PR that names the issue, or a remote `<n>-*` branch with no merged PR. A branch whose PR has merged is finished work, so it gives nothing;
  - ready, or blocked when it has an open "blocked by" link: the body has a `## Scenarios` section;
  - request: anything else, so an issue made by hand is never mistaken for shaped work.
- **No status label.** A label would copy a fact that the body, a link, a branch or a PR already holds. An old status label on an issue changes nothing, and `next` changes no label.
- **A merged sub-issue is closed.** A workflow closes it when its PR merges into the feature branch ([ADR-002](ADR-002-feature-branch-per-umbrella.md)), so "merged" needs no other record.
- GitHub already shows blocked issues (a Blocked icon and the `is:blocked` filter) and closed issues. slice sets every blocker as a link, so the Blocked icon shows for each one ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- The plugin's contract for branches, merging and PRs is in its `references/issue-tracker.md`, and it takes `main` as the default branch. A repo's only profile file is `docs/agents/commands.md`, with its commands. The contract stays in the plugin, so a plugin update reaches every repo.

## Rejected alternatives
- **State files in the repo** (GSD's `.planning/` and `STATE.md`): GSD writes about 15 files for each phase, and the files drift from what is true.
- **Issues plus one `STATE.md`:** two sources that can disagree.
- **Hand-written stop notes or status sections in issues:** people miss them, and they go out of date.
- **Status labels** (`status:ready`, `status:in-progress`, `status:needs-review`, `umbrella`) **set by each skill:** each one copied a fact that GitHub and git already hold, so the copies drifted. Keeping them true took a label rule in every skill, a repair step in `next` and a hook that guarded its calls.
- **Labels for blocked and done:** GitHub shows both already.
- **A GitHub Action that sets labels from events:** it is extra setup in each repo, to keep copies of facts that `status.sh` reads directly. The one workflow the plugin ships closes sub-issues and sets no label.

## Consequences
- Each repo must be on GitHub. Skills read and write issues, PRs, parent, sub-issue and dependency data through `gh api` REST, so they need no minimum `gh` version and work in cloud sessions ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- A different tracker needs a new tracker profile and a new status script.
- Work can resume from any device that can read GitHub, including Remote Control on a phone and a cloud session.
- The Blocked icon shows in the GitHub web issue list, but not in the GitHub mobile app.
- `status.sh` reads each issue's blocked-by links through REST (`issues/<n>/dependencies/blocked_by`). GitHub's search API did not return `is:blocked` results.
