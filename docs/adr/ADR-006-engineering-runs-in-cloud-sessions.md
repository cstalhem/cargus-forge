---
adr: 006
title: Engineering runs in cloud sessions
status: active
---

# ADR-006: Engineering runs in cloud sessions

- **Decision:** Every engineering skill runs end to end in a Claude Code cloud session, where the agent proxy refuses GraphQL and many `gh` writes. Skills read GitHub through `gh api` REST, try each write with `gh` and fall back to the GitHub MCP tools, and find branches and blockers from git and issue text instead of from links that they cannot set there.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md), [ADR-002](ADR-002-feature-branch-per-umbrella.md)
- **Design notes:** [process.md, execute](../engineering-plugin/process.md#execute-build)

## Details
- **What the cloud refuses:** GraphQL (HTTP 403), and REST writes through `gh api` such as `POST git/refs` and `issues/<n>/dependencies/blocked_by`. That breaks `gh issue develop`, `gh pr ready` and the `parent`, `subIssues` and `blockedBy` fields of `gh issue view`. The GitHub MCP tools work there, but they have no dependency tool and cannot link a branch to an issue.
- **Reads** go through `gh api` REST on every surface, local and cloud: `issues/<n>`, `/parent`, `/sub_issues`, `/dependencies/blocked_by`, `pulls/<n>` and `pulls?base=<base>`. No skill reads with `gh issue view`, `gh pr view`, `gh pr list` or `gh issue develop --list`.
- **Writes** try `gh` first. After the first refusal (a GraphQL 403 or a proxy refusal), the skill loads the GitHub MCP tools with ToolSearch, does the same operation through MCP, and uses MCP for the rest of the run. When every `gh` write succeeds, the skill calls no MCP tool.
  - One rule in `references/rules.md` names the fallback. The tools' own descriptions pick the tool.
  - A body or comment written through MCP goes in the tool's text parameter. The `--body-file` rule applies only to `gh`.
  - Every write is read back through REST, on either path. If a required fact is missing (a sub-issue's parent, a PR's base and draft state, a posted comment, a created branch), the skill stops and names the gap.
- **The feature branch** is found by its name in git. execute, verify and ship take the one remote branch from `git ls-remote --heads origin` that matches the `issue-tracker.md` pattern for the umbrella's number. They stop if none or more than one match. slice creates the branch with `gh issue develop`, or through MCP when that is refused.
- **The issue branch in a cloud session** is the session's designated branch. execute enters no worktree, creates no `<n>-<slug>` branch, and opens the draft PR against the base. The PR's first line ties the branch to the issue (ADR-002). On resume, execute finds the open PR whose head is the current branch and whose first line names the issue.
- **Blockers** are written only as text, in the sub-issue's first line: `Sub-issue of #<umbrella> · Blocked by #<a>, #<b>`. No skill sets a dependency link.
  - The link-blocked-by workflow turns that text into GitHub "blocked by" links. It runs on `issues: opened, edited`, so every write from slice or discuss triggers it, and no skill calls it. It only adds links.
  - The workflow is optional for each repo, like close-sub-issue (ADR-002). execute takes the union of the API's blocked-by links and the first-line text, so it works in a repo without the workflow.
  - slice reads each sub-issue's blocked-by links back through REST, and names each missing link instead of reporting it as set.
- **Checks:** where `gh pr checks --watch` is refused, ship reads `commits/<sha>/check-runs` once through REST, shows which checks passed, failed or are pending, and stops without waiting.

## Rejected alternatives
- **MCP first whenever its tools are present:** `gh` works on every local surface without an MCP server. MCP is needed only where `gh` is refused.
- **A user token to authenticate `gh` in the cloud:** the refusals come from the proxy's policy, not from missing authentication, so a token does not lift them.
- **A table that maps each `gh` command to an MCP tool name:** it goes stale when a tool changes. The tools' descriptions pick the tool, and the REST read-back proves the result.
- **Find the feature branch with `gh issue develop --list`:** it needs GraphQL, a cloud session cannot link a branch to an issue, and deleting a merged branch also removes the link.
- **A line in the umbrella body that names the feature branch:** it is hand-written state (ADR-001), and `formats.md` allows no extra section.
- **Set blockers from the skill with `--blocked-by` or the REST dependency API:** `gh issue create` 2.89 has no `--blocked-by` flag, the proxy refuses the dependency write, and the MCP server has no dependency tool.
- **Wait for checks in the cloud:** the session stays busy for the whole CI run. A report and a stop let you run ship again when CI is done.

## Consequences
- discuss, slice, execute, verify and ship work the same on the desktop, under Remote Control and in a cloud session, including one driven from the phone.
- Reads need no minimum `gh` version.
- A cloud session needs the GitHub MCP tools. Without them, a refused write cannot complete.
- In a cloud session, no branch is linked to its issue. The PR's first line and the branch name carry that tie.
- In a repo without the link-blocked-by workflow, blockers exist only as text. GitHub's Blocked icon does not show for them, but execute still waits for them.
- A deleted feature branch makes execute, verify and ship stop with a reason, because no remote branch matches.
