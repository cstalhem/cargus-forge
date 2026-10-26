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

**Status**: Where an open issue or umbrella issue stands in the process: request, umbrella, ready, blocked, in progress or needs review. A label shows it, and `next` repairs a label that the facts contradict.
_Avoid_: state

**Request**: An open GitHub issue with none of the plugin's labels, so discuss has not shaped it yet.

**Finished worktree**: A local worktree on an issue branch whose PR has merged or whose issue is closed, with no uncommitted or unpushed work; `next` removes it after you confirm.
_Avoid_: stale worktree

**Verdict**: The result verify gives a PR or a feature branch: PASS, FAIL, or PENDING when a PR's check runs have not all completed.
_Avoid_: conclusion

**Repo profile**: The files in a repo's `docs/agents/` that hold its own facts for the plugin's skills: its commands and its issue tracker; setup writes them, and the plugin's contract stays in the plugin.
_Avoid_: repo config, agent docs
