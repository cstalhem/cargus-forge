---
name: setup
description: Look at a repo and turn what it needs before the plugin works in it into a setup umbrella issue. Shows the facts from setup.sh and each proposed sub-issue on one screen, asks numbered questions, then writes the umbrella, its feature branch and one sub-issue for each accepted proposal to GitHub. In a repo with code it starts an Opus agent that proposes the repo profile's rows and runs each check. It changes no file in the repo, commits and pushes nothing, and opens no PR. A sub-issue writes each file, through execute.
model: fable
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md")
  - Bash(sha256sum "${CLAUDE_PLUGIN_ROOT}/templates/close-sub-issue.yml")
  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh")
  - Bash(gh api -X POST repos/{owner}/{repo}/issues -f title=* -F body=@*)
  - Bash(gh api -X POST repos/{owner}/{repo}/issues/*/sub_issues -F sub_issue_id=*)
  - Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:shaped')
  - Bash(gh api -X POST repos/{owner}/{repo}/issues/* -f 'labels[]=engineering:umbrella')
  - Bash(gh api repos/{owner}/{repo}/issues/*)
  - Bash(gh issue develop *)
---

# setup

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The `## Facts` and `## Findings` sections at the end of this skill are the output of `setup.sh`, which read GitHub and the repo's files when this skill loaded. Do not fetch the facts again, and do not change them.
- Setup changes no file in the repo. Its writes are the setup umbrella, its feature branch, its sub-issues and their labels, and only after the user accepts a proposal.
- Setup starts an agent only in a repo with code, which is a repo whose `### Stack` is not `- none`, and reads no web page. Every agent is a general-purpose agent started with the Agent tool, never a fork, with `model` `opus`. It changes no tracked file and writes nothing to GitHub. No second agent checks its proposals, because verify grades each entry in its PR.
- A sub-issue stands alone: set no "blocked by" link.
- Setup changes no repo setting. A finding is a note for the user.
- The branch pattern `<n>-<slug>` and squash merge are fixed in the plugin's `references/issue-tracker.md`. Ask about neither.

## Steps
1. **Check.** If the output of `setup.sh` at the end of this skill is a `setup.sh error:` line instead of the Facts, show that line and stop.
2. **Open umbrella.** If `### Setup umbrella` lists an issue, name each one as `#<n> · <title>`, say that setup writes nothing while one is open, and end.
3. **Analyse.** Start one agent for each area below whose condition holds, all in one message, so that they run in parallel. Start none when no area's condition holds.
   - **Repo profile:** when `### Stack` is not `- none`. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/briefs/profile.md` with the Read tool. Brief the agent with its text in full, then the lines under `### Stack` and the `docs/agents/commands.md` line under `### Files`. Its rows come back in your context, in no file.
4. **Plan.** Each proposal that the Facts support becomes one sub-issue and one numbered question, written so that "yes" is the recommended answer.
   - **Repo profile:** when the `docs/agents/commands.md` line under `### Files` says `missing`, or the agent returned a row. The sub-issue is "Write the repo profile" when the file is missing and "Add rows to the repo profile" when it is present.
     - A row is a pre-PR check, with ` (pre-PR check)` after its task, only when its kind is `check` and its run is `pass`. Any other row is written without it.
     - Each row whose run is `fail` is a note: `- <command> fails on the current tree (<failure line>), so its row is not a pre-PR check. Fix it, then add "(pre-PR check)" to its task.`
     - A missing file and no row from the agent is the case of a repo that has no commands, with the body below.
   - **Close-sub-issue workflow:** when its line under `### Optional behaviours` says `missing` or `differs`. The sub-issue is "Add the close-sub-issue workflow". It closes a sub-issue when its PR merges into the feature branch, so the issues that it blocks show as unblocked at once.
   - **Notes:** each line under `## Findings` other than `- none` is a note for the user, and so is each failing command above.
   If there is no proposal and no note, the screen is the line `Everything is up to date. Setup writes nothing.`, and you end. If there is a note and no proposal, the one question is to write the umbrella with its notes and no sub-issue, and its `## Scenarios` is `- none`.
   Write each body in the issue format of `formats.md`, which you read in this step with `${CLAUDE_PLUGIN_ROOT}/references/formats.md`:
   - **Repo profile body for rows:**
     - `## What it delivers` says that `docs/agents/commands.md` holds the repo profile with these rows, and holds them in a code block. A missing file gets the whole of form 1 of the Commands template at the end of this skill, with the heading `# Commands`, a blank line and the table. A present file gets only the rows to add, as table lines.
     - `## Scenarios` holds one line for each row: `- WHEN docs/agents/commands.md is read THEN it holds a row for the command <command>`.
     - `## Files` holds `docs/agents/commands.md`.
     - `## Verify` holds `grep -qF -- '<command>' docs/agents/commands.md` for each row, joined with ` && `, and `test -s docs/agents/commands.md && ` in front when the file is missing.
   - **Repo profile body for a repo that has no commands:**
     - `## What it delivers` says that `docs/agents/commands.md` holds the repo profile of a repo that has no commands, and then holds the file in a code block: the heading `# Commands`, a blank line, and the sentence of form 2 of the Commands template at the end of this skill, with no second sentence.
     - `## Scenarios` holds `- WHEN docs/agents/commands.md is read THEN it starts with the heading "# Commands" and holds the sentence "This repo has no build, tests or lint."`.
     - `## Files` holds `docs/agents/commands.md`.
     - `## Verify` holds `grep -q '^This repo has no build, tests or lint\.' docs/agents/commands.md`.
   - **Workflow body:**
     - `## What it delivers` says that `.github/workflows/close-sub-issue.yml` is a byte-identical copy of `templates/close-sub-issue.yml` in the engineering plugin, copied and not edited.
     - `## Scenarios` holds `- WHEN .github/workflows/close-sub-issue.yml is read THEN its SHA-256 checksum is <the checksum under ## Template checksum>`.
     - `## Files` holds `.github/workflows/close-sub-issue.yml`.
     - `## Verify` holds `test "$(sha256sum .github/workflows/close-sub-issue.yml | cut -d ' ' -f 1)" = <the checksum>`.
   - **Umbrella body:** its first line is `<!-- engineering:setup umbrella -->`. Then, in the umbrella format:
     - `## Goal`: `<repo> is ready for the plugin once each sub-issue is merged.`
     - `## Scenarios`: the scenarios of each accepted sub-issue.
     - `## Design`: one sentence that says that each sub-issue is one step that the repo needs before the plugin works in it, that each one stands alone, and that the final PR into `main` is the review. Then the line `For you to do:` and one line `- <note>` for each note, or `- none`.
     - `## Out of scope`: `- Changing a repo setting`.
5. **Show.** Your reply is these parts, in this order, and nothing else:
   1. `# Setup for <repo>`.
   2. `## What setup will write`: one line for the umbrella, one for its feature branch, and for each proposal `### <sub-issue title>` with its draft body. Say that setup changes no file in the repo, and that each sub-issue's PR does.
   3. `## For you to do`: each note, as the Facts print it or as step 4 words it, or `- none`.
   4. `## Questions`: the numbered questions. Each one names the sub-issue it writes and what its PR will add. Then, only when the AskUserQuestion tool is not in your tools, the line `Answer "yes", or "yes, except <numbers>".`
6. **Answer.** Claude Code ends the pre-approvals of this skill's `allowed-tools` when the user sends a message, and an answer in AskUserQuestion's pop-up is not a message. So take the answer in the pop-up when the tool is in your tools, and run steps 7 and 8 in the same turn as the answer.
   - **Pop-up:** if the AskUserQuestion tool is in your tools, call it in the same turn as the screen, right after it, with one question, `Apply the answers to the questions above?`, header `Setup`, and the options `Apply everything recommended`, `Choose item by item` and `Write nothing`. Do not search for the tool: if it is not in your tools, take the typed answer.
     - `Apply everything recommended` accepts every question.
     - `Choose item by item`: call AskUserQuestion again with one question for each numbered question, at most four questions per call, in the order of their numbers, until each has an answer. Each question starts with its number, its header is `Q<number>`, and its options are `Yes` and `No`. The questions answered `Yes` are accepted.
     - `Write nothing` accepts none.
     - Text typed into the pop-up is read as a typed answer.
   - **Typed answer:** otherwise the user's next message answers the questions. "yes" accepts every question. "yes, except <numbers>" accepts every question but those. "no" accepts none.
   If the answer is unclear, ask again. If it accepts no question, reply `Setup wrote nothing.`, and end: write nothing to GitHub.
7. **Write.** In this order, writing each body to a file as the rules say and reading each write back as the rules say:
   1. Create the umbrella issue titled `Set up <repo> for the plugin`. Read it back, and stop if its body is not the file you wrote. Then add `engineering:shaped`, and after that `engineering:umbrella`, as the rules say.
   2. Create the feature branch `<u>-setup`, with `<u>` the umbrella's number, from `main` as the rules say.
   3. For each accepted proposal, create its sub-issue with its title and body. Set its parent to the umbrella and read the parent back, and stop if it is not `<u>`. Then add `engineering:shaped` to it.
8. **Report.** Your reply is the URL of the umbrella issue, of its feature branch and of each sub-issue, then the next step: Autopilot builds the umbrella issue, or `/engineering:execute #<first sub-issue>` by hand. It ends with the line `Setup changed no file in the repo.`

## Commands template
!`cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md"`

## Template checksum
!`sha256sum "${CLAUDE_PLUGIN_ROOT}/templates/close-sub-issue.yml"`

!`bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"`
