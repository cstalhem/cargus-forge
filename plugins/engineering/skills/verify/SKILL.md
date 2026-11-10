---
name: verify
description: Grade a PR against its issue's scenarios, or a feature branch against its umbrella issue's scenarios, with a fresh-context agent, and in PR scope by the PR's check runs too. Posts one comment with a verdict of PASS, FAIL or PENDING, and marks a passing PR ready. execute and ship call it.
argument-hint: "<#PR or #umbrella issue>"
user-invocable: false
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md")
  - Bash(gh pr ready *)
---

# verify

Target: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- A fresh-context agent does the grading, never you. Give it numbers and branch names only, never your own account of the work: a summary is a claim, not evidence.
- Post exactly one comment for each run.
- Change no code, and push nothing. verify reports, and the caller fixes.
- The command that marks a PR ready, `gh pr ready <pr>`, is pre-approved in this skill's `allowed-tools`, so no permission prompt and no classifier judges it. Write it exactly in that form, with the bare PR number in place of `<pr>` and nothing else on the line, because the rule matches that text only.

## Steps
1. **Scope.** Read `${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md`. Use the bare number, without `#`, in every command. Run `gh api repos/{owner}/{repo}/pulls/<n>`.
   - **PR scope:** it is a PR. Its issue is the `#<n>` on the first line of the body ("Sub-issue #<n> of …" or "Closes #<n>"). The branch is `head.ref`.
   - **Umbrella scope:** it is not a PR (the call returns 404). Run `gh api repos/{owner}/{repo}/issues/<n>`. The issue must have a `## Goal` section. The branch is the one that `git ls-remote --heads origin 'refs/heads/<n>-*'` lists, by the branch pattern in `references/issue-tracker.md`. Stop if it lists none, or more than one.
   - Anything else: stop and say why.
