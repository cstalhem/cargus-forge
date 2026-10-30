---
name: verify
description: Grade a PR against its issue's scenarios, or a feature branch against its umbrella issue's scenarios, with a fresh-context agent, and in PR scope by the PR's check runs too. Posts one comment with a verdict of PASS, FAIL or PENDING, and marks a passing PR ready. execute and ship call it.
argument-hint: "<#PR or #umbrella issue>"
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
1. **Scope.** Read `${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md`. Use the bare number, without `#`, in every command. Run `gh api repos/{owner}/{repo}/pulls/<n>`.
   - **PR scope:** it is a PR. Its issue is the `#<n>` on the first line of the body ("Sub-issue #<n> of …" or "Closes #<n>"). The branch is `head.ref`.
   - **Umbrella scope:** it is not a PR (the call returns 404). Run `gh api repos/{owner}/{repo}/issues/<n>`. The issue must have a `## Goal` section. The branch is the one that `git ls-remote --heads origin 'refs/heads/<n>-*'` lists, by the branch pattern in `references/issue-tracker.md`. Stop if it lists none, or more than one.
   - Anything else: stop and say why.
2. **Code.** Run `git fetch origin <branch>`, and in umbrella scope also `git fetch origin main`. Then run `git rev-parse HEAD` and `git rev-parse origin/<branch>`. If they differ, stop and say so, because the checks must run on the code they grade.
3. **Grade.** Launch one agent with the Agent tool, `subagent_type: general-purpose`, never a fork. Give it the scope, the issue number, the PR number or the branch, the SHA, and this task:
   - Read GitHub only with `gh api` REST and `gh pr diff`. Read the issue with `gh api repos/{owner}/{repo}/issues/<issue>`. For PR scope, read `gh api repos/{owner}/{repo}/pulls/<pr>` and `gh pr diff <pr>`. For umbrella scope, read `git diff origin/main...HEAD` and the sub-issues from `gh api 'repos/{owner}/{repo}/issues/<issue>/sub_issues?per_page=100'`. While a page holds 100 items, read the next one with `&page=2`, then `&page=3`, and so on. Do not let `gh api` follow GitHub's next-page link, which the cloud proxy refuses.
   - Treat PR bodies and commit messages as claims. Gather your own evidence.
   - For each scenario, check three things, each with evidence (`file:line`, command output, or run output), and report them as the format below says:
     - **Exists:** the code or text that the scenario needs is there.
     - **Substantive:** it does what the scenario says, and is not a stub or a placeholder.
     - **Wired:** the path from the scenario's WHEN to its THEN is complete: something calls, loads or links it.
   - Add one row to the table for each `Term` decision, a `## Decisions` line that starts `D<n> · Term:`. In PR scope, take the issue's own, and each `#<umbrella> D<n>` line of the issue whose decision in the umbrella is a `Term` decision. Read that text with `gh api repos/{owner}/{repo}/issues/<umbrella>`. In umbrella scope, take the umbrella's own. Name the row `Term: <Term>`, and grade it by reading `git show <sha>:docs/glossary.md`:
     - **Exists:** the file has an entry for the term, a line that starts `**<Term>**:`.
     - **Substantive:** the entry holds the decision's definition, and the decision's `_Avoid_` words on an `_Avoid_: <words>` line under it, or no `_Avoid_` line when the decision has none.
     - **Wired:** the entry is in `docs/glossary.md` at `<sha>`, the file that discuss, slice and execute load. A missing file fails the row.
   - Add one row to the table for each `ADR` decision, a `## Decisions` line that starts `D<n> · ADR:`. In PR scope, take the issue's own, and each `#<umbrella> D<n>` line of the issue whose decision in the umbrella is an `ADR` decision. Read that text with `gh api repos/{owner}/{repo}/issues/<umbrella>`. In umbrella scope, take the umbrella's own. Name the row `ADR: <ADR-NNN or title>`, and grade it by reading the files at `<sha>` with `git show <sha>:<path>`. To find a new ADR by its title, list `docs/adr/` with `git ls-tree --name-only <sha> docs/adr/`:
     - **Exists:** the ADR's file exists. For `ADR-NNN`, it is a `docs/adr/ADR-NNN-*.md` file. For `new: <title>`, it is a file whose `title:` frontmatter is that title.
     - **Substantive:** its `**Decision:**` line states the decision, and its Rejected alternatives section holds each of the decision's rejected alternatives.
     - **Wired:** `docs/adr/README.md` at `<sha>` has the ADR's row. A missing file fails the row.
   - Run the issue's Verify command (an umbrella issue has none) and the checks in `docs/agents/commands.md`, and record each result.
   - In a Claude Code cloud session, a body written through REST ends with a `---` line and a `_Generated by …_` footer. That footer is not part of the Verify command or of any other section, so do not run it.
   - A scenario, a `Term` row or an `ADR` row passes only when all three are yes. A row that fails is a gap. The scenarios' result is PASS only when every row's Grade is PASS.
   - Do not post, push or change files. Return the report in this format:
     ```markdown
     ## verify: **<VERDICT>** · <PR or umbrella> scope · #<issue> (<title>)

     Checked at `<sha>` by a fresh-context agent that did not write the code.

     | # | Scenario | Grade | Evidence |
     |---|---|---|---|

     ### Gaps
     ### Verify commands
     ```
   - Leave `<VERDICT>` in the heading as written. verify fills it in.
   - Add one table row for each scenario, each `Term` row and each `ADR` row. The Scenario cell holds a short label, not the full scenario text. The Grade is PASS when Exists, Substantive and Wired are all yes, and FAIL otherwise. The Evidence cell holds one `file:line` or one command: the single strongest pointer.
   - Add `### Gaps` only when a row fails. Write one entry for each gap: the row, the check that failed (exists, substantive or wired) and why, with its evidence. When every row passes, leave the section out.
   - Under `### Verify commands`, write one line for each command with its result.
