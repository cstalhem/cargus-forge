---
name: setup
description: Look at a repo and turn what it needs before the plugin works in it into a setup umbrella issue. Shows the facts from setup.sh and each proposed sub-issue on one screen, asks numbered questions, then writes the umbrella, its feature branch and one sub-issue for each accepted proposal to GitHub. In a repo with code it starts an Opus agent that proposes the repo profile's rows and runs each check, in a repo with workflows of its own it starts one that finds a workflow that already closes issues on merge, in a repo with code and no ADR it starts one that finds decisions with a written reason and a rejected alternative, and in a repo with code and no glossary it starts one that proposes the repo's domain terms. It changes no file in the repo, commits and pushes nothing, and opens no PR. A sub-issue writes each file, through execute.
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
- Setup changes no file in the repo. Its writes are the setup umbrella, its feature branch, its sub-issues, their labels and the one request, and only after the user accepts a proposal.
- Setup starts an agent only for an area in step 3 whose condition holds, and reads no web page. A repo with code is a repo whose `### Stack` is not `- none`. Every agent is a general-purpose agent started with the Agent tool, never a fork, with `model` `opus`. It changes no tracked file and writes nothing to GitHub. No second agent checks its proposals, because verify grades each entry in its PR.
- A sub-issue stands alone: set no "blocked by" link.
- Setup changes no repo setting. A finding is a note for the user.
- The branch pattern `<n>-<slug>` and squash merge are fixed in the plugin's `references/issue-tracker.md`. Ask about neither.

## Steps
1. **Check.** If the output of `setup.sh` at the end of this skill is a `setup.sh error:` line instead of the Facts, show that line and stop.
2. **Open umbrella.** If `### Setup umbrella` lists an issue, name each one as `#<n> · <title>`, say that setup writes nothing while one is open, and end.
3. **Analyse.** Start one agent for each area below whose condition holds, all in one message, so that they run in parallel. Start none when no area's condition holds.
   - **Repo profile:** when `### Stack` is not `- none`. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/briefs/profile.md` with the Read tool. Brief the agent with its text in full, then the lines under `### Stack` and the `docs/agents/commands.md` line under `### Files`. Its rows come back in your context, in no file.
   - **Workflows:** when `### Workflows` lists a file, which is a workflow file other than the plugin's. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/briefs/workflows.md` with the Read tool. Brief the agent with its text in full, then the lines under `### Workflows`. The workflows that it returns come back in your context, in no file.
   - **ADRs:** when `### Stack` is not `- none` and `### Docs` lists no line that starts `- adr ·`. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/briefs/adrs.md` with the Read tool. Brief the agent with its text in full, then the lines under `### Stack`. Its `Sourced` and `Unsourced` decisions come back in your context, in no file.
   - **Glossary:** when `### Stack` is not `- none` and `### Docs` lists no line that starts `- glossary ·`. Read `${CLAUDE_PLUGIN_ROOT}/skills/setup/briefs/glossary.md` and `${CLAUDE_PLUGIN_ROOT}/references/domain-model.md` with the Read tool. Brief the agent with the text of both in full, then the lines under `### Stack`. Its terms come back in your context, in no file.
