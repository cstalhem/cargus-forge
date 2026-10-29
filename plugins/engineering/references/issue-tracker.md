# Issue tracker

The plugin's contract for branches, merging and PRs. It is the same in every repo, and it takes `main` as the default branch.

## Branches
- **Branch pattern:** `<n>-<slug>`. It is fixed, and a repo cannot set its own. Create a branch the same way on every surface: run `git push origin <sha>:refs/heads/<n>-<slug>`, with `origin/<base>` as `<sha>`, or `HEAD` when the branch starts from the current branch's head and the current branch is `<base>`. Before the push, run `git fetch origin <base>` only when `<sha>` is `origin/<base>`, so that the push of `HEAD` works when the current branch was never pushed. The branch has no link to its issue.
  - Skills find a branch by its name, because no branch is linked to its issue. The branch of issue `#<n>` is the one remote branch that `git ls-remote --heads origin 'refs/heads/<n>-*'` lists. None, or more than one, is an error.
  - Feature branch of an umbrella issue: base `main`. When a single issue with work so far becomes an umbrella and the user keeps those commits, slice reuses the issue's own branch as the feature branch. Only when no such branch exists, as in a cloud session, does slice create the feature branch from the current branch's head, with the current branch as base.
  - Sub-issue branch: base the umbrella's feature branch.
  - Single issue: base `main`.
  - In a session with a designated branch it must push to, such as a Claude Code cloud session, the issue branch is that designated branch, whatever its name. execute creates no `<n>-<slug>` branch there. The PR's first line ties the branch to its issue, and execute finds earlier work through the open PR whose head is the designated branch. Before it resumes, execute fetches and fast-forwards, and stops if the fetch fails, the fast-forward fails or the branches have diverged.

## Merging
Squash-merge every PR: sub-issue PRs into the feature branch, and single-issue and final PRs into `main`. Each PR becomes one commit, and `main` stays linear. The squash message is the PR title and description. A feature branch takes `main` in by merge, never by rebase; a squash applies only the end result, so those merge commits cause no conflicts.

## PR targets and `Closes` lines
GitHub reads closing keywords only on PRs into `main`, the default branch.

| PR | Target | `Closes` lines |
|---|---|---|
| Sub-issue PR | the umbrella's feature branch | none; it would close nothing |
| Single-issue PR | `main` | `Closes #<issue>` |
| Final PR of an umbrella | `main` | one `Closes #<n>` for each sub-issue that is still open, and one for the umbrella |

## Closing sub-issues
Where a repo has `.github/workflows/close-sub-issue.yml`, it closes a sub-issue as completed when its PR merges into a branch other than `main`. It reads the `Sub-issue #<n> of #<umbrella>` first line that execute writes, and closes `#<n>` only if it is a sub-issue of `#<umbrella>`. The file is a byte-identical copy of the plugin's `templates/close-sub-issue.yml`. A repo without it leaves a merged sub-issue open, and the final PR closes it.
