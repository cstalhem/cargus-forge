---
name: setup
description: Write a repo's profile for the plugin and turn on its optional behaviours. Shows the facts from setup.sh on one screen, asks numbered questions, then writes the accepted files to the working tree and lists them to commit. It commits, pushes and labels nothing, and opens no PR. Its one GitHub write, after a yes, is one issue that lists what to convert.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh")
  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/apply.sh" *)
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md")
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md")
  - Bash(git rev-parse --show-prefix)
---

# setup

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The `## Facts` and `## Warnings` sections at the end of this skill are the output of `setup.sh`, which read GitHub and the repo's files when this skill loaded. Do not fetch the facts again, other than the read-back in step 6, and do not change them.
- Setup writes files to the working tree only. It does not commit, push, open a PR, add a label, create a branch or change a repo setting. Its one GitHub write is the conversion issue of step 7, and only after the user accepts its question.
- `apply.sh` writes each optional behaviour's file. Do not write or edit those files yourself. You write only `docs/agents/commands.md`, with the Write or Edit tool.
- The repo owns `docs/agents/commands.md` once setup has written it: never rewrite that file, and only add the rows that the user accepts.
- An optional behaviour's file is a byte-identical copy of its template. Never edit one.
- The branch pattern `<n>-<slug>` and squash merge are fixed in the plugin's `references/issue-tracker.md`. Ask about neither.
- On an existing repo, setup reports and changes nothing else. It renames, deletes or creates no branch, and it edits no doc other than the repo profile: not the ADRs, glossaries, CLAUDE.md, AGENTS.md, CONTRIBUTING.md or PR templates under `### Docs`.
- Judge a conflict only against the plugin's contract in the Contract section at the end of this skill. A line conflicts when it says something that the contract does not allow, such as another branch pattern, a merge style other than squash, or another PR target or `Closes` rule. A line that only adds to the contract does not.

## Steps
1. **Check.** If the output of `setup.sh` at the end of this skill is a `setup.sh error:` line instead of the Facts, show that line and stop. Run `git rev-parse --show-prefix`, as its own Bash call. If it prints a path, the session is not at the top of the repo, where `apply.sh` writes: say to start the session there, and stop.
2. **Plan.** Work out the screen from the Facts. Each part that needs a decision becomes one numbered question, written so that "yes" is the recommended answer.
   - **Branches**, the lines under `### Branches`: their warnings say what to do. No question, because setup changes no branch.
   - **Docs**, the lines under `### Docs`:
     - `adr` and `glossary`: their warnings say that the plugin cannot see them. No question.
     - `rules`: read the file with the Read tool. Flag each line that conflicts with the contract. No question, because setup edits none of these files.
   - **`docs/agents/commands.md`**, its line under `### Files`:
     - Propose the commands: from `### Commands`, and from the README.md, CONTRIBUTING.md and CLAUDE.md of the repo if they name a command that the Facts lack. Take the commands that a developer runs to build, test, lint, format or type-check the code. One row for each task, with the command that runs locally rather than a CI step that wraps it. Leave out install, deploy and release steps, and shell lines that only set up CI. A task that should pass before every PR ends with `(pre-PR check)`. Give each row its source.
     - `missing`: create it from the Commands template at the end of this skill. Use form 1 with the proposed rows, or form 2 when you propose none. One question for the whole file.
     - `present`: keep it. Read it, and find each proposed command that its table lacks. Each one is its own question, which adds that row to the table.
   - **Optional behaviours**, each line under `### Optional behaviours`:
     - `missing`: one question to add it, with its recommendation.
     - `current`: up to date. No question.
     - `differs`: one question to replace it with the template, with the diff from the Facts.
     - close-sub-issue: recommend yes. It closes a sub-issue when its PR merges into the feature branch, so the issues that it blocks show as unblocked at once. Without it, a merged sub-issue stays open until the final PR closes it.
   - **Conversion issue:** the conversion items are what the repo holds that differs from the plugin's process: the warnings that the lines under `### Branches` gave (an open issue with `<n>-*` branches, another branch convention), the warnings of the `adr` and `glossary` lines under `### Docs`, and each line that you flagged in the `rules` docs. If there is at least one, ask one more question, the last one: create one GitHub issue titled `engineering: convert this repo to the plugin's process`, with no label, that lists each item with its suggested action. Its body has neither a `## Scenarios` nor a `## Goal` section, so it is a request, which `/engineering:discuss` shapes later. If there is none, ask no such question.
     - The suggested action of a branch warning is the one that the warning states. For an ADR folder, move its ADRs into `docs/adr/`. For a glossary, move its terms into `docs/glossary.md`. For a flagged line, edit or remove it so that it agrees with the contract.
