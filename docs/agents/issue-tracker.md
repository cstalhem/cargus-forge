# Issue tracker

- **Repo:** GitHub, `cstalhem/cargus-forge`. Default branch: `main`.
- **Branch pattern:** `<n>-<slug>`, the form `gh issue develop` makes. Create every branch with `gh issue develop <n> --name <n>-<slug> --base <base>`, so it is linked to its issue.
  - Skills find a branch by its name, not by its link, because the link cannot be read or made on every surface. The branch of issue `#<n>` is the one remote branch that `git ls-remote --heads origin 'refs/heads/<n>-*'` lists. None, or more than one, is an error.
  - Feature branch of an umbrella issue: base `main`.
  - Sub-issue branch: base the umbrella's feature branch.
  - Single issue: base `main`.
  - In a session with a designated branch it must push to, such as a Claude Code cloud session, the issue branch is that designated branch, whatever its name. execute creates no `<n>-<slug>` branch there. The PR's first line ties the branch to its issue, and execute finds earlier work through the open PR whose head is the designated branch ([ADR-006](../adr/ADR-006-engineering-runs-in-cloud-sessions.md)).

## Merging
Squash-merge every PR: sub-issue PRs into the feature branch, and single-issue and final PRs into `main`. Each PR becomes one commit, and `main` stays linear. The squash message is the PR title and description. A feature branch takes `main` in by merge, never by rebase (ADR-002); a squash applies only the end result, so those merge commits cause no conflicts.

## PR targets and `Closes` lines
GitHub reads closing keywords only on PRs into `main` ([ADR-002](../adr/ADR-002-feature-branch-per-umbrella.md)).

| PR | Target | `Closes` lines |
|---|---|---|
| Sub-issue PR | the umbrella's feature branch | none; it would close nothing |
| Single-issue PR | `main` | `Closes #<issue>` |
| Final PR of an umbrella | `main` | one `Closes #<n>` for each sub-issue that is still open, and one for the umbrella |

## Closing sub-issues
`.github/workflows/close-sub-issue.yml` closes a sub-issue as completed when its PR merges into a branch other than `main`. It reads the `Sub-issue #<n> of #<umbrella>` first line that execute writes, and closes `#<n>` only if it is a sub-issue of `#<umbrella>`. The file is a byte-identical copy of `plugins/engineering/templates/close-sub-issue.yml`: change the template, then copy it.