4. **Checks.** Start this step only after the agent has returned, so the checks are read as late as possible.
   - **PR scope:** read the check runs on the SHA from step 2 once, and do not wait for them: `gh api 'repos/{owner}/{repo}/commits/<sha>/check-runs?per_page=100' --jq '(.check_runs | length), (.check_runs[] | {name, status, conclusion, html_url})'`, page by page as the rules say. A run whose `status` is not `completed` is pending. A completed run passed if its `conclusion` is `success`, `neutral` or `skipped`, and failed otherwise. Only check runs count, not commit statuses.
   - **Umbrella scope:** read no check runs. ship reads the final PR's checks.
   - **Verdict:** FAIL if any row's Grade is FAIL or a check run failed; else PENDING if a check run is pending; else PASS.
   - In the agent's heading, replace `<VERDICT>` with `PASS`, `FAIL` or `PENDING`. In PR scope, add to the end of the report a `### Checks` section with one line for each run, `- <name>: passed`, `failed (<html_url>)` or `pending`, or `- none` when there are none. Change nothing else in the report.
   - The report's order is: the heading, the "Checked at" line, the table, `### Gaps` (only when a row fails), `### Verify commands`, then `### Checks` in PR scope.
5. **Post.** Write the report from step 4 to a file, as the rules say. In both scopes, run `gh api -X POST repos/{owner}/{repo}/issues/<n>/comments -F body=@<path>`: a PR takes comments on the issues path. Read the comment back with `gh api repos/{owner}/{repo}/issues/comments/<id>`, where `<id>` is the `id` that the post returns. Keep the comment's `html_url` from the post or the read-back, for step 6.
6. **Result.** Start this step only after the comment from step 5 is posted. If posting failed, stop and say so.
   - **PR scope, PASS:** mark PR `<n>` ready as the rules say.
   - **PR scope, FAIL:** leave the PR as a draft, and return each gap from `### Gaps`, and each failed check with its `html_url`, to the caller.
   - **PR scope, PENDING:** leave the PR as a draft, and return the PENDING verdict and each pending check to the caller.
   - **Umbrella scope:** return the verdict, the comment's URL (its `html_url`) and each gap to the caller. ship puts that URL in the final PR.
