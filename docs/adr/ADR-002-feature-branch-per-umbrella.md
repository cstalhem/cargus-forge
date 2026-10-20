---
adr: 002
title: One feature branch for each umbrella issue
status: active
---

# ADR-002: One feature branch for each umbrella issue

- **Decision:** Each umbrella issue gets a feature branch. Sub-issue PRs merge into that branch. One final PR merges the feature into `main` and closes every sub-issue and the umbrella issue.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md)
- **Design notes:** [process.md, ship](../engineering-plugin/process.md#ship-build-for-an-umbrella-issue)

## Details
- **Branch names:** the feature branch is `38-export-to-s3`, taken from `main`. A sub-issue branch is `39-export-job`, taken from the feature branch, with one worktree for each active sub-issue.
- **Closing keywords:** GitHub reads them only on PRs into the default branch, so a sub-issue PR into the feature branch closes nothing. The final PR body has one `Closes #n` line for each sub-issue and one for the umbrella.
- **Umbrella-scope verify** runs on the feature branch and gates the final PR. A gap between sub-issues is found before it reaches `main`.
- `main` is merged into the feature branch before the final PR, and also when the branch falls behind. Merge, not rebase.
- A one-session issue with no umbrella uses a branch from `main` and one PR into `main` with `Closes #n`.

## Rejected alternatives
- **One PR for each sub-issue into `main`** (trunk-based): smaller batches, but a feature reaches `main` in parts. A feature must land on `main` as one item.
- **One branch and one PR for each umbrella:**
  - one large review;
  - one branch cannot be checked out in two worktrees, so sub-issues cannot run in parallel;
  - verify has no PR to report on.

## Consequences
- A feature branch can drift from `main` while a feature is in progress.
- A sub-issue stays open after its PR merges into the feature branch, until the final PR merges. The derived status "merged" covers this time.
- Unfinished features never reach `main`, so slices need no feature flags.