4. **Plan.** Each proposal that the Facts support becomes one sub-issue and one numbered question, written so that "yes" is the recommended answer.
   - **Repo profile:** when the `docs/agents/commands.md` line under `### Files` says `missing`, or the agent returned a row. The sub-issue is "Write the repo profile" when the file is missing and "Add rows to the repo profile" when it is present.
     - A row is a pre-PR check, with ` (pre-PR check)` after its task, only when its kind is `check` and its run is `pass`. Any other row is written without it.
     - Each row whose run is `fail` is a note: `- <command> fails on the current tree (<failure line>), so its row is not a pre-PR check. Fix it, then add "(pre-PR check)" to its task.`
     - A missing file and no row from the agent is the case of a repo that has no commands, with the body below.
   - **Close-sub-issue workflow:** when its line under `### Optional behaviours` says `missing` or `differs`. The sub-issue is "Add the close-sub-issue workflow". It closes a sub-issue when its PR merges into the feature branch, so the issues that it blocks show as unblocked at once.
   - **ADRs:** when `### Docs` lists a line `- adr · \`<folder>/\`` whose folder is not `docs/adr/`, or the agent returned a `Sourced` decision. The sub-issue is "Add the repo's ADRs to docs/adr/". It moves each such folder and writes each sourced decision as a new ADR.
   - **Unsourced decisions:** when the agent returned an `Unsourced` decision. It is a proposal that has one numbered question and no sub-issue: one request with no label that lists each of them, which the umbrella names under `## Out of scope`.
   - **Glossary:** when `### Docs` lists a line `- glossary · \`<file>\`` whose file is not `docs/glossary.md`, or the agent returned a term. The sub-issue is "Add the repo's glossary to docs/glossary.md". It moves the terms of each such file and writes each proposed term as a new entry.
   - **Notes:** each line under `## Findings` other than `- none` and other than a line that says `looks like an ADR folder` or `looks like a glossary`, which the ADR and glossary sub-issues cover, is a note for the user, and so is each failing command above and each workflow that the workflows agent returned: `- <file> already closes issues when a PR merges (<source>). It stays, and the workflow sub-issue still adds the plugin's workflow.` The workflow sub-issue is unchanged by it.
   If there is no proposal and no note, the screen is the line `Everything is up to date. Setup writes nothing.`, and you end. If there is a note or an unsourced-decisions proposal and no sub-issue, the umbrella has no sub-issue and its `## Scenarios` is `- none`. The questions are then the proposal's, and, when there is none, the one question is to write the umbrella with its notes.
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
   - **ADR body:**
     - `## What it delivers` says that `docs/adr/` holds the repo's ADRs in the plugin's format, indexed in `docs/adr/README.md`: the ADRs that each moved folder holds, which are then gone from it, and one new ADR for each sourced decision. Under it, one line `- <title>: <source>` for each sourced decision.
     - `## Scenarios` holds `- WHEN docs/adr/ is read THEN it holds each ADR of <folder>/ in the plugin's format` for each moved folder, and `- WHEN docs/adr/README.md is read THEN it indexes an ADR titled <title>` for each sourced decision.
     - `## Decisions` holds one `ADR` decision with `new: <title>` for each sourced decision, filled in from what the agent returned.
     - `## Files` holds each moved folder, `docs/adr/` and `docs/adr/README.md`.
     - `## Verify` holds `test -f docs/adr/README.md && test ! -e <folder>` for each moved folder, and `grep -qF -- '<title>' docs/adr/README.md` for each sourced decision, all joined with ` && `, the first part left out when the repo has no moved folder.
   - **Glossary body:**
     - `## What it delivers` says that `docs/glossary.md` holds the repo's terms in the plugin's format: the terms that each moved file holds, with that file then gone, and one new entry for each proposed term. When `docs/glossary.md` already exists, a moved term joins it in place and no term appears twice. Under it, one line `- <Term>: used in <file:line>` for each proposed term.
     - `## Scenarios` holds `- WHEN docs/glossary.md is read THEN it holds each term of <file> in the plugin's format` for each moved file, and `- WHEN docs/glossary.md is read THEN it holds an entry for <Term>` for each proposed term.
     - `## Decisions` holds one `Term` decision for each proposed term, filled in from what the agent returned.
     - `## Files` holds each moved file and `docs/glossary.md`.
     - `## Verify` holds `test -s docs/glossary.md && test ! -e <file>` for each moved file, and `grep -qF -- '**<Term>**' docs/glossary.md` for each proposed term, all joined with ` && `, the first part left out when the repo has no moved file.
   - **Request body:** it has neither `## Scenarios` nor `## Goal`. It says in one sentence that each decision below has no written reason or no written rejected alternative, so setup proposed no ADR for it, and that it becomes an ADR once the missing part is written down. Then one line for each unsourced decision: `- <title>: <decision> (shown at <file:line>; missing: <reason | rejected alternative>)`. Its title is `Decisions in <repo> with no written reason or rejected alternative`.
   - **Umbrella body:** its first line is `<!-- engineering:setup umbrella -->`. Then, in the umbrella format:
     - `## Goal`: `<repo> is ready for the plugin once each sub-issue is merged.`
     - `## Scenarios`: the scenarios of each accepted sub-issue.
     - `## Design`: one sentence that says that each sub-issue is one step that the repo needs before the plugin works in it, that each one stands alone, and that the final PR into `main` is the review. Then the line `For you to do:` and one line `- <note>` for each note, or `- none`.
     - `## Out of scope`: `- Changing a repo setting`, and `- Decisions with no written reason or rejected alternative: #<request>` when the request is accepted.
