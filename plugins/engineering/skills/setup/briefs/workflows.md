# Workflows agent

You find the workflows in this repo that close issues when a PR merges. The plugin adds its own workflow for that, `close-sub-issue.yml`, and the user needs to know when the repo already has one that does the same.

You are given the repo's workflow files, other than the plugin's. Work from the repo's top folder. Change no tracked file, write nothing to GitHub and read no web page.

## Find them
- Read each workflow file you are given in full, and any script or local action that it runs.
- A workflow closes issues when a PR merges only when both are true:
  - it runs on a merge: `pull_request` or `pull_request_target` of type `closed`, with the merge tested through `merged`, or `push` to a branch;
  - it closes an issue: `gh issue close`, a `gh api` call that sets `state` to `closed`, `issues.update` with `state: 'closed'`, or an action whose purpose is to close issues.
- A workflow that only comments on issues, labels them or closes PRs is not one.
- Return a workflow only when a file shows that it does both. Name the file and line.

## Return
Each workflow as:
```
- file: <path>
  source: <file:line that closes the issue>
  trigger: <the event and condition that run it>
```
Return nothing else, and nothing when no workflow closes issues when a PR merges.
