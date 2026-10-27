---
name: execute
description: Take one ready issue to a draft PR, in the session's worktree locally or on the session's designated branch in a cloud session. Gets onto the issue branch, builds until the issue's verify command passes, opens the draft PR, then calls verify.
argument-hint: "<#issue>"
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(cat docs/glossary.md 2>/dev/null || printf '\342\200\213')
---

# execute

Issue: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Locally, use the session's worktree. Do not make a second one, and do not move or rename its directory, because that breaks the running session. In a cloud session, use the designated branch in the current directory, and enter no worktree.
- Run plain git commands, one at a time, in the current directory: no `cd … &&` and no `git -C`. Claude Code blocks git commands that it cannot confirm stay inside the worktree.
- Deviations:
  1. A bug in the way of the issue: fix it, and name the fix in the PR.
  2. A missing guard that the issue needs: add it, and name it in the PR.
  3. A broken check or tool that blocks the issue: fix it.
  4. A change to the architecture or to a scenario: stop and ask.
  5. The issue fails the size test: stop. Name the criterion that fails and what you found. Commit and push the work so far with `git push -u origin <branch>`. Then:
     - a sub-issue: if the branch has no open PR, open a draft PR as in step 5, with the same title, first line, base and read-back. Its body is the first line and one line that names the failing criterion. A later run on the narrowed sub-issue then resumes, from this PR in a cloud session and from the issue branch locally, and its step 5 rewrites the PR's title and body. Then call the Skill tool with `engineering:slice`, `#<n>` and the failing criterion with your findings. After slice ends, tell the user to run `/engineering:execute #<n>` again.
     - a single issue: open no PR, because its branch becomes the feature branch. Tell the user to run `/engineering:discuss #<n>`, which turns it into an umbrella issue.
  6. A new domain name that the code needs and that no `Term` decision and no glossary entry covers, or a rename of a domain name: if it passes the gate in `domain-model`, add or edit its entry in `docs/glossary.md` in the same PR, as `domain-model` says, and name the entry under the PR's `## Deviations`.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md`, `${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md`, `docs/agents/commands.md` and `docs/agents/issue-tracker.md`. Run `gh api repos/{owner}/{repo}/issues/<n>`, `gh api repos/{owner}/{repo}/issues/<n>/parent` and `gh api 'repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by?per_page=100'`. Stop and say why if the issue is closed or has no `## Scenarios` or `## Verify` section. Call the Skill tool with `engineering:domain-model` and `execute`, every time, not only when a term comes up.
   - **Repo profile:** if the repo has no `docs/agents/`, tell the user to run `/engineering:setup`, which writes it, and go on with the defaults: the default branch is `main`, and the issue's Verify command is the only check.
   - **Base:** for a sub-issue, the parent's feature branch: the one branch that `git ls-remote --heads origin 'refs/heads/<parent>-*'` lists, by the branch pattern in `references/issue-tracker.md`. Stop if it lists none, or more than one. For a single issue, the default branch in `docs/agents/issue-tracker.md`, else `main`.
   - **Blockers:** read the issue's blockers, and their state, from its `dependencies/blocked_by` links only. The `Blocked by` part of the first line is for readers. If an open issue blocks a single issue, stop. If one blocks a sub-issue, list the merged PRs into the base with `gh api 'repos/{owner}/{repo}/pulls?base=<base>&state=closed&per_page=100' --jq 'length, (.[] | select(.merged_at) | {number, body})'`, page by page as the rules say. A repo without the close-sub-issue workflow leaves a merged sub-issue open, so an open blocker counts as merged when a merged PR's first line names it as its issue ("Sub-issue #<b> of" or "for #<b>"). A mention elsewhere in a body does not count. Name each such PR and go on. Stop and name each open blocker that has no such PR.
   - **Terms:** the issue's `Term` decisions are its own `D<n> · Term:` lines, and each `#<umbrella> D<n>` line in its `## Decisions` whose decision in the umbrella is a `Term` decision. Read that decision's text in the body that the `/parent` call returns.
