---
name: execute
description: Take one ready issue to a draft PR in the session's own worktree. Switches the worktree to the issue branch, builds until the issue's verify command passes, opens the draft PR, then calls verify.
argument-hint: <#issue>
disable-model-invocation: true
allowed-tools: Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
---

# execute

Issue: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Use the session's worktree. Do not make a second one, and do not move or rename its directory, because that breaks the running session.
- Run plain git commands, one at a time, in the current directory: no `cd … &&` and no `git -C`. Claude Code blocks git commands that it cannot confirm stay inside the worktree.
- Deviations:
  1. A bug in the way of the issue: fix it, and name the fix in the PR.
  2. A missing guard that the issue needs: add it, and name it in the PR.
  3. A broken check or tool that blocks the issue: fix it.
  4. A change to the architecture or to a scenario: stop and ask.
  5. The issue fails the size test: stop. Name the criterion that fails and what you found, and ask for slice. Do not push or open a PR.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md`, `docs/agents/commands.md` and `docs/agents/issue-tracker.md`. Run `gh issue view <n> --json title,body,state,parent,blockedBy`. Stop and say why if the issue is closed, is blocked by an open issue, or has no `## Scenarios` or `## Verify` section.
   - **Base:** for a sub-issue, the branch that `gh issue develop --list <parent>` shows. Stop if the parent has none. For a single issue, the default branch in `issue-tracker.md`, else `main`.
2. **Worktree.** Run `git rev-parse --abbrev-ref HEAD`, `git rev-parse --git-dir`, `git rev-parse --git-common-dir`, `git status --porcelain`, `git rev-list HEAD --not --remotes` and `gh issue develop --list <n>`. The session is in a worktree when the git dir and the common dir differ.
   - **On the issue's branch:** resume. Read `git log --oneline origin/<base>..HEAD` to see what is done.
   - **Not in a worktree:** enter a new one with the EnterWorktree tool, then go on as in the next case.
   - **In a worktree with no changes and no commits that are not on a remote:**
     1. If no branch is linked to the issue, run `gh issue develop <n> --base <base> --name <n>-<slug>`, with the branch pattern from `issue-tracker.md`.
     2. Run `git fetch origin <branch>`, then `git switch <branch>`, then `git branch -D <the worktree's old branch>`.
     3. Ask the user to name the session with `/rename <branch>`.
   - **Anything else** (changes, commits, another issue's branch, or a `git switch` that fails): stop, show what the worktree holds, and ask.
3. **Build.** Read the code that the Files section names. Work one scenario at a time, and commit as you go with messages that say what changed and why. Follow the deviation rules.
4. **Check.** Run the issue's Verify command and the pre-PR checks in `commands.md`. If one fails, go back to step 3.
5. **PR.** Run `git push -u origin <branch>`. If the branch has no PR yet (`gh pr list --head <branch>`), run `gh pr create --draft --base <base> --title "<issue title>" --body-file - <<'PR_BODY'`. The body has:
   - a first line: for a sub-issue, "Sub-issue #<n> of #<parent>. This PR goes into `<base>`, so it has no `Closes` line."; for a single issue, `Closes #<n>`;
   - `## What it delivers`: the changes, file by file;
   - `## Verify`: each command and its result, and what the commands do not prove;
   - `## Deviations`: only if a deviation rule was used, one line for each.
6. **Hand off.** Call the Skill tool with `engineering:verify` and the PR number.
