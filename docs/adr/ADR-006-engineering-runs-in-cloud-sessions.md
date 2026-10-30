---
adr: 006
title: Engineering runs in cloud sessions
status: active
---

# ADR-006: Engineering runs in cloud sessions

- **Decision:** Every engineering skill runs end to end in a Claude Code cloud session, where the agent proxy refuses GraphQL and `git/refs` writes. Skills read and write GitHub through `gh api` REST on every surface, use a fallback for the one operation that exists only in GraphQL, create branches with `git push`, and find branches by their names in git.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md), [ADR-002](ADR-002-feature-branch-per-umbrella.md)
- **Records:** #78 D1, D4, D5, D7 and D9 to D16. D2, D3 and D6 are replaced, and so is D10's linked branch (see Rejected alternatives). Also #144 D1, #181 D3 and D5, and #185 D1 and D2.

## Details
- **What the cloud refuses:** GraphQL, with HTTP 403 and a message that points to REST and to the CCR routes `POST pulls/<n>/ccr/ready_for_review`, `POST pulls/<n>/ccr/convert_to_draft`, `PUT` and `DELETE pulls/<n>/ccr/auto_merge`, and `GET pulls/<n>/ccr/review_threads`. Also `POST` and `DELETE git/refs` (HTTP 403), and deleting a branch with `git push`. That breaks `gh pr ready` and every `gh issue` and `gh pr` command that reads or writes through GraphQL.
- **What the cloud allows:** REST writes to issues, comments, `sub_issues`, `dependencies` and pulls, and creating a branch with `git push`.
- **Reads** go through `gh api` REST on every surface, local and cloud: `issues/<n>`, `/parent`, `/sub_issues`, `/dependencies/blocked_by`, `pulls/<n>` and `pulls?base=<base>`. No skill reads with `gh issue view`, `gh pr view` or `gh pr list`, so reads need no minimum `gh` version (D1).
- **Lists** are read page by page (D15). Each list call passes `per_page=100` on the `repos/{owner}/{repo}` path, and reads `page=2` and onward while a page holds 100 items. No skill uses `gh api --paginate`, because it follows GitHub's next-page link, which uses a numeric-ID path (`repositories/<id>/…`) that the cloud proxy refuses. The close-sub-issue workflow keeps `--paginate`, because it runs in GitHub Actions.
- **Writes** go through `gh api` REST on every surface, like reads (D9). Each body is written to a file first and passed as `-F body=@<path>`. No skill calls a GitHub MCP tool, `gh issue create`, `gh issue edit`, `gh issue comment`, `gh pr create` or `gh pr comment`.
  - discuss creates an issue with `POST issues` and rewrites it with `PATCH issues/<n>`. execute and ship open a PR with `POST pulls`, execute with `draft: true`. execute rewrites the title and body of a PR that is already open with `PATCH pulls/<pr>`. verify posts with `POST issues/<n>/comments`.
  - Every write is read back through REST. If a required fact is missing (a sub-issue's parent, a blocked-by link, a PR's base and draft state, a posted comment, a created branch), the skill stops and names the gap.
