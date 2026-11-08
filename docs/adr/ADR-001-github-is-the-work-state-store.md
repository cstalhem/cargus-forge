---
adr: 001
title: GitHub is the only store of work state
status: active
---

# ADR-001: GitHub is the only store of work state

- **Decision:** The engineering plugin keeps work state only in GitHub issues, PRs and git. It derives each status from facts that GitHub and git record: an issue's body, links, branches and PRs, and the author of each issue and PR, which must be a trusted author for the item to count ([ADR-011](ADR-011-build-acts-only-on-trusted-authors.md)). No script or skill reads a label to decide anything, and no skill sets a status label. The one label it keeps is a display label, `engineering:shaped`, which one script, `labels.sh`, sets on each open issue whose status is not request, so that a person browsing GitHub sees which issues discuss has finished and are left to Build. It leaves closed issues alone.

## Details
- The **umbrella issue** is the one record of a feature: goal, scenarios, decisions, out of scope. Shape writes it once. It has no progress section.
- A **sub-issue** is one session of work. A GitHub parent link holds its place under the umbrella. Its blockers are GitHub "blocked by" links, which slice sets through REST. Its body lists neither its parent nor its blockers, so no text copies a link ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- **Facts decide the status.** A script (`status.sh`) works out the status of each open issue for `next`, the first of these that applies:
  - request, first: the issue's author is not a trusted author, whatever its body says. A PR whose author is not a trusted author names no issue, so it gives no fact ([ADR-011](ADR-011-build-acts-only-on-trusted-authors.md));
  - umbrella: the body has a `## Goal` section. Its feature branch is a `<n>-*` branch, so this comes before the branch fact;
  - needs review: an open ready PR whose first line names the issue;
  - in progress: an open draft PR that names the issue, or a remote `<n>-*` branch with no merged PR. A branch whose PR has merged is finished work, so it gives nothing;
  - ready, or blocked when it has an open "blocked by" link: the body has a `## Scenarios` section;
  - request: anything else, so an issue made by hand is never mistaken for shaped work.
- **The author is a fact too.** `status.sh` reads `author_association` from the issue and PR lists it already reads, and acts only on a trusted author's item ([ADR-011](ADR-011-build-acts-only-on-trusted-authors.md)).
- **No status label.** A label would copy a fact that the body, a link, a branch or a PR already holds. An old status label on an issue changes nothing.
- **`setup.sh` tells plugin work by the body.** It treats an open issue as one that the plugin works on when its body has a `## Goal` or `## Scenarios` section, so an issue being built, with its one `<n>-*` branch, gets no branch finding. It uses the section test that `status.sh` uses, which both scripts load from `scripts/lib.sh`, and does not call `status.sh`.
- **One display label.** `labels.sh` is the only writer of `engineering:shaped`: it adds the label to each open issue whose status is not request and removes it from each open request. It reads no closed issue, because the label stays true once an issue closes. It reads the statuses from `status.sh --statuses`, so the status logic stays in one place and `status.sh` stays read-only. `next` and both Autopilots run it, once a run. It creates the label with its colour and description only when it is missing, and it touches no other label. A wrong or missing label gives a wrong view and no wrong action, because no script reads it.
- **A merged sub-issue is closed.** A workflow closes it when its PR merges into the feature branch ([ADR-002](ADR-002-feature-branch-per-umbrella.md)), so "merged" needs no other record.
- GitHub already shows blocked issues (a Blocked icon and the `is:blocked` filter) and closed issues. slice sets every blocker as a link, so the Blocked icon shows for each one ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- The plugin's contract for branches, merging and PRs is in its `references/issue-tracker.md`, and it takes `main` as the default branch. A repo's only profile file is `docs/agents/commands.md`, with its commands. The contract stays in the plugin, so a plugin update reaches every repo.

## Rejected alternatives
- **State files in the repo** (GSD's `.planning/` and `STATE.md`): GSD writes about 15 files for each phase, and the files drift from what is true.
- **Issues plus one `STATE.md`:** two sources that can disagree.
- **Hand-written stop notes or status sections in issues:** people miss them, and they go out of date.
- **The body alone decides the status:** a stranger's issue with a `## Scenarios` section reads as ready, and Autopilot builds it unattended.
- **Status labels** (`status:ready`, `status:in-progress`, `status:needs-review`, `umbrella`) **set by each skill:** each one copied a fact that GitHub and git already hold, so the copies drifted. Keeping them true took a label rule in every skill, a repair step in `next` and a hook that guarded its calls.
- **Labels for blocked and done:** GitHub shows both already.
- **A label for every status:** only one split matters to a person browsing: shaped or not. GitHub's PR list already shows ready PRs.
- **A label on each request (`engineering:needs-discussion`):** most open issues were requests, so the label sat on almost every issue and did not show which ones to leave alone.
- **A label only on ready issues:** blocked, in-progress and umbrella issues would look like requests.
- **Removing the label from closed issues:** it stays true once an issue closes, and the sweep cost a write for every finished issue.
- **Scripts that read labels:** a drifted label would cause a wrong action instead of a wrong view.
- **Reading the old status labels (`status:*`, `umbrella`) in `setup.sh`:** no issue that the current plugin creates has one, so setup flagged the branch of every issue being built.
- **Calling `status.sh` from `setup.sh`:** it reads each issue's links, PRs and branches, which is many REST calls for a yes/no question that the body answers.
- **Dropping the exemption from `setup.sh`:** every issue being built in a repo that uses the plugin would get a finding to rename its branch.
- **A label name without the `engineering:` prefix, such as `Shaped`:** `labels.sh` removes its label from each open request, so in a repo that already uses that name it would strip it.
- **A label write mode in `status.sh`:** Autopilot loads `status.sh` at the start of each run, so loading the Facts would write to GitHub.
- **Running `labels.sh` at the end of each skill that changes a status:** five more call sites for a freshness that a display label does not need.
- **Letting `POST issues/<n>/labels` create the label:** GitHub gives it the grey default colour.
- **A GitHub Action that sets labels from events:** it is extra setup in each repo, to keep copies of facts that `status.sh` reads directly. The one workflow the plugin ships closes sub-issues and sets no label.

## Consequences
- Each repo must be on GitHub. Skills read and write issues, PRs, parent, sub-issue and dependency data through `gh api` REST, so they need no minimum `gh` version and work in cloud sessions ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- A different tracker needs a new tracker profile and a new status script.
- A repo that used the old labels (`engineering:needs-discussion`, `status:ready`, `status:in-progress`, `status:needs-review`, `umbrella`) keeps them until its owner deletes them by hand; no script or skill reads them. An old labelled issue whose body has neither section gets `setup.sh`'s branch finding.
- Work can resume from any device that can read GitHub, including Remote Control on a phone and a cloud session.
- The Blocked icon shows in the GitHub web issue list, but not in the GitHub mobile app.
- `status.sh` reads each issue's blocked-by links through REST (`issues/<n>/dependencies/blocked_by`). GitHub's search API did not return `is:blocked` results.
