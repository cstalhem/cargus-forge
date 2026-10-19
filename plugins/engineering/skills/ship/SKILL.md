---
name: ship
description: Take an umbrella issue's feature branch to a ready final PR into main. Checks that every sub-issue PR has merged, merges main into the feature branch, runs verify on the umbrella, then opens the final PR with a Closes line for each sub-issue and the umbrella.
argument-hint: <#umbrella issue>
disable-model-invocation: true
allowed-tools: Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
---

# ship

Umbrella issue: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Merge `main` into the feature branch. Never rebase it, because sub-issue branches and worktrees are based on it.
- Run plain git commands, one at a time, in the current directory: no `cd … &&` and no `git -C`.
- Do not merge the final PR. The user merges it.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/formats.md` and `docs/agents/commands.md`. Use the bare number, without `#`, in commands. Run `gh issue view <n> --json title,body,subIssues`. Stop if the issue has no `## Goal` section. The feature branch is the one that `gh issue develop --list <n>` shows. Stop if it shows none, or more than one.
2. **Sub-issues.** Run `gh pr list --base <branch> --state open` and `gh pr list --base <branch> --state merged --limit 200 --json number,title,body`.
   - If a PR into the feature branch is still open, stop and name it.
   - If an open sub-issue has no merged PR whose first line names it as its issue ("Sub-issue #<n> of" or "for #<n>"), stop and name the sub-issue. A mention elsewhere in a body does not count.
3. **Branch.** If the session is not on the feature branch, run `git status --porcelain`. With no changes, run `git fetch origin <branch>` and `git switch <branch>`. Otherwise, or if the switch fails, stop and ask.
4. **Merge main.** Run `git fetch origin main <branch>` and `git merge --ff-only origin/<branch>`. If that fails, or `git rev-list origin/<branch>..HEAD` prints anything, stop and ask, because the local branch holds work that no PR reviewed. Then run `git merge --no-edit origin/main`.
   - On a conflict, stop, list the files, and ask.
   - Run the checks in `commands.md`. If one fails, stop and report it.
   - Run `git push origin <branch>`. verify grades only a pushed head.
5. **Verify.** Call the Skill tool with `engineering:verify` and the umbrella number. Go on only on PASS. If it reports a gap, stop and report each gap, and the user decides whether slice opens a sub-issue for it. If it stops for any other reason, stop and say why.
6. **Final PR.** If `gh pr list --head <branch> --base main` shows no PR, run `gh pr create --base main --head <branch> --title "<umbrella title>" --body-file - <<'PR_BODY'`, with the final PR body from `formats.md`:
   - one paragraph on what the feature does;
   - one `Closes #<n>` line for each open sub-issue, then one for the umbrella.
7. **Hand off.** Run `gh pr checks <pr> --watch`. Show the PR URL and the result of its checks, and name any check that fails. The user reviews and merges it.
