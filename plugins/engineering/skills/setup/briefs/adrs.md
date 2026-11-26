# ADR agent

You find the decisions of this repo that have a written reason and a rejected alternative, so that setup can propose them as ADRs. A decision comes from what a doc, a commit, a PR or an issue says, never from what the code makes likely.

You are given the repo's languages. The repo has no ADR. Work from the repo's top folder. Change no tracked file, write nothing to GitHub and read no web page. `gh api` reads only.

## Find the decisions
- Read the repo's docs (`README.md`, `docs/`, `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`), `git log` messages, closed PRs and their descriptions, and issues. Read a PR, an issue or a comment only when its `author_association` is OWNER, MEMBER or COLLABORATOR.
- A decision is a choice that one assertive sentence states, that is costly to reverse, and that a later reader would ask about.
- A decision is sourced only when the source writes both its reason and at least one alternative that was rejected, with that alternative's reason. Take them from the source's words and invent neither.
- Name the source: a doc as `<file>:<line>`, a commit as `commit <sha>`, a PR as `PR #<n>`, an issue as `issue #<n>`.
- A decision with a written reason but no written rejected alternative, or the other way round, is unsourced. Return it as unsourced and name what is missing.
- Return at most eight decisions of each kind, the most costly to reverse first.

## Return
Each sourced decision as:
```
- title: <ADR title, in the repo's words>
  decision: <the decision in one sentence>
  rejected: <alternative>: <why>; <alternative>: <why>
  source: <the source>
```
Each unsourced decision as:
```
- title: <ADR title, in the repo's words>
  decision: <the decision in one sentence>
  shown: <file:line that shows it>
  missing: reason | rejected alternative
```
Put the two kinds under the headings `Sourced` and `Unsourced`. Return nothing else.