3. **Show.** Your reply is these parts, in this order, and nothing else:
   1. `## Setup for <repo>`.
   2. `### Files`: one line for the repo profile, `- docs/agents/commands.md · <state>`, where the state is `create`, or `kept` for a `commands.md` that is present.
   3. `### Commands`: the proposed table with a source for each row, or form 2's sentence when you propose none. For a kept `commands.md`, only the commands that its table lacks, or `- none`.
   4. `### Optional behaviours`: one line for each, `- <name> · <path> · <state>`, where the state is `add`, `up to date` or `differs`. An `add` or `differs` line ends with ` · recommended: <answer>, because <reason>`, and has the diff under a `differs` line.
   5. `### Warnings`: the lines under `## Warnings`, as printed.
   6. `### Conflicts`: one line for each line that step 2 flagged in the `rules` docs, `- <path> · "<the line, quoted>" · <what the contract says instead>`, or `- none`. Then the line `Setup edits none of these files.`
   7. `### Questions`: the numbered questions. Each one names the file it writes and what it writes, and the conversion question names the issue's title, says that it has no label, and gives the number of items it lists. Then the line `Answer "yes", or "yes, except <numbers>".`
   If step 2 found no question, replace part 7 with the line `Everything is up to date. Setup writes nothing.`, and end.
4. **Answer.** The user's next message answers the questions. "yes" accepts every question. "yes, except <numbers>" accepts every question but those. "no" accepts none. If the answer changes a proposal, such as a row of the commands table, show the changed proposal and ask again. If the answer is unclear, ask again. If it accepts no question, reply `Setup wrote nothing.`, and end.
5. **Apply.** Write the accepted files in this order:
   1. If the user accepted an optional behaviour, run `apply.sh` once, as its own Bash call, with no pipe, redirect or chain: `bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/apply.sh"`, then `--behaviour <name>` for each accepted optional behaviour. It prints each path it wrote. If it fails, it wrote nothing: show its `apply.sh error:` line, write no other file, and stop.
   2. If the user accepted the `commands.md` question, write the file with the Write tool, in the form that step 3 showed, without the template's comments and without the source of each row.
   3. For each accepted command that a kept `commands.md` lacks, add its row at the end of the file's table with the Edit tool. If the file has no table, add form 1's table at the end of the file, with the accepted rows.
6. **Read back.** If step 5 wrote no file, skip this step. Run `bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"` again. Each path that `apply.sh` printed must read `current` in its output. Read `docs/agents/commands.md` if step 5 wrote it: it must hold each accepted row. If a check fails, stop and name the file and what differs.
7. **Conversion issue.** Only if the user accepted the conversion question:
   1. Write the body with the Write tool to a new file, as the rules say. It starts with the line `/engineering:setup found these items, which differ from the plugin's process. Setup changed none of them.`, then `## Items`, then one line for each conversion item from step 2: `- <what setup found> · suggested action: <action>`. Name each branch, path and quoted line as the screen did.
   2. Run `gh api -X POST repos/{owner}/{repo}/issues -f title="engineering: convert this repo to the plugin's process" -F body=@<path>`, as its own Bash call. Pass no `labels` field.
   3. Read it back with `gh api repos/{owner}/{repo}/issues/<n>`, with the number that the POST returned. Check that its title is the one above, that its body is the file you wrote, and that it has no labels.
   If the POST fails, or the read-back differs, do not create another issue and do not change this one. Name what failed in step 8.
8. **Report.** Your reply is these parts, in this order, and nothing else:
   1. Only if step 5 wrote or changed a file: `## Files to commit`, then one line `- <path>` for each file that it wrote or changed.
   2. Only if step 7 ran: `## Conversion issue`, then `- #<n> · <its html_url> · no label`, or the line that names what failed.
   3. The line `Setup committed, pushed and labelled nothing.`, and only if step 5 wrote or changed a file, ` Commit these files on a branch and open a PR.` after it on the same line.
   4. Only if a path is under `.github/workflows/`: the line `Pushing a file under .github/workflows/ needs a token with the workflow scope, which a cloud session often lacks.`

## Commands template
!`cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md"`

## Contract
!`cat "${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md"`

!`bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"`
