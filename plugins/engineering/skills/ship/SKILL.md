---
name: ship
description: Take an umbrella issue's feature branch to a ready final PR into main. Checks that every sub-issue PR has merged, merges main into the feature branch, runs verify on the umbrella, then opens the final PR with a Closes line for each sub-issue that is still open and for the umbrella.
argument-hint: "<#umbrella issue>"
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
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/formats.md` and `docs/agents/commands.md`. Use the bare number, without `#`, in commands. Run `gh api repos/{owner}/{repo}/issues/<n>` and `gh api repos/{owner}/{repo}/issues/<n>/sub_issues`. Stop if the issue has no `## Goal` section. The feature branch is the one that `git ls-remote --heads origin 'refs/heads/<n>-*'` lists, by the branch pattern in `docs/agents/issue-tracker.md`. Stop if it lists none, or more than one.
2. **Sub-issues.** Run `gh api --paginate 'repos/{owner}/{repo}/pulls?base=<branch>&state=open&per_page=100'` and `gh api --paginate 'repos/{owner}/{repo}/pulls?base=<branch>&state=closed&per_page=100' --jq '.[] | select(.merged_at) | {number, title, body}'`.
   - If a PR into the feature branch is still open, stop and name it.
   - List each open sub-issue that has no merged PR whose first line names it as its issue ("Sub-issue #<n> of" or "for #<n>"). A mention elsewhere in a body does not count. Ask about each one by number whether it needs no PR, for example because it is a repo setting, and say that a yes means the final PR closes it. Go on only when the user has said yes to every listed number; otherwise stop.
3. **Branch.** If the session is not on the feature branch, run `git status --porcelain`. With no changes, run `git fetch origin <branch>` and `git switch <branch>`. Otherwise, or if the switch fails, stop and ask.
4. **Merge main.** Run `git fetch origin main <branch>` and `git merge --ff-only origin/<branch>`. If that fails, or `git rev-list origin/<branch>..HEAD` prints anything, stop and ask, because the local branch holds work that no PR reviewed. Then run `git merge --no-edit origin/main`.
   - On a conflict, stop, list the files, and ask.
   - Run the checks in `commands.md`. If one fails, stop and report it.
   - Run `git push origin <branch>`. verify grades only a pushed head.
5. **Verify.** Call the Skill tool with `engineering:verify` and the umbrella number. Go on only on PASS. If it reports a gap, stop and report each gap, and the user decides whether slice opens a sub-issue for it. If it stops for any other reason, stop and say why.
6. **Final PR.** If `gh api 'repos/{owner}/{repo}/pulls?head={owner}:<branch>&base=main&state=open'` shows no PR, run `gh api -X POST repos/{owner}/{repo}/pulls -f title="<umbrella title>" -f head=<branch> -f base=main -F body=@<path>`, with the final PR body from `formats.md` written to a file as the rules say. Read the PR back with `gh api repos/{owner}/{repo}/pulls/<pr>`, and stop if its base is not `main` or it is a draft. The body has:
   - one paragraph on what the feature does;
   - one `Closes #<n>` line for each sub-issue that is still open, then one for the umbrella. Run `gh api repos/{owner}/{repo}/issues/<n>/sub_issues` again for the current state. Where the close-sub-issue workflow runs, it has closed each sub-issue whose PR merged, so often only the umbrella line is left.
7. **Hand off.** Run `gh pr checks <pr> --watch`. Show the PR URL and the result of its checks, and name any check that fails. The user reviews and merges it.
   - If `gh pr checks` is refused, such as by an HTTP 403 from GraphQL, do not wait for the checks. Read the PR's head SHA with `gh api repos/{owner}/{repo}/pulls/<pr> --jq .head.sha`. Then read its check runs once with `gh api --paginate repos/{owner}/{repo}/commits/<sha>/check-runs --jq '.check_runs[] | {name, status, conclusion}'`.
   - A run whose `status` is not `completed` is pending. A completed run passed if its `conclusion` is `success`, `neutral` or `skipped`, and failed otherwise.
   - Show the PR URL and list the checks that passed, failed and are pending, or say that there are none. Then stop. Say that pending checks were not waited for, and that running ship again reports them anew.