- **Marking a PR ready exists only in GraphQL** (D10). A skill tries `gh pr ready` first, and on the GraphQL 403 runs `POST pulls/<n>/ccr/ready_for_review`.
- **Branches** are created the same way on every surface (#181 D5): `git push origin <sha>:refs/heads/<n>-<slug>`, after `git fetch origin <base>` only when `<sha>` is `origin/<base>` (#212 D2). No branch is linked to its issue, because no REST route links one.
- **The feature branch** is found by its name in git (D4). execute, verify and ship take the one remote branch from `git ls-remote --heads origin` that matches the plugin's fixed `<n>-<slug>` pattern (`references/issue-tracker.md`) for the umbrella's number. They stop if none or more than one match.
- **The issue branch in a cloud session** depends on whether the session's system prompt names a designated branch. execute knows it is in a cloud session when `printenv CLAUDE_CODE_REMOTE` prints `true`, and then enters no worktree (#185 D2). The container serves one session and is discarded, so a worktree adds no isolation.
  - With a designated branch, that branch is the issue branch (D5). execute creates no `<n>-<slug>` branch, and opens the draft PR against the base. The PR's first line ties the branch to the issue (ADR-002). On resume, execute finds the open PR whose head is the current branch and whose first line names the issue. It then fetches the base and the branch, fast-forwards the local branch with `git merge --ff-only` if it is behind, and stops and asks if they have diverged, the fetch fails or the fast-forward fails.
  - With no designated branch, the issue branch is the issue's `<n>-<slug>` branch, as locally (#185 D1). execute needs a checkout with no changes and no commits that are not on a remote, and otherwise stops and asks. If `git ls-remote` lists no issue branch, execute creates it from the base with `git push`. If it lists one, execute fetches it. Either way, execute switches to it with `git switch` in the current directory. On resume, it syncs and reads `git log --oneline origin/<base>..HEAD`. The `<n>-<slug>` name keeps the branch findable by name for `next`, slice and a later execute run.
- **Blockers** are GitHub "blocked by" links (D11). slice sets each parent link with `POST issues/<umbrella>/sub_issues` and each blocked-by link with `POST issues/<n>/dependencies/blocked_by`, both with the other issue's `id`, and reads each one back. A sub-issue's body does not list its parent or its blockers, so slice writes no text that could disagree with a link (#181 D3). execute reads blockers from the links only.
- **The work so far** is found on the current branch (D12). execute's size-test stop hands off to slice or discuss in the same session, so the current branch is the issue branch: `<n>-<slug>` locally and in a cloud session with no designated branch, and the designated branch in a cloud session that names one. A re-split reads the work from there.
- **The size-test stop** opens a draft PR for a sub-issue, on both surfaces (D16). execute pushes the work and opens the PR with the same title, first line, base and read-back as its PR step. A later run on the narrowed sub-issue then takes the existing resume path: the open PR whose first line names the issue in a cloud session with a designated branch, and the issue branch otherwise. Its PR step rewrites the title and body with `PATCH pulls/<pr>` and reads them back. A single issue gets no PR, because its branch becomes the feature branch.
- **A single issue that becomes an umbrella** keeps its work so far as the start of the feature branch, on both surfaces (D13). If the issue's own `<n>-<slug>` branch exists, slice makes it the feature branch. If not, as in a cloud session with a designated branch, slice creates the feature branch from the current branch's head, not `main`. Its plan lists those commits, so you can drop them. slice treats a detached `HEAD` with no commits beyond `main` as no work so far, and creates the feature branch from `main`. It stops and asks if a detached `HEAD` holds commits (#185).
- **Checks:** where `gh pr checks --watch` is refused, ship reads `commits/<sha>/check-runs` once through REST, shows which checks passed, failed or are pending, and stops without waiting (D7).
  - verify reads the same check runs once in PR scope, after its grading agent returns, and does not wait either (#144 D1). A failed run fails the verdict, and a pending run gives a PENDING verdict that keeps the PR a draft, so you run execute again once CI has finished.
- **The cloud footer** (D14): in a cloud session, every issue, PR and comment body written through REST gets a `---` line and a `_Generated by Claude Code_` footer. The server adds it and never stacks it on a rewrite. The footer is not part of the body's last section: readers ignore it, and read-backs compare without it.

## Rejected alternatives
- **Write with `gh` first and fall back to the GitHub MCP tools after the first refusal, with each body in the tool's text parameter** (#78 D2 and D3, replaced by D9): the proxy allows the REST writes the skills need. Only GraphQL and `git/refs` writes are refused, and D10 covers the two GraphQL operations. A second write path doubles what each skill must handle, and the MCP tools can neither link a branch nor set a blocked-by link.
- **Blockers only as first-line text, with a link-blocked-by workflow that turns the text into links, and execute reading the union of links and text** (#78 D6, replaced by D11): the proxy allows `POST issues/<n>/dependencies/blocked_by`, so slice sets the links itself. A workflow is extra setup in each repo, and two sources can disagree.
- **After a size-test stop, resume from commits tied to the issue** (#78 D16): no convention ties a commit to an issue.
- **Create a branch linked to its issue through GraphQL, and fall back to `git push` on the 403** (#78 D10, replaced by #181 D5): no REST route links a branch, so the link exists only on some surfaces, and the lookup by name makes it unneeded. Two ways to create one branch double what each skill must handle.
- **A user token to authenticate `gh` in the cloud:** the refusals come from the proxy's policy, not from missing authentication, so a token does not lift them.
- **Find the feature branch by its link to the issue:** reading the link needs GraphQL, no skill creates the link, and deleting a merged branch also removes it.
- **A line in the umbrella body that names the feature branch:** it is hand-written state (ADR-001), and `formats.md` allows no extra section.
- **Strip the cloud footer before a write, or remove it after:** the server adds it to every body written through REST, and it does not stack. Readers ignoring it is enough.
- **Wait for checks in the cloud:** the session stays busy for the whole CI run. A report and a stop let you run ship again when CI is done.
- **Stop with a message when a cloud session names no designated branch:** it blocks every such session and gains nothing, because the container serves one session and needs no worktree.
- **Recognise a cloud session from the wording of its system prompt:** the wording can change. `CLAUDE_CODE_REMOTE` is a fact that a command can check.

## Consequences
- discuss, slice, execute, verify and ship work the same on the desktop, under Remote Control and in a cloud session, including one driven from the phone.
- A cloud session needs no GitHub MCP tools, and reads and writes need no minimum `gh` version.
- Every blocker is a GitHub link on every surface, so the Blocked icon shows for it.
- No branch is linked to its issue. The branch name and the PR's first line carry that tie.
- A cloud session cannot delete a branch. A merged branch stays until GitHub or a person deletes it.
- Bodies written in a cloud session end with the footer, and any skill that reads a body must skip it.
- A deleted feature branch makes execute, verify and ship stop with a reason, because no remote branch matches.
