---
name: setup
description: Write a repo's profile for the plugin, propose rules for `.claude/rules/`, and turn on its optional behaviours. Shows the facts from setup.sh on one screen, asks numbered questions, then writes the accepted files to the working tree and lists them to commit. It commits, pushes and labels nothing, and opens no PR. Its one GitHub write, after a yes, is one issue that lists what to convert.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh")
  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/apply.sh" *)
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/templates/commands.md")
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/issue-tracker.md")
  - Bash(git rev-parse --show-prefix)
  - Edit(docs/agents/commands.md)
  - Edit(.claude/rules/*)
  - 'Bash(gh api -X POST repos/{owner}/{repo}/issues -f title="engineering: convert this repo to the plugin''s process" -F body=@*)'
  - Bash(gh api repos/{owner}/{repo}/issues/*)
---

# setup

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The research agents of step 2's Rules part are the one exception to the first rule above: they read the web, with WebSearch and WebFetch. Setup reads the web nowhere else.
- The `## Facts` and `## Findings` sections at the end of this skill are the output of `setup.sh`, which read GitHub and the repo's files when this skill loaded. Do not fetch the facts again, other than the read-back in step 6, and do not change them.
- Setup writes files to the working tree only. It does not commit, push, open a PR, add a label, create a branch or change a repo setting. Its one GitHub write is the conversion issue of step 7, and only after the user accepts its question.
- `apply.sh` writes each optional behaviour's file. Do not write or edit those files yourself. You write only `docs/agents/commands.md` and the files under `.claude/rules/`, with the Write or Edit tool.
- The repo owns `docs/agents/commands.md` once setup has written it: never rewrite that file, and only add the rows that the user accepts.
- The repo owns `.claude/rules/` once it holds a file: setup writes no rule into it and asks nothing about rules.
- An optional behaviour's file is a byte-identical copy of its template. Never edit one.
- The branch pattern `<n>-<slug>` and squash merge are fixed in the plugin's `references/issue-tracker.md`. Ask about neither.
- On an existing repo, setup reports and changes nothing else. It renames, deletes or creates no branch, and it edits no doc other than the repo profile, and creates no file other than the rules files under `.claude/rules/`: not the ADRs, glossaries, CLAUDE.md, AGENTS.md, CONTRIBUTING.md or PR templates under `### Docs`.
- Judge a line of a `rules` doc only against the plugin's contract in the Contract section at the end of this skill. The line is a finding when it says something that the contract does not allow, such as another branch pattern, a merge style other than squash, or another PR target or `Closes` rule. A line that only adds to the contract is not.

## Steps
1. **Check.** If the output of `setup.sh` at the end of this skill is a `setup.sh error:` line instead of the Facts, show that line and stop. Run `git rev-parse --show-prefix`, as its own Bash call. If it prints a path, the session is not at the top of the repo, where `apply.sh` writes: say to start the session there, and stop.
2. **Plan.** Work out the screen from the Facts. Each part that needs a decision becomes one numbered question, written so that "yes" is the recommended answer.
   - **Branches**, the lines under `### Branches`: their findings say what to do. No question.
   - **Docs**, the lines under `### Docs`:
     - `adr` and `glossary`: their findings say that the plugin cannot see them. No question.
     - `rules`: read the file with the Read tool. Flag each line that conflicts with the contract: it is a finding. No question.
   - **`docs/agents/commands.md`**, its line under `### Files`:
     - Propose the commands: from `### Commands`, and from the README.md, CONTRIBUTING.md and CLAUDE.md of the repo if they name a command that the Facts lack. Read each of the three files with the Read tool, one call per file, and run no Bash command to read them. A file that does not exist names no command. Take the commands that a developer runs to build, test, lint, format or type-check the code. One row for each task, with the command that runs locally rather than a CI step that wraps it. Leave out install, deploy and release steps, and shell lines that only set up CI. A task that should pass before every PR ends with `(pre-PR check)`. Give each row its source.
     - `missing`: create it from the Commands template at the end of this skill. Use form 1 with the proposed rows, or form 2 when you propose none. One question for the whole file.
     - `present`: keep it. Read it, and find each proposed command that its table lacks. Each one is its own question, which adds that row to the table.
   - **Rules**, the `.claude/rules/` line under `### Files`:
     - `present (<n> files)`: the repo owns it. Show reports `### .claude/rules/ · kept`, and proposes no rule. No question, and launch no research agent.
     - `missing`: build the candidate rules. Read the files that the `rules` lines under `### Docs` name, with the Read tool, one call per file, to learn which conventions the repo already states. Read the tool configs listed as `config:` under `### Stack`, and the repo's other docs and layout, for conventions that no rule doc states.
       - **Research.** Launch one research agent for each stack component, in parallel, in one message, with the Agent tool, `subagent_type: general-purpose`, never a fork. A component is a `language:` or `framework|tool:` line under `### Stack`; `config:` lines are not components. Launch at most four: when there are more, take the first four lines in the order of `### Stack`, which lists languages first, by file count. Brief each agent with this text, filled in:
         ```
         Component: <name from the Stack line>.
         The repo's own convention lines, which are already covered: <each convention line that the rule docs state, or "none">.
         Use WebSearch and WebFetch to read the component's official docs and widely used guides. Find conventions for using it that Claude would plausibly get wrong in this repo without a rule. Return a finding only if you can name its source URL. Do not return a well-known language feature, a generic best practice, or a pattern that this repo does not use: check the repo's files for that. Do not return a line that the repo's own convention lines already state.
         Return at most ten lines, each `- <rule> · <url>`, where the rule is one line that says what code does or never does, with no code and no rationale, and the url is the one page that shows it. Return nothing else. If your fetches fail, return the single line `no network`.
         ```
       - Add what you know of the components that no agent covered, or whose agent returned `no network`, where Claude would plausibly get a convention of this repo wrong without a rule.
       - Each candidate is one line that says what code in the repo does or never does: no code, no rationale. Its source is `repo: <path>` when a repo file shows it, `docs: <url>` when a research agent's finding gave it, and `proposed` when it comes from what you know of the stack.
       - When every agent returned `no network`, every candidate that is not from the repo has the source `proposed`, and the `### Rules` part says so.
       - Drop a candidate that restates a line of the repo's CLAUDE.md, AGENTS.md or CONTRIBUTING.md, or a convention that a linter or formatter config in the repo enforces.
       - A candidate that one command can check is not a rule: add it to the `commands.md` proposal above as a `(pre-PR check)` row.
       - Group the rest into areas. An area is a folder when `### Stack` or the repo layout maps it to one, such as `src/api/**`, and its file gets those `paths`. A cross-cutting area gets no `paths`. The file is `.claude/rules/<area>.md`, with the area written as a lowercase slug.
       - One question for the whole set of files. If no candidate is left, ask none.
   - **Optional behaviours**, each line under `### Optional behaviours`:
     - `missing`: one question to add it, with its recommendation.
     - `current`: up to date. No question.
     - `differs`: one question to replace it with the template, with the diff from the Facts.
     - close-sub-issue: recommend yes. It closes a sub-issue when its PR merges into the feature branch, so the issues that it blocks show as unblocked at once. Without it, a merged sub-issue stays open until the final PR closes it.
   - **Conversion issue, already open:** if `### Conversion issue` lists at least one issue, setup has made one before. Ask no conversion question and offer no new issue. Name each listed issue on the screen. When it lists more than one, say that setup offers none until the user closes the extra ones.
   - **Conversion issue:** only if `### Conversion issue` says `- none`. Its items are the findings: each line under the Facts' `## Findings` other than `- none` (a repo setting, an open issue with `<n>-*` branches, another branch convention, an ADR folder or a glossary that the plugin cannot see), and each line that you flagged in the `rules` docs. If there is at least one, ask one more question, the last one: create one GitHub issue titled `engineering: convert this repo to the plugin's process`, with no label, that lists each finding with its suggested action. Its body starts with the line `<!-- engineering:setup conversion issue -->`, which a later setup run finds it by, and has neither a `## Scenarios` nor a `## Goal` section, so it is a request, which `/engineering:discuss` shapes later. If there is none, ask no such question.
     - The suggested action of a finding from `setup.sh` is the one that its last sentence states. For a flagged line, it is to edit or remove it so that it agrees with the contract.
3. **Show.** Your reply is these parts, in this order, and nothing else:
   1. `# Setup for <repo>`.
   2. `## What setup will write`, holding:
      1. `### docs/agents/commands.md · <state>`, where the state is `create`, or `kept` for a `commands.md` that is present. Under it, the proposed table with a source for each row, or form 2's sentence when you propose none. For a kept `commands.md`, only the commands that its table lacks, or `- none`.
      2. `### .claude/rules/ · <state>`, where the state is `create`, `kept` for a folder that is present, or `none to propose` when no candidate is left. Under it, only when the state is `create`: for each area, `#### <area> · paths: <globs>`, or `#### <area> · no paths`, then one line `- <rule> · <source>` for each of its rules, where the source is `repo: <path>`, `docs: <url>` or `proposed`. When every research agent returned `no network`, the part starts with the line `No network: every research agent returned \`no network\`, so each rule that is not from the repo is \`proposed\`.`
      3. `### Optional behaviours`: one line for each, `- <name> · <path> · <state>`, where the state is `add`, `up to date` or `differs`. An `add` or `differs` line ends with ` · recommended: <answer>, because <reason>`, and has the diff under a `differs` line. Print no file for an `add`: its name, path and recommendation are enough, because the file is a byte-identical copy of the plugin's template.
   3. `## What setup found but will not change`, opening with the line `Setup leaves these as they are.`, followed on the same line by ` Fix them yourself, or let setup file one issue that lists them (question <N>).` only when you ask the conversion question, where `<N>` is its number. Then:
      1. `### Findings`: the lines under the Facts' `## Findings`, as printed, then one line for each line that step 2 flagged in the `rules` docs, `- <path> · "<the line, quoted>" · <what the contract says instead> · edit or remove it so that it agrees with the contract`. `- none` when there is neither.
      2. `### Conversion issue`, only when the Facts list one: `- #<n> · <title>` for each, as the Facts print it.
   4. `## Questions`: the numbered questions. Each one names the file it writes and what it writes, and the rules question names each `.claude/rules/<area>.md` file with its number of rules, and the conversion question names the issue's title, says that it has no label, and gives the number of findings it lists. Then, only when the AskUserQuestion tool is not in your tools, the line `Answer "yes", or "yes, except <numbers>".`
   If step 2 found no question, the body of `## Questions` is the line `Everything is up to date. Setup writes nothing.`, and you end.
4. **Answer.** Claude Code ends the pre-approvals of this skill's `allowed-tools` when the user sends a message, and an answer in AskUserQuestion's pop-up is not a message. So take the answer in the pop-up when the tool is in your tools, and run steps 5 to 8 in the same turn as the answer.
   - **Pop-up:** if the AskUserQuestion tool is in your tools, call it in the same turn as the screen, right after it, with one question, `Apply the answers to the questions above?`, header `Setup`, and the options `Apply everything recommended`, `Choose item by item` and `Write nothing`. Do not search for the tool: if it is not in your tools, take the typed answer.
     - `Apply everything recommended` accepts every question.
     - `Choose item by item`: call AskUserQuestion again with one question for each numbered question, at most four questions per call, in the order of their numbers, until each has an answer. Each question starts with its number, its header is `Q<number>`, and its options are `Yes` and `No`. The questions answered `Yes` are accepted.
     - `Write nothing` accepts none.
     - Text typed into the pop-up is read as a typed answer.
   - **Typed answer:** otherwise the user's next message answers the questions. "yes" accepts every question. "yes, except <numbers>" accepts every question but those. "no" accepts none.
   If the answer changes a proposal, such as a row of the commands table, show the changed proposal and ask again, in the same way. If the answer is unclear, ask again. If it accepts no question, reply `Setup wrote nothing.`, and end: write no file and create no issue.
5. **Apply.** Write the accepted files in this order:
   1. If the user accepted an optional behaviour, run `apply.sh` once, as its own Bash call, with no pipe, redirect or chain: `bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/apply.sh"`, then `--behaviour <name>` for each accepted optional behaviour. Send it alone, with no other tool call in the same message, and wait for its result before the next call. It prints each path it wrote. If it fails or is refused, it wrote nothing: show its `apply.sh error:` line, or say that it was refused, write no other file, create no issue, and stop.
   2. If the user accepted the `commands.md` question, write the file with the Write tool, in the form that step 3 showed, without the template's comments and without the source of each row.
   3. If the user accepted the rules question, write each `.claude/rules/<area>.md` with the Write tool, in the form that step 3 showed, without the sources. A file with `paths` starts with the frontmatter `---`, `paths:`, one line `  - "<glob>"` for each glob, and `---`. Then comes the heading `# <Area>`, and then one line `- <rule>` for each rule: no code, no rationale and no source tag. A cross-cutting area has no frontmatter.
   4. For each accepted command that a kept `commands.md` lacks, add its row at the end of the file's table with the Edit tool. If the file has no table, add form 1's table at the end of the file, with the accepted rows.
6. **Read back.** If step 5 wrote no file, skip this step. Run `bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/setup.sh"` again. Each path that `apply.sh` printed must read `current` in its output. Read `docs/agents/commands.md` if step 5 wrote it: it must hold each accepted row. If step 5 wrote rules files, the `.claude/rules/` line of the output must read `present (<n> files)` with the number of files that step 5 wrote, and each file must hold each accepted rule. If a check fails, stop and name the file and what differs.
7. **Conversion issue.** Only if the user accepted the conversion question:
   1. Write the body with the Write tool to a new file, as the rules say. Its first line is `<!-- engineering:setup conversion issue -->`, then comes the line `/engineering:setup reported these findings, which differ from the plugin's process. Setup changed none of them.`, then `## Findings`, then one line for each finding from step 2: `- <what setup found> · suggested action: <action>`. Name each branch, path and quoted line as the screen did.
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
