---
adr: 001
title: GitHub is the only store of work state
status: active
---

# ADR-001: GitHub is the only store of work state

- **Decision:** The engineering plugin keeps work state only in GitHub issues, PRs and git. An issue is shaped only while it carries `engineering:shaped`, which discuss, slice and anneal add in their write step and `status.sh` reads; `engineering:needs-discussion` marks a shaped issue that was sent back, `engineering:umbrella` is a display label, and build states stay derived from links, branches and PRs. It derives each build status from facts that GitHub and git record: an issue's links, branches and PRs, and the author of each issue and PR, which must be a trusted author for the item to count ([ADR-011](ADR-011-build-acts-only-on-trusted-authors.md)). Skills reach GitHub through `gh`, by the simplest command for each operation, and work resumes from any device that reaches the T3 Code host ([ADR-006](ADR-006-engineering-runs-in-t3-code-threads.md)). `status.sh` reads each open issue's labels, parent, sub-issues, blockers and linked branches, and the PRs, through GraphQL queries that page with the query's cursor, so it makes no REST call for each issue.
- **Source:** [#390](https://github.com/cstalhem/cargus-forge/issues/390)

## Details
- The **umbrella issue** is the one record of a feature: goal, scenarios, decisions, out of scope. Shape writes it once. It has no progress section.
- A **sub-issue** is one session of work. A GitHub parent link holds its place under the umbrella. Its blockers are GitHub "blocked by" links, which slice sets through REST. Its body lists neither its parent nor its blockers, so no text copies a link ([ADR-006](ADR-006-engineering-runs-in-t3-code-threads.md)).
- **Facts decide the status.** A script (`status.sh`) works out the status of each open issue for `next`, the first of these that applies:
  - request, first: the issue's author is not a trusted author, whatever its body says, or the issue does not carry `engineering:shaped`. A PR whose author is not a trusted author names no issue, so it gives no fact ([ADR-011](ADR-011-build-acts-only-on-trusted-authors.md));
  - umbrella: the body has a `## Goal` section. Its feature branch is a branch linked to it, so this comes before the branch fact;
  - needs review: an open ready PR whose first line names the issue;
  - in progress: an open draft PR that names the issue, or a branch linked to the issue with no merged PR. A branch whose PR has merged is finished work, and a `<n>-*` branch with no link is no issue's branch, so neither gives anything;
  - merged: a merged PR into the feature branch of its umbrella names the issue on its first line. A repo without the close-sub-issue workflow leaves a merged sub-issue open until the final PR, and GitHub may delete its branch, so this fact rests on the PR alone. No group lists a merged issue, it counts as done for its umbrella, and it blocks nothing;
  - ready, or blocked when it has an open "blocked by" link: any other shaped issue.
- **A finished worktree is a fact too.** `status.sh` lists a worktree for removal only when its issue branch has a merged PR and no open one, or its issue is closed, it has no uncommitted work by the check that `git worktree remove` makes without `--force`, and every commit is on a remote branch or in the merged PR's head, which a squash merge keeps after GitHub deletes the remote branch. The main, bare, detached, locked and prunable worktrees and the one the session runs in are never listed, and `next` removes one only after the user's yes.
- **The author is a fact too.** `status.sh` reads `author_association` from the issue and PR lists it already reads, and acts only on a trusted author's item ([ADR-011](ADR-011-build-acts-only-on-trusted-authors.md)).
- **No build-state label.** A label would copy a fact that a link, a branch or a PR already holds. An old `status:ready`, `status:in-progress`, `status:needs-review` or `umbrella` label on an issue changes nothing.
- **The skill that shapes an issue writes its labels.** discuss adds `engineering:shaped` to the issue it writes, and `engineering:umbrella` to an umbrella issue. slice adds `engineering:shaped` to each sub-issue it creates, and anneal to its umbrella and its fix sub-issues, with `engineering:umbrella` on the umbrella; a request that anneal writes carries no label. Each skill adds them in its write step, after the issue's own write, with the label commands in `references/rules.md`, and never through a `labels` field on a create or a rewrite, which on a rewrite replaces every label on the issue.
- **At most one of `engineering:shaped` and `engineering:needs-discussion`.** A swap removes the old label first, then adds the new one. discuss removes `engineering:needs-discussion` when it rewrites an issue that carries it.
- **No label write waits for the user.** Each skill's `allowed-tools` pre-approves exactly its label calls. A failed write, or a read-back without the label, shows its error and the skill goes on to its hand-off, so a missing label leaves one issue a request, and discuss can shape it again.
- GitHub creates a label that a repo lacks, in grey, on first use, and no skill sets a colour.
- **A merged sub-issue is closed.** A workflow closes it when its PR merges into the feature branch ([ADR-002](ADR-002-feature-branch-per-umbrella.md)), so "merged" needs no other record.
- GitHub already shows blocked issues (a Blocked icon and the `is:blocked` filter) and closed issues. slice sets every blocker as a link, so the Blocked icon shows for each one ([ADR-006](ADR-006-engineering-runs-in-t3-code-threads.md)).
- The plugin's contract for branches, merging and PRs is in its `references/issue-tracker.md`, and it takes `main` as the default branch. A repo's only profile file is `docs/agents/commands.md`, with its commands. The contract stays in the plugin, so a plugin update reaches every repo.

## Rejected alternatives
- **State files in the repo** (GSD's `.planning/` and `STATE.md`): GSD writes about 15 files for each phase, and the files drift from what is true.
- **Issues plus one `STATE.md`:** two sources that can disagree.
- **Hand-written stop notes or status sections in issues:** people miss them, and they go out of date.
- **The body's sections decide "shaped":** the body cannot say that a shaped issue needs discussion again, and anyone can type a section, so a stranger's issue with a `## Scenarios` section reads as ready and Autopilot builds it unattended.
- **Labels for build states:** `status:ready`, `status:in-progress`, `status:needs-review`, blocked and done each copied a fact that GitHub and git already hold, and a PR is merged on GitHub with no skill running, so the copies drifted. Keeping them true took a label rule in every skill, a repair step in `next` and a hook that guarded its calls.
- **A label for every status:** only one split matters to a person browsing: shaped or not. GitHub's PR list already shows ready PRs.
- **A label on each request (`engineering:needs-discussion`):** most open issues were requests, so the label sat on almost every issue and did not show which ones to leave alone.
- **A label only on ready issues:** blocked, in-progress and umbrella issues would look like requests.
- **One display label kept by a sweep (`labels.sh`):** the label was missing until `next` or Autopilot ran, and a skill that wrote one issue changed many.
- **Slice adds the umbrella label:** anneal writes umbrellas without slice, and an interrupted slice leaves the umbrella unlabelled.
- **A script or setup step that creates each label with its colour:** it costs a script for a colour that no skill reads, and GitHub creates a missing label in grey on first use.
- **A GitHub Action that sets labels from events:** it is extra setup in each repo, to keep copies of facts that `status.sh` reads directly. The one workflow the plugin ships closes sub-issues and sets no label.
- **Reads and writes through `gh api` REST only:** it served the cloud proxy, which the plugin no longer supports.
- **One REST call for each issue's blockers and sub-issues in `status.sh`:** it made about 20 calls and took 12.6 s; one GraphQL query returns every open issue with its parent, sub-issues and blockers in 0.46 s.

## Consequences
- Each repo must be on GitHub. Skills reach issues, PRs, parent, sub-issue and dependency data through `gh`, by the simplest command for each operation ([ADR-006](ADR-006-engineering-runs-in-t3-code-threads.md)).
- A different tracker needs a new tracker profile and a new status script.
- A repo that used the retired labels (`status:ready`, `status:in-progress`, `status:needs-review`, `umbrella`) keeps them until its owner deletes them by hand; no script or skill reads them.
- An open issue that is not labelled `engineering:shaped` is a request, so an issue shaped before the label existed needs the label added by hand or a new discuss run.
- Work can resume from any device that reaches the T3 Code host, including a phone.
- The Blocked icon shows in the GitHub web issue list, but not in the GitHub mobile app.
- `status.sh` reads blockers from each issue's `blockedBy` connection and its branches from the `linkedBranches` connection, in the one query that reads the open issues. GitHub's search API did not return `is:blocked` results. Its list of merged remote branches, which the user reads to clean up, is still read by the `<n>-` name.
