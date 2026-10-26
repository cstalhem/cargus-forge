---
name: setup
description: Write a repo's profile for the plugin and turn on its optional behaviours. Shows the facts from setup.sh on one screen, asks numbered questions, then writes the accepted files to the working tree and lists them to commit. It commits, pushes, labels and opens nothing.
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
- Setup writes to the working tree only. It does not commit, push, open an issue or a PR, add a label or change a repo setting, and it makes no GitHub write.
- `apply.sh` writes `docs/agents/issue-tracker.md` and each optional behaviour's file. Do not write or edit those files yourself. You write only `docs/agents/commands.md`, with the Write or Edit tool.
- Setup owns the facts in `docs/agents/issue-tracker.md` and never touches its `## Notes`. The repo owns `docs/agents/commands.md` once setup has written it: never rewrite that file, and only add the rows that the user accepts.
- An optional behaviour's file is a byte-identical copy of its template. Never edit one.
- The branch pattern `<n>-<slug>` and squash merge are fixed in the plugin's `references/issue-tracker.md`. Ask about neither.
- On an existing repo, setup reports and changes nothing else. It renames, deletes or creates no branch, and it edits no doc other than the repo profile: not the ADRs, glossaries, CLAUDE.md, AGENTS.md, CONTRIBUTING.md or PR templates under `### Docs`.
- Judge a conflict only against the plugin's contract in the Contract section at the end of this skill. A line conflicts when it says something that the contract does not allow, such as another branch pattern, a merge style other than squash, or another PR target or `Closes` rule. A line that only adds to the contract does not.

## Steps
1. **Check.** If the output of `setup.sh` at the end of this skill is a `setup.sh error:` line instead of the Facts, show that line and stop. Run `git rev-parse --show-prefix`, as its own Bash call. If it prints a path, the session is not at the top of the repo, where `apply.sh` writes: say to start the session there, and stop.
2. **Plan.** Work out the screen from the Facts. Each part that needs a decision becomes one numbered question, written so that "yes" is the recommended answer.
   - **`docs/agents/issue-tracker.md`**, its line under `### Files`:
     - `missing`: create it with the repo and the default branch under `### Repo`. One question.
     - `current`: up to date. No question.
     - `differs`: setup wrote it. Re-render its facts and keep its `## Notes` byte-identical, with the diff from the Facts. One question.
     - `not written by setup`: its first line does not start with `<!-- Written by /engineering:setup.`, and its whole text is in the fence under its line. Check each line of it against the contract, and flag each line that conflicts. One question: adopt it. `apply.sh` writes the repo and the default branch above it and moves its whole text, flagged lines included, under `## Notes`, where setup never touches it again. A note can add to the contract but not change it, so say that the user should edit or remove each flagged line after setup.
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
3. **Show.** Your reply is these parts, in this order, and nothing else:
   1. `## Setup for <repo>`.
   2. `### Files`: one line for each file of the repo profile, `- <path> · <state>`, where the state is `create`, `up to date`, `differs`, `not written by setup`, or `kept` for a `commands.md` that is present. Under a `differs` line, its diff from the Facts, as printed. A `create` line for `issue-tracker.md` names the repo and the default branch. A `not written by setup` line ends with ` · adopt: its text moves under ## Notes`.
   3. `### Commands`: the proposed table with a source for each row, or form 2's sentence when you propose none. For a kept `commands.md`, only the commands that its table lacks, or `- none`.
   4. `### Optional behaviours`: one line for each, `- <name> · <path> · <state>`, where the state is `add`, `up to date` or `differs`. An `add` or `differs` line ends with ` · recommended: <answer>, because <reason>`, and has the diff under a `differs` line.
   5. `### Warnings`: the lines under `## Warnings`, as printed.
   6. `### Conflicts`: one line for each line that step 2 flagged, in `docs/agents/issue-tracker.md` and in the `rules` docs, `- <path> · "<the line, quoted>" · <what the contract says instead>`, or `- none`. Then the line `Setup edits none of these files, other than adopting docs/agents/issue-tracker.md.`
   7. `### Questions`: the numbered questions. Each one names the file it writes and what it writes. Then the line `Answer "yes", or "yes, except <numbers>".`
   If step 2 found no question, replace part 7 with the line `Everything is up to date. Setup writes nothing.`, and end.
4. **Answer.** The user's next message answers the questions. "yes" accepts every question. "yes, except <numbers>" accepts every question but those. "no" accepts none. If the answer changes a proposal, such as a row of the commands table, show the changed proposal and ask again. If the answer is unclear, ask again. If it accepts no question, reply `Setup wrote nothing.`, and end.
5. **Apply.** Write the accepted files in this order:
   1. If the user accepted the `issue-tracker.md` question or an optional behaviour, run `apply.sh` once, as its own Bash call, with no pipe, redirect or chain: `bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/apply.sh"`, then `--issue-tracker --repo <repo> --default-branch <default branch>` if the `issue-tracker.md` question was accepted, with the values under `### Repo` without their backticks, and `--adopt` after `--issue-tracker` only if the file is `not written by setup`, then `--behaviour <name>` for each accepted optional behaviour. It prints each path it wrote. If it fails, it wrote nothing: show its `apply.sh error:` line, write no other file, and stop.
   2. If the user accepted the `commands.md` question, write the file with the Write tool, in the form that step 3 showed, without the template's comments and without the source of each row.
   3. For each accepted command that a kept `commands.md` lacks, add its row at the end of the file's table with the Edit tool. If the file has no table, add form 1's table at the end of the file, with the accepted rows.
6. **Read back.** Run `bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"` again. Each path that `apply.sh` printed must read `current` in its output. Read `docs/agents/commands.md` if step 5 wrote it: it must hold each accepted row. If a check fails, stop and name the file and what differs.
7. **Report.** Your reply is these parts, in this order, and nothing else:
   1. `## Files to commit`, then one line `- <path>` for each file that step 5 wrote or changed.
   2. The line `Setup committed, pushed and labelled nothing. Commit these files on a branch and open a PR.`
   3. Only if a path is under `.github/workflows/`: the line `Pushing a file under .github/workflows/ needs a token with the workflow scope, which a cloud session often lacks.`

## Commands template
!`cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md"`

## Contract
!`cat "${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md"`

!`bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"`
