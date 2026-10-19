---
name: verify
description: Grade a PR against its issue's scenarios, or a feature branch against its umbrella issue's scenarios, with a fresh-context agent. Posts one comment with a verdict, and marks a passing PR ready. execute and ship call it.
argument-hint: <#PR or #umbrella issue>
user-invocable: false
allowed-tools: Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
---

# verify

Target: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- A fresh-context agent does the grading, never you. Give it numbers and branch names only, never your own account of the work: a summary is a claim, not evidence.
- Post exactly one comment for each run.
- Change no code, and push nothing. verify reports, and the caller fixes.

## Steps
1. **Scope.** Use the bare number, without `#`, in every command. Run `gh pr view <n> --json number,title,body,headRefName`.
   - **PR scope:** it is a PR. Its issue is the `#<n>` on the first line of the body ("Sub-issue #<n> of …" or "Closes #<n>"). The branch is `headRefName`.
   - **Umbrella scope:** it is not a PR. Run `gh issue view <n> --json title,body`. The issue must have a `## Goal` section, and the branch is the one that `gh issue develop --list <n>` shows.
   - Anything else: stop and say why.
2. **Code.** Run `git fetch origin <branch>`, and in umbrella scope also `git fetch origin main`. Then run `git rev-parse HEAD` and `git rev-parse origin/<branch>`. If they differ, stop and say so, because the checks must run on the code they grade.
3. **Grade.** Launch one agent with the Agent tool, `subagent_type: general-purpose`, never a fork. Give it the scope, the issue number, the PR number or the branch, the SHA, and this task:
   - Read the issue with `gh issue view`. For PR scope, read `gh pr view` and `gh pr diff`. For umbrella scope, read `git diff origin/main...HEAD` and the sub-issues.
   - Treat PR bodies and commit messages as claims. Gather your own evidence.
   - For each scenario, record three things with evidence (`file:line`, command output, or run output):
     - **Exists:** the code or text that the scenario needs is there.
     - **Substantive:** it does what the scenario says, and is not a stub or a placeholder.
     - **Wired:** the path from the scenario's WHEN to its THEN is complete: something calls, loads or links it.
   - Run the issue's Verify command (an umbrella issue has none) and the checks in `docs/agents/commands.md`, and record each result.
   - A scenario passes only when all three are yes. The verdict is PASS only when every scenario passes.
   - Do not post, push or change files. Return the report in this format:
     ```markdown
     ## verify, <PR or umbrella> scope: #<issue> (<title>)

     Checked at `<sha>` by a fresh-context agent that did not write the code.

     | # | Scenario | Exists | Substantive | Wired | Grade |
     |---|---|---|---|---|---|

     ### Evidence
     ### Verify commands
     ### Observations (non-blocking)
     ### Verdict: **PASS** or **FAIL**
     ```
4. **Post.** Post the agent's report as it is, through a quoted heredoc and no temp file. PR scope: `gh pr comment <n> --body-file - <<'REPORT'`. Umbrella scope: `gh issue comment <n> --body-file - <<'REPORT'`.
5. **Result.**
   - **PR scope, PASS:** run `gh pr ready <n>`.
   - **PR scope, FAIL:** leave the PR as a draft, and return each failing scenario with its evidence to the caller.
   - **Umbrella scope:** return the verdict and each gap to the caller.
