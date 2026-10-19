---
name: slice
description: Split an umbrella issue into sub-issues that each pass the size test, with parent and "blocked by" links, and create the umbrella's feature branch from main. discuss calls it after it writes an umbrella issue.
argument-hint: <#umbrella issue>
user-invocable: false
---

# slice

Umbrella issue: $ARGUMENTS

## Rules
- Write nothing to GitHub until the user answers "yes" to the plan.
- Every umbrella scenario belongs to at least one sub-issue. If a scenario fits no sub-issue, stop before you write anything, name the scenario, and send it back to discuss.
- If two parts of the umbrella conflict, for example a Design that breaks a decision, stop before you write anything. Name both parts, say why they conflict, and send it back to discuss. Do not settle it in a sub-issue.
- Every sub-issue passes the size test. Split a sub-issue that fails, and test each part again.
- Read only this plugin's files, the current repo's files, and GitHub data about the current repo, such as issues or branch protection, through `gh` calls that change nothing. Read `docs/adr/` and `docs/agents/` only if they exist.
- Add no labels.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. Run `gh issue view <n> --json title,body,subIssues`. If the issue has no `## Goal` section, it is not an umbrella issue: stop and say so. If it already has sub-issues, read them. The scenarios they own count as owned. Read the code that the Design section names.
2. **Plan.** Split the umbrella into sub-issues with one behaviour each. Each body uses the issue format in `formats.md` exactly, including its Decisions rules. Show:
   - each sub-issue: its title, its draft body, and the four size-test verdicts;
   - a table of each umbrella scenario and the sub-issues that own it;
   - which sub-issue blocks which.

   Wait for "yes". If the user changes something, update the plan and show it again.
3. **Branch.** Run `gh issue develop --list <n>`. If no branch is linked, run `gh issue develop <n> --base main --name <n>-<slug>`.
4. **Write.** Create the sub-issues in dependency order, so that each "blocked by" number exists. Use one command for each, with the body on stdin through a quoted heredoc and no temp file: `gh issue create --title "<title>" --parent <n> --blocked-by <a>,<b> --body-file - <<'ISSUE_BODY'`. Leave out `--blocked-by` when nothing blocks the sub-issue.
5. **Hand off.** Show the branch, then each sub-issue URL with the issues that block it. The next step is execute on a sub-issue that nothing blocks.