5. **Show.** Your reply is these parts, in this order, and nothing else:
   1. `# Setup for <repo>`.
   2. `## What setup will write`: one line for the umbrella, one for its feature branch, and for each proposal `### <sub-issue title>` with its draft body. Say that setup changes no file in the repo, and that each sub-issue's PR does.
   3. `## For you to do`: each note, as the Facts print it or as step 4 words it, or `- none`.
   4. `## Questions`: the numbered questions. Each one names the sub-issue it writes and what its PR will add, or the request it writes. Then, only when the AskUserQuestion tool is not in your tools, the line `Answer "yes", or "yes, except <numbers>".`
6. **Answer.** Claude Code ends the pre-approvals of this skill's `allowed-tools` when the user sends a message, and an answer in AskUserQuestion's pop-up is not a message. So take the answer in the pop-up when the tool is in your tools, and run steps 7 and 8 in the same turn as the answer.
   - **Pop-up:** if the AskUserQuestion tool is in your tools, call it in the same turn as the screen, right after it, with one question, `Apply the answers to the questions above?`, header `Setup`, and the options `Apply everything recommended`, `Choose item by item` and `Write nothing`. Do not search for the tool: if it is not in your tools, take the typed answer.
     - `Apply everything recommended` accepts every question.
     - `Choose item by item`: call AskUserQuestion again with one question for each numbered question, at most four questions per call, in the order of their numbers, until each has an answer. Each question starts with its number, its header is `Q<number>`, and its options are `Yes` and `No`. The questions answered `Yes` are accepted.
     - `Write nothing` accepts none.
     - Text typed into the pop-up is read as a typed answer.
   - **Typed answer:** otherwise the user's next message answers the questions. "yes" accepts every question. "yes, except <numbers>" accepts every question but those. "no" accepts none.
   If the answer is unclear, ask again. If it accepts no question, reply `Setup wrote nothing.`, and end: write nothing to GitHub.
7. **Write.** In this order, writing each body to a file as the rules say and reading each write back as the rules say:
   1. If the unsourced-decisions proposal is accepted, create the request with its title and body and no label, before the umbrella, because the umbrella's body names its number. Read it back, and stop if its body is not the file you wrote.
   2. Create the umbrella issue titled `Set up <repo> for the plugin`. Read it back, and stop if its body is not the file you wrote. Then add `engineering:shaped`, and after that `engineering:umbrella`, as the rules say.
   3. Create the feature branch `<u>-setup`, with `<u>` the umbrella's number, from `main` as the rules say.
   4. For each accepted sub-issue proposal, create its sub-issue with its title and body. Set its parent to the umbrella and read the parent back, and stop if it is not `<u>`. Then add `engineering:shaped` to it.
8. **Report.** Your reply is the URL of the umbrella issue, of its feature branch, of each sub-issue and of the request, then the next step: Autopilot builds the umbrella issue, or `/engineering:execute #<first sub-issue>` by hand. It ends with the line `Setup changed no file in the repo.`

## Commands template
!`cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md"`

## Template checksum
!`sha256sum "${CLAUDE_PLUGIN_ROOT}/templates/close-sub-issue.yml"`

!`bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"`
