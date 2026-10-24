---
adr: 002
title: One feature branch for each umbrella issue
status: active
---

# ADR-002: One feature branch for each umbrella issue

- **Decision:** Each umbrella issue gets a feature branch. Sub-issue PRs merge into that branch, and a workflow closes each sub-issue when its PR merges. One final PR merges the feature into `main` and closes the umbrella issue.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md)
- **Design notes:** [process.md, ship](../engineering-plugin/process.md#ship-build-for-an-umbrella-issue)

## Details
- **Branch names:** the feature branch is `38-export-to-s3`, taken from `main`. When a single issue with work so far becomes an umbrella, the feature branch starts from that work instead ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)). A sub-issue branch is `39-export-job`, taken from the feature branch, with one worktree for each active sub-issue. In a cloud session, the sub-issue branch is the session's designated branch instead ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- **Finding the feature branch:** execute, verify and ship take the one remote branch whose name matches the pattern for the umbrella's number. They need no link between the branch and the issue. A skill creates a branch with `gh issue develop`, which links it, or with `git push` and no link where GraphQL is refused ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- **Closing keywords:** GitHub reads them only on PRs into the default branch, so a sub-issue PR into the feature branch closes nothing on its own.
- **The close-sub-issue workflow** closes the sub-issue instead. It runs when a PR merges into a branch other than the default branch, reads the `Sub-issue #<n> of #<umbrella>` first line, and closes `#<n>` as completed if it is a sub-issue of `#<umbrella>`. It uses only `gh` and the repo's token, with `issues: write`.
  - It is optional for each repo: the file being in `.github/workflows/` is the setting. The plugin ships it as `plugins/engineering/templates/close-sub-issue.yml`, the source of truth, and this repo runs a byte-identical copy.
  - A workflow runs from the copy on the PR's base branch, so a feature branch cut before the workflow landed closes no sub-issue until it merges `main`. Its final PR closes them.
- **The final PR body** has one `Closes #n` line for each sub-issue that is still open, and one for the umbrella. Where the workflow runs, that is usually only the umbrella.
- **Umbrella-scope verify** runs on the feature branch and gates the final PR. A gap between sub-issues is found before it reaches `main`.
- `main` is merged into the feature branch before the final PR, and also when the branch falls behind. Merge, not rebase.
- A one-session issue with no umbrella uses a branch from `main` and one PR into `main` with `Closes #n`.

## Rejected alternatives
- **One PR for each sub-issue into `main`** (trunk-based): smaller batches, but a feature reaches `main` in parts. A feature must land on `main` as one item.
- **One branch and one PR for each umbrella:**
  - one large review;
  - one branch cannot be checked out in two worktrees, so sub-issues cannot run in parallel;
  - verify has no PR to report on.
- **Close sub-issues only at the final PR:** every downstream sub-issue reads as blocked until ship, the umbrella shows no progress, and agents must reason about whether an open blocker is done.
- **A label for merged sub-issues:** it fixes neither GitHub's Blocked icon nor the umbrella's progress bar, and it is a second status to repair.
- **Match the sub-issue from the head branch name:** cloud sessions name branches `claude/…`, so the name is unreliable.

## Consequences
- A feature branch can drift from `main` while a feature is in progress.
- Sub-issue PRs need CI on the feature branch, or problems first show on the final PR, after every sub-issue has merged. This repo runs its plugin checks on every PR, and `version-bump` compares against `main`, so a feature branch bumps each plugin once, sized to the whole umbrella. Branch protection still requires the checks only on `main`.
- GitHub's Blocked icon, the umbrella's progress bar and the issue list show merged sub-issues as done. The umbrella stays open until the final PR, so it records whether the feature is on `main`.
- A closed sub-issue on an abandoned feature branch reads as done. The umbrella, closed as not planned, records that.
- In a repo without the workflow, the final PR's `Closes` lines close the sub-issues. execute and ship look for a sub-issue's merged PR, not only its state, so they work either way.
- A PR from a fork gets a read-only token, so the workflow fails and the sub-issue waits for the final PR.
- Unfinished features never reach `main`, so slices need no feature flags.
