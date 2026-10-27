---
name: slice
description: Split an umbrella issue into sub-issues that each pass the size test, with parent links and "blocked by" links, and create the umbrella's feature branch from main, or from the work so far on the current branch. Also re-splits a sub-issue that fails the size test. discuss calls it after it writes an umbrella issue, and execute calls it on a sub-issue that is too big.
argument-hint: "<#umbrella issue | #sub-issue findings>"
user-invocable: false
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(cat docs/glossary.md 2>/dev/null || printf '\342\200\213')
---

# slice

Issue: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Write nothing to GitHub until the user answers "yes" to the plan.
- Every umbrella scenario belongs to at least one sub-issue. In a re-split, every umbrella scenario that the old sub-issue owned is still owned. If a scenario fits no sub-issue, stop before you write anything, name the scenario, and send it back to discuss.
- If two parts of the umbrella conflict, for example a Design that breaks a decision, stop before you write anything. Name both parts, say why they conflict, and send it back to discuss. Do not settle it in a sub-issue.
- Every sub-issue passes the size test. Split a sub-issue that fails, and test each part again.
- Every `Term` decision of the umbrella is pointed to as `#<umbrella> D<n>` by at least one sub-issue: the one whose work writes or names that term. In a re-split, the pointer moves with that work.
- Write sub-issue titles and scenarios with the terms of the Glossary section at the end of this skill, and not with a word that it lists under `_Avoid_`.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. Use the bare number, without `#`, in commands. Run `gh api repos/{owner}/{repo}/issues/<n>`, and the same path with `/parent`, `/sub_issues?per_page=100`, `/dependencies/blocked_by?per_page=100` and `/dependencies/blocking?per_page=100` added, reading those lists page by page as the rules say.
   - **Umbrella mode:** the issue has a `## Goal` section. If it already has sub-issues, read them. The scenarios they own count as owned. Read the code that the Design section names. If it has no sub-issues yet, find its work so far, which it has when discuss turned a single issue into it. Run `git fetch origin main` and `git ls-remote --heads origin 'refs/heads/<n>-*'`. Stop if it lists more than one branch.
     - **It lists a branch:** that is the issue's own branch, and it becomes the feature branch. Run `git fetch origin <branch>` and `git log --oneline origin/main..origin/<branch>`.
     - **It lists none:** the work so far is on the current branch, as in a cloud session. Run `git rev-parse --abbrev-ref HEAD`, and stop and ask if it prints `HEAD`, because `HEAD` is then detached. Then run `git log --oneline origin/main..HEAD`. These commits may be the issue's work or unrelated, so the plan shows them and the user decides.
   - **Re-split mode:** the issue has a `parent` and no `## Goal` section. Read the umbrella with `gh api repos/{owner}/{repo}/issues/<parent>` and its `/sub_issues?per_page=100`, page by page as the rules say. The rest of the arguments are execute's findings: the criterion that fails and why. Read the old sub-issue's blockers from its `dependencies/blocked_by` links only, and the issues that it blocked from its `dependencies/blocking` links only. Read the work so far on the current branch. execute calls slice in the same session, so the current branch is the issue branch: `<n>-<slug>` locally, and the designated branch in a cloud session. The feature branch is the one branch that `git ls-remote --heads origin 'refs/heads/<parent>-*'` lists. Stop if it lists none, or more than one. Run `git rev-parse --abbrev-ref HEAD`, and stop and ask if it prints `HEAD`, because `HEAD` is then detached. Then run `git fetch origin <feature branch>`, `git log --oneline origin/<feature branch>..HEAD` and `git diff origin/<feature branch>...HEAD`.
   - Anything else: stop and say why.
2. **Plan.** Each body uses the issue format in `formats.md` exactly, including its Decisions rules.
   - **Umbrella mode:** split the umbrella into sub-issues with one behaviour each. Show each sub-issue (its title, its draft body and the four size-test verdicts), a table of each umbrella scenario and the sub-issues that own it, and which sub-issue blocks which. If step 1 found commits, list them and say the feature branch starts from them. The user can drop them, and the feature branch then starts from `main`. To drop the commits of the issue's own branch, the user deletes that branch first, because slice creates no branch when one exists.
   - **Re-split mode:** the sub-issue keeps the part that is built or closest to built. Rewrite its Scenarios, Files and Verify for that part, and do not keep its old body, because GitHub's edit history keeps it. Each other part becomes a new sub-issue of the same umbrella. Show:
     - the narrowed sub-issue and each new part: its title, its draft body and the four size-test verdicts;
     - a table of the umbrella scenarios that the old sub-issue owned, and the issues that own them after the split;
     - the links: each new part is blocked by the narrowed sub-issue and by every issue that blocked it, and each issue that the old sub-issue blocked becomes blocked by every part;
     - any commits on the current branch that belong to a part that moves out, so the user can decide whether they stay.

   Wait for "yes". If the user changes something, update the plan and show it again.
3. **Branch.** Umbrella mode only. Run `git ls-remote --heads origin 'refs/heads/<n>-*'`. If it lists a branch, that is the feature branch. If it lists none, create `<n>-<slug>` as the rules say, with `main` as `<base>`. If the user kept the commits on the current branch, start it from the current branch's head instead, with the current branch as `<base>` and `HEAD` as `<sha>`. `gh issue develop` starts from the remote branch, so first run `git fetch origin <current branch>`, `git rev-parse HEAD` and `git rev-parse origin/<current branch>`. Stop and ask if the fetch fails or the two differ, because the branch would then not hold the commits the plan listed.
4. **Write.** Create the sub-issues in dependency order, so that each "blocked by" number exists. Write each body to a file as the rules say, then create each with `gh api -X POST repos/{owner}/{repo}/issues -f title="<title>" -F body=@<path>`. Set its parent with `gh api -X POST repos/{owner}/{repo}/issues/<umbrella>/sub_issues -F sub_issue_id=<id>`, where `<id>` is the `id` field of the new issue, not its number. Read the parent back with `gh api repos/{owner}/{repo}/issues/<s>/parent --jq .number`, with the new issue's number as `<s>`, and stop if it is not the umbrella. For each blocker `#<a>`, read its `id` with `gh api repos/{owner}/{repo}/issues/<a> --jq .id` and set the link with `gh api -X POST repos/{owner}/{repo}/issues/<s>/dependencies/blocked_by -F issue_id=<id>`. The `id` is not the number. Read the links back with `gh api 'repos/{owner}/{repo}/issues/<s>/dependencies/blocked_by?per_page=100' --jq 'length, (.[] | .number)'`, and stop if `#<a>` is not among them. The body does not list the parent or the blockers, as in `formats.md`.
   - **Re-split mode:** first rewrite the narrowed sub-issue with `gh api -X PATCH repos/{owner}/{repo}/issues/<n> -f title="<title>" -F body=@<path>`. Its "blocked by" links stay as they are. Then create the new parts as above. Each new part gets the narrowed sub-issue's parent as its parent, with the same `sub_issues` call and read-back, and a "blocked by" link for each of its blockers, with the same read-back. Then, for each issue `<x>` that the old sub-issue blocked, as step 1 found them, set a "blocked by" link from `<x>` to each new part the same way, with the same read-back.
5. **Hand off.** Show the branch (umbrella mode), then each sub-issue URL with the issues that block it. The next step is execute on a sub-issue that nothing blocks. After a re-split, that is `/engineering:execute #<n>` on the narrowed sub-issue.

## Glossary
!`cat docs/glossary.md 2>/dev/null || printf '\342\200\213'`