2. **Code.** Run `git fetch origin <branch>`, and in umbrella scope also `git fetch origin main`. Then run `git rev-parse HEAD` and `git rev-parse origin/<branch>`. If they differ, stop and say so, because the checks must run on the code they grade.
3. **Grade.** Launch one agent with the Agent tool, `subagent_type: general-purpose`, never a fork. Give it the scope, the issue number, the PR number or the branch, the SHA, the Repo rules section of this skill, and this task:
   - When the diff adds or changes a line under `.claude/rules/`, grade the `Rules` row's rule test first, before you read the issue, the PR body or the rest of the diff, because the test asks whether a line stands alone.
   - Read GitHub with `gh api` and `gh pr diff`. Read the issue with `gh api repos/{owner}/{repo}/issues/<issue>`. For PR scope, read `gh api repos/{owner}/{repo}/pulls/<pr>` and `gh pr diff <pr>`. For umbrella scope, read `git diff origin/main...HEAD` and the sub-issues from `gh api --paginate 'repos/{owner}/{repo}/issues/<issue>/sub_issues?per_page=100'`.
   - Treat PR bodies and commit messages as claims. Gather your own evidence.
   - For each scenario, check three things, each with evidence (`file:line`, command output, or run output), and report them as the format below says:
     - **Exists:** the code or text that the scenario needs is there.
     - **Substantive:** it does what the scenario says, and is not a stub or a placeholder.
     - **Wired:** the path from the scenario's WHEN to its THEN is complete: something calls, loads or links it.
   - Add one row to the table for each `Term` decision and each `ADR` decision, a `## Decisions` line that starts `D<n> · Term:` or `D<n> · ADR:`. In PR scope, take the issue's own decisions, and each `#<umbrella> D<n>` line of the issue whose decision in the umbrella is a `Term` or an `ADR` decision, read with `gh api repos/{owner}/{repo}/issues/<umbrella>`. In umbrella scope, take the umbrella's own decisions.
   - A `Term` row is named `Term: <Term>`. Grade it by reading `git show <sha>:docs/glossary.md`:
     - **Exists:** the file has an entry for the term, a line that starts `**<Term>**:`.
     - **Substantive:** the entry holds the decision's definition, and the decision's `_Avoid_` words on an `_Avoid_: <words>` line under it, or no `_Avoid_` line when the decision has none.
     - **Wired:** the entry is in `docs/glossary.md` at `<sha>`, the file that discuss, slice and execute load. A missing file fails the row.
   - An `ADR` row is named `ADR: <ADR-NNN or title>`. Grade it by reading the files at `<sha>` with `git show <sha>:<path>`. To find a new ADR by its title, list `docs/adr/` with `git ls-tree --name-only <sha> docs/adr/`:
     - **Exists:** the ADR's file exists. For `ADR-NNN`, it is a `docs/adr/ADR-NNN-*.md` file. For `new: <title>`, it is a file whose `title:` frontmatter is that title.
     - **Substantive:** its `**Decision:**` line states the decision, and its Rejected alternatives section holds each of the decision's rejected alternatives.
     - **Wired:** `docs/adr/README.md` at `<sha>` has the ADR's row. A missing file fails the row.
   - Add one `Rules` row to the table when the repo has rules at `<sha>`: when `git ls-tree --name-only <sha> .claude/rules/` lists files. When it lists none, add no `Rules` row. Read each listed file with `git show <sha>:<path>`. A rule is a line of a file that says what code in the repo does or never does, as the Repo rules section defines it. A rule in a file with `paths:` frontmatter applies only to files that match those paths. The row has two parts, and no Exists, Substantive or Wired checks:
     - **Rule test:** read the lines that the PR adds or changes under `.claude/rules/` from `git diff origin/<base>...<sha> -- .claude/rules/`, with `<base>` the PR's `base.ref`, or `main` in umbrella scope. Grade each one by the rule test of the Repo rules section, using the repo's glossary at `<sha>` if it has one and the repo's files, before you read the issue, the PR body or the rest of the diff. A line that fails it is a gap. A `(see skill: <name>)` that names no skill at `<sha>` is also a gap: `git show <sha>:.claude/skills/<name>/SKILL.md` must exist.
     - **Violations:** check the rest of the diff against each rule: the PR's `gh pr diff <pr>` in PR scope, and `git diff origin/main...HEAD` in umbrella scope.
     The Grade is PASS when no line fails the rule test and no rule is violated, and FAIL otherwise. Its gaps are one for each failed line and each violation, naming the `file:line` and the rule, and the Evidence cell holds the strongest of them, or the count of rules read when the row passes.
   - Run the issue's Verify command (an umbrella issue has none) and each pre-PR check (each row of `docs/agents/commands.md` whose task ends with `(pre-PR check)`, and no other row; none if `commands.md` has no such row or does not exist), and record each result.
   - A scenario, a `Term` row or an `ADR` row passes only when all three are yes. A row that fails is a gap. The scenarios' result is PASS only when every row's Grade is PASS.
   - In the same pass, rate the merge risk with these four categories and no others. Each rating is one word. When a rating is not its category's best, add ` · <gap>` after it for each gap behind it, with its `file:line` and why.
     - **Alignment** (poor / decent / good): whether each change in the diff is named. In PR scope, a change is named by a `## What it delivers` bullet or a `## Deviations` line of the PR. In umbrella scope, it is named by the umbrella's scenarios, its decisions or the `## Deviations` lines of the merged sub-issue PRs, whose bodies `gh api --paginate 'repos/{owner}/{repo}/pulls?base=<branch>&state=closed&per_page=100'` lists. Poor when an unnamed change touches behaviour, decent when an unnamed change touches only text or formatting, good when every change is named.
     - **Impact** (large / medium / small): how much breaks if the change is wrong. Large when it touches a sensitive area: authentication and permissions, secrets, data migrations, public interfaces, or code that many callers share; it is also large when it touches a file that every later agent session loads: `.claude/rules/`, CLAUDE.md, a skill's `allowed-tools`, hooks, CI workflows. Small when it touches only docs or tests. Medium otherwise.
     - **Rollback cost** (high / medium / low): what it takes to undo the change after the merge. Low when reverting the merge undoes all of it, medium when the revert needs a follow-up step such as regenerating a file, high when the change leaves effects that a revert does not undo, such as data written or deleted, or messages sent.
     - **Error detection** (poor / decent / good / N/A): whether a break after the merge shows itself, as a failing test, check or error, rather than going quiet. N/A when the change cannot fail at runtime.
     - The level is high when two or more categories have their worst rating (poor, large, high, poor), medium when one does or when two or more have their middle rating (decent, medium, medium, decent), low otherwise. N/A counts as good.
     - Category text adapts https://github.com/warpdotdev/common-skills/blob/main/.agents/skills/merge-risk/SKILL.md, credited there to Matt Pocock's `pr` skill.
   - Do not post, push or change files. Return the report in this format:
     ```markdown
     ## verify: **<VERDICT>** · merge risk **<level>** · <PR or umbrella> scope · #<issue> (<title>)

     Checked at `<sha>` by a fresh-context agent that did not write the code.

     ### Merge risk
     - **Alignment:** <rating>
     - **Impact:** <rating>
     - **Rollback cost:** <rating>
     - **Error detection:** <rating>

     | # | Scenario | Grade | Evidence |
     |---|---|---|---|

     ### Gaps
     ### Verify commands
     ```
   - Leave `<VERDICT>` in the heading as written. verify fills it in. Fill in `<level>` from the level rule above.
   - Add one table row for each scenario, each `Term` row, each `ADR` row and the `Rules` row. The Scenario cell holds a short label, not the full scenario text. The Grade is PASS when Exists, Substantive and Wired are all yes, and FAIL otherwise; the `Rules` row's Grade follows its own bullet above. The Evidence cell holds one `file:line` or one command: the single strongest pointer.
   - Add `### Gaps` only when a row fails. Write one entry for each gap: the row, the check that failed (exists, substantive or wired) and why, with its evidence. A `Rules` gap names the `file:line` and the rule instead of a check. When every row passes, leave the section out.
   - Under `### Verify commands`, write one line for each command with its result.