2. **Worktree.** Run `git rev-parse --abbrev-ref HEAD`, `git rev-parse --absolute-git-dir`, `git rev-parse --path-format=absolute --git-common-dir`, `git status --porcelain`, `git rev-list HEAD --not --remotes` and `git ls-remote --heads origin 'refs/heads/<n>-*'`, which lists the issue's branch. The session is in a worktree when the git dir and the common dir differ.
   - **Sync:** the cases below that say "sync" run these on the issue branch `<branch>`:
     1. Run `git fetch origin <base> <branch>`. If it fails, for example because `<branch>` is not on the remote, stop and ask.
     2. Run `git rev-list --left-right --count HEAD...origin/<branch>`, which counts the commits only on `HEAD` and only on `origin/<branch>`. If they have diverged (both counts above 0), stop and ask. If `HEAD` is behind `origin/<branch>`, run `git merge --ff-only origin/<branch>`, and stop and ask if it fails.
   - **In a session with a designated branch it must push to** (a Claude Code cloud session names one in its system prompt): that branch is the issue branch, and the cases after this one do not apply. Enter no worktree and create no `<n>-<slug>` branch. Stop if `HEAD` is not on the designated branch. List its open PR with `gh api 'repos/{owner}/{repo}/pulls?head={owner}:<branch>&state=open&per_page=100'`.
     - **An open PR whose first line names #<n>** ("Sub-issue #<n> of" or `Closes #<n>`): resume. Stop and ask if the PR's base is not `<base>`. Sync as above. Then read `git log --oneline origin/<base>..HEAD` to see what is done.
     - **No open PR, with no changes and no commits that are not on a remote:** start the branch at the base, so the PR holds only this issue's work. Run `git fetch origin <base>`. If `git ls-remote --heads origin 'refs/heads/<branch>'` lists the branch, run `git fetch origin <branch>`, and stop and ask if `git log --oneline origin/<base>..origin/<branch>` shows commits. Then run `git reset --hard origin/<base>`.
     - **Anything else** (an open PR for another issue, changes, or commits that are not on a remote): stop, show what the branch holds, and ask.
   - **On the issue's branch:** resume. Sync as above. Then read `git log --oneline origin/<base>..HEAD` to see what is done.
   - **In a worktree on another issue's branch whose PR has merged, with no changes and `HEAD` at that PR's last commit (`head.sha` from `gh api 'repos/{owner}/{repo}/pulls?state=closed&per_page=100&head={owner}:<that branch>' --jq 'length, (.[] | select(.merged_at) | .head.sha)'`):** say so, and ask whether to reuse this worktree for #<n>. On yes, go on as in the case of a worktree on its own new branch, and delete the old issue's local branch. On no, stop.
   - **Not in a worktree:** enter a new one with the EnterWorktree tool, then go on as in the next case.
   - **In a worktree on its own new branch (Remote Control names it `worktree-…`), with no changes and no commits that are not on a remote:**
     1. If `git ls-remote` lists no branch for the issue, create `<n>-<slug>` from `<base>` as the rules say, with the branch pattern from `references/issue-tracker.md`.
     2. Sync as above, and run `git switch <branch>` between its fetch and its count. A local `<branch>` that already existed can be behind, and the count finds that. Then run `git branch -D <the worktree's old branch>`.
     3. Ask the user to name the session with `/rename <branch>`.
   - **In a worktree on `<base>`, the feature branch from step 1, with no changes and no commits that are not on a remote:** this happens after discuss turned a single issue with work so far into an umbrella, because the issue's own branch became the feature branch. Go on as in the case of a worktree on its own new branch, but skip its `git branch -D`: the feature branch is not a throwaway branch.
   - **Anything else** (changes, commits, another issue's branch, or a `git switch` that fails): stop, show what the worktree holds, and ask.
3. **Implement.** Read the code that the Files section names. Work one scenario at a time, and commit as you go with messages that say what changed and why. Follow the deviation rules. Write each `Term` decision into `docs/glossary.md` as `domain-model` says. The Glossary section at the end of this skill holds the file as it was when the skill loaded, and step 2 can switch or update the branch after that, so read `docs/glossary.md` on the issue branch, if it exists, before you judge that no entry covers a name, and before you write an entry.
4. **Check.** Run the issue's Verify command and the pre-PR checks in `commands.md`. If one fails, go back to step 3.
5. **PR.** Run `git push -u origin <branch>`. If the branch has no open PR yet (`gh api 'repos/{owner}/{repo}/pulls?head={owner}:<branch>&state=open&per_page=100'`), run `gh api -X POST repos/{owner}/{repo}/pulls -f title="<issue title>" -f head=<branch> -f base=<base> -F draft=true -F body=@<path>`. If it has one, as after deviation 5, rewrite its title and body with `gh api -X PATCH repos/{owner}/{repo}/pulls/<pr> -f title="<issue title>" -F body=@<path>`. Write the body to a file as the rules say. Read the PR back with `gh api repos/{owner}/{repo}/pulls/<pr>`, and stop if its base is not `<base>`, it is not a draft, or its title or body is not the one you wrote. The body has:
   - a first line: for a sub-issue, "Sub-issue #<n> of #<parent>. This PR goes into `<base>`, so it has no `Closes` line."; for a single issue, `Closes #<n>`;
   - `## What it delivers`: the changes, file by file;
   - `## Verify`: each command and its result, and what the commands do not prove;
   - `## Deviations`: only if a deviation rule was used, one line for each.
6. **Hand off.** Call the Skill tool with `engineering:verify` and the PR number.
   - **FAIL:** fix what its report names, failed checks included, and go back to step 4. If it fails a second time, stop and ask.
   - **PENDING:** stop. Name each pending check, and tell the user to run `/engineering:execute #<n>` again once CI has finished. That run resumes on this branch and calls verify again. A PENDING verdict does not count as one of the two failures.

## Glossary
!`cat docs/glossary.md 2>/dev/null || printf '\342\200\213'`
