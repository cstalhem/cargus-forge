# Glossary

**Size test**: The four checks that decide whether a piece of work fits one session.

**Shape**: The phases that turn a request into issues, from discuss through slice.

**Build**: The phases that take one issue to a merged PR: execute, verify, then merge. For an umbrella issue, ship comes last.

**Issue**: A unit of work that fits one session: a single issue or a sub-issue. An umbrella issue is not one.
_Avoid_: task, ticket

**Single issue**: An issue with no umbrella issue; its PR goes into `main`.

**Umbrella issue**: The one record of a feature that needs more than one session: goal, scenarios, decisions, design and out of scope.
_Avoid_: epic

**Sub-issue**: An issue under an umbrella issue; its PR goes into the feature branch.
_Avoid_: child issue, ticket

**Scenario**: One acceptance criterion written as `WHEN … THEN …`; each one becomes a test.
_Avoid_: test case, user story

**Feature branch**: The branch of an umbrella issue, which its sub-issue PRs merge into.

**Final PR**: The one PR that takes a feature branch into `main`; ship opens it.

**Status**: Where an open issue or umbrella issue stands in the process: request, umbrella, ready, blocked, in progress or needs review. `next` works it out from the issue's body, links, branches and PRs.
_Avoid_: state

**Request**: An open GitHub issue whose body has neither a `## Scenarios` nor a `## Goal` section, so discuss has not shaped it yet.

**Finished worktree**: A local worktree on an issue branch whose PR has merged or whose issue is closed, with no uncommitted or unpushed work; `next` removes it after you confirm.
_Avoid_: stale worktree

**Verdict**: The result verify gives a PR or a feature branch: PASS, FAIL, or PENDING when a PR's check runs have not all completed.
_Avoid_: conclusion

**Repo profile**: The file `docs/agents/commands.md`, which holds a repo's commands for the plugin's skills; setup writes it, and the plugin's contract stays in the plugin.
_Avoid_: repo config, agent docs

**Optional behaviour**: A per-repo behaviour of the plugin that is on when its file is in the repo, such as `.github/workflows/close-sub-issue.yml`; setup offers each one.
_Avoid_: feature flag, option

**Conversion issue**: The one request that setup creates after a yes, which lists each conversion item it reported with a suggested action. A conversion item is something in an existing repo that differs from the plugin's process: an open issue's colliding branches, another branch convention, ADRs or a glossary that the plugin cannot see, or a line that conflicts with the contract.

**Challenge**: The first round of discuss, which asks whether a request needs to exist and gives each of its requirements, with its source, a verdict of keep, simplify or delete, before any question about how to build it.

**Gap**: A scenario, `Term` row or `ADR` row that verify grades as failing, with the check that failed (exists, substantive or wired) and why.

**Designated branch**: The branch that a Claude Code cloud session's system prompt names for it to push to; when a session has one, it is the issue branch.

**Issue branch**: The branch that holds one issue's work and is the head of its PR: `<n>-<slug>`, or the designated branch in a cloud session that names one.

**ADR decision**: A line in an issue's `## Decisions` that tells execute to write a new ADR or edit an existing one in `docs/adr/`, holding the decision and its rejected alternatives.
