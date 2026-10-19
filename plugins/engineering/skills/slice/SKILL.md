---
name: slice
description: Split an umbrella issue into sub-issues that each pass the size test, with parent and "blocked by" links, and create the umbrella's feature branch from main. Also re-splits a sub-issue that fails the size test. discuss calls it after it writes an umbrella issue, and execute calls it on a sub-issue that is too big.
argument-hint: <#umbrella issue | #sub-issue findings>
user-invocable: false
allowed-tools: Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
---

# slice

Issue: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Write nothing to GitHub until the user answers "yes" to the plan.
- Every umbrella scenario belongs to at least one sub-issue. In a re-split, every umbrella scenario that the old sub-issue owned is still owned. If a scenario fits no sub-issue, stop before you write anything, name the scenario, and send it back to discuss.
- If two parts of the umbrella conflict, for example a Design that breaks a decision, stop before you write anything. Name both parts, say why they conflict, and send it back to discuss. Do not settle it in a sub-issue.
- Every sub-issue passes the size test. Split a sub-issue that fails, and test each part again.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. Use the bare number, without `#`, in commands. Run `gh issue view <n> --json title,body,parent,subIssues,blockedBy,blocking`.
   - **Umbrella mode:** the issue has a `## Goal` section. If it already has sub-issues, read them. The scenarios they own count as owned. Read the code that the Design section names.
   - **Re-split mode:** the issue has a `parent` and no `## Goal` section. Read the umbrella with `gh issue view <parent> --json title,body,subIssues`. The rest of the arguments are execute's findings: the criterion that fails and why. Read the work so far: the branch from `gh issue develop --list <n>`, and its `git log` and `git diff` against the feature branch from `gh issue develop --list <parent>`.
   - Anything else: stop and say why.
2. **Plan.** Each body uses the issue format in `formats.md` exactly, including its Decisions rules.
   - **Umbrella mode:** split the umbrella into sub-issues with one behaviour each. Show each sub-issue (its title, its draft body and the four size-test verdicts), a table of each umbrella scenario and the sub-issues that own it, and which sub-issue blocks which.
   - **Re-split mode:** the sub-issue keeps the part that is built or closest to built. Rewrite its Scenarios, Files and Verify for that part, and do not keep its old body, because GitHub's edit history keeps it. Each other part becomes a new sub-issue of the same umbrella. Show:
     - the narrowed sub-issue and each new part: its title, its draft body and the four size-test verdicts;
     - a table of the umbrella scenarios that the old sub-issue owned, and the issues that own them after the split;
     - the links: each new part is blocked by the narrowed sub-issue and by every issue that blocked it, and each issue that the old sub-issue blocked becomes blocked by every part;
     - any commits on the branch that belong to a part that moves out, so the user can decide whether they stay.

   Wait for "yes". If the user changes something, update the plan and show it again.
3. **Branch.** Umbrella mode only. Run `gh issue develop --list <n>`. If no branch is linked, run `gh issue develop <n> --base main --name <n>-<slug>`.
4. **Write.** Create the sub-issues in dependency order, so that each "blocked by" number exists. Use one command for each, with the body on stdin through a quoted heredoc and no temp file: `gh issue create --title "<title>" --parent <umbrella> --blocked-by <a>,<b> --body-file - <<'ISSUE_BODY'`. Leave out `--blocked-by` when nothing blocks the sub-issue.
   - **Re-split mode:** first rewrite the narrowed sub-issue with `gh issue edit <n> --title "<title>" --body-file - <<'ISSUE_BODY'`, then create the new parts. Then, for each issue `<x>` that the old sub-issue blocked, run `gh issue edit <x> --add-blocked-by <a>,<b>` with the new parts. If `gh` does not know that flag, add each link with `gh api -X POST repos/{owner}/{repo}/issues/<x>/dependencies/blocked_by -F issue_id=<id>`, where `<id>` comes from `gh api repos/{owner}/{repo}/issues/<a> --jq .id`.
5. **Hand off.** Show the branch (umbrella mode), then each sub-issue URL with the issues that block it. The next step is execute on a sub-issue that nothing blocks. After a re-split, that is `/engineering:execute #<n>` on the narrowed sub-issue.