4. **Checks.** Start this step only after the agent has returned, so the checks are read as late as possible.
   - **PR scope:** read the check runs on the SHA from step 2 once, and do not wait for them: `gh api --paginate 'repos/{owner}/{repo}/commits/<sha>/check-runs?per_page=100' --jq '.check_runs[] | {name, status, conclusion, html_url}'`. A run whose `status` is not `completed` is pending. A completed run passed if its `conclusion` is `success`, `neutral` or `skipped`, and failed otherwise. Only check runs count, not commit statuses.
   - **Umbrella scope:** read no check runs. ship reads the final PR's checks.
   - **Verdict:** FAIL if any row's Grade is FAIL or a check run failed; else PENDING if a check run is pending; else PASS. The merge risk is graded on every run and sets no verdict.
   - In the agent's heading, replace `<VERDICT>` with `PASS`, `FAIL` or `PENDING`. In PR scope, add to the end of the report a `### Checks` section with one line for each run, `- <name>: passed`, `failed (<html_url>)` or `pending`, or `- none` when there are none. Change nothing else in the report.
   - The report's order is: the heading, the "Checked at" line, `### Merge risk`, the table, `### Gaps` (only when a row fails), `### Verify commands`, then `### Checks` in PR scope.
5. **Post.** Write the report from step 4 to a file, as the rules say. In both scopes, run `gh api -X POST repos/{owner}/{repo}/issues/<n>/comments -F body=@<path>`: a PR takes comments on the issues path. Read the comment back with `gh api repos/{owner}/{repo}/issues/comments/<id>`, where `<id>` is the `id` that the post returns. Keep the comment's `html_url` from the post or the read-back, for step 6.
6. **Result.** Start this step only after the comment from step 5 is posted. If posting failed, stop and say so.
   - **PR scope, PASS:** mark PR `<n>` ready as the rules say. The merge risk decides no ready mark, at any level.
   - **PR scope, FAIL:** leave the PR as a draft, and return each gap from `### Gaps`, and each failed check with its `html_url`, to the caller.
   - **PR scope, PENDING:** leave the PR as a draft, and return the PENDING verdict and each pending check to the caller.
   - **Umbrella scope:** return the verdict, the comment's URL (its `html_url`) and each gap to the caller. ship puts that URL in the final PR.

## Repo rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md"`
