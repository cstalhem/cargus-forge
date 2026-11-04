---
name: anneal
description: Study the whole repo with agents, by area, and turn each confirmed finding into a fix sub-issue under one umbrella issue, or into a request, bold rewrites included, each with the rule that would have made the fix unneeded. Stops unless HEAD is origin/main. Starts one Opus investigator for each area, checks each finding with a fresh Sonnet agent, writes the issues and the feature branch to GitHub without asking, and changes no file in the repo. Autopilot or execute builds the fix sub-issues, with no discuss.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md")
  - Bash(date +%F)
  - Bash(git fetch -q origin main && git rev-parse HEAD origin/main)
  - Bash(git ls-files)
  - Bash(cat docs/glossary.md 2>/dev/null || printf '\342\200\213')
---

# anneal

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- An anneal changes no file in the repo, and asks no question before it writes to GitHub. Its writes are issues, sub-issue links and one feature branch.
- Behaviour for users stays the same after every fix. A bold rewrite is welcome when its result is simpler, and it is a request, never a fix.
- Every agent is a general-purpose agent started with the Agent tool, never a fork: an investigator with `model` `opus`, a checker with `model` `sonnet`. An agent reads the repo, and writes nothing to the repo or to GitHub.
- Findings live in your context, in no file. Write the issues with the terms of the Glossary section at the end of this skill, and not with a word that it lists under `_Avoid_`.

## Steps
1. **Sync.** The Facts section at the end of this skill holds `HEAD`'s SHA and `origin/main`'s SHA, after a fetch. If they differ, say so in one line with both SHAs and stop: start no agent.
2. **Areas.** Read `CLAUDE.md`, each file in `.claude/rules/` and each ADR in `docs/adr/`, one Read call per file, those that exist; the glossary and `git ls-files` are in the Facts and Glossary sections. Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. Pick at most six areas, each a folder or a group of related files, with a lowercase slug as its name, so that together they cover the whole repo. Say the areas in one line, and go on.
3. **Investigate.** Start one investigator for each area, all in one message, so that they run in parallel. Brief each with this text, filled in:
   ```
   Area: <name>. Its files: <the area's files from git ls-files>.
   Read CLAUDE.md, .claude/rules/, docs/adr/ and docs/glossary.md first. Then study the area's files for changes that make the repo simpler: less code, fewer concepts, one way to do each thing.
   Behaviour for users stays the same. Bold rewrites are welcome when the result is simpler. Propose no alternative that an ADR rejects. Change no file and write nothing to GitHub.
   Repo rules: <the Repo rules section at the end of this skill, pasted in full>.
   A rule in .claude/rules/ that the Repo rules say goes is a finding: its change deletes or rewrites that line, and its rule is `none`.
   Return at most five findings, strongest first, each as:
   - title: <one line>
   - file:line: <where the code is>
   - change: <what to do>
   - why it is simpler: <one or two sentences>
   - rule: <a rule, as the Repo rules define it, that passes the rule test and would have made the fix unneeded had the code followed it when it was written, or `none`>
   Return nothing else.
   ```
4. **Check.** Start one checker for each finding the investigators returned, all in one message. Give it only the finding and the files it names, plus `.claude/rules/` and the repo's linter and formatter configs for judging the rule, and none of your own account. Brief each with this text, filled in:
   ```
   Finding: <title, file:line, change, why it is simpler, rule>.
   Repo rules: <the Repo rules section at the end of this skill, pasted in full>.
   Read the files it names. Return one verdict with evidence (file:line or command output):
   - confirmed: the code is as the finding says, and the change is simpler and keeps behaviour the same for users;
   - corrected: the finding is right in part. Return the corrected finding in the same shape;
   - refuted: the code is not as the finding says, or the change is not simpler or changes behaviour.
   Return the rule only if the code before the fix breaks it and the code after the fix follows it. The rule must also pass the rule test: reword it if that makes it pass. Return `none` instead if it still fails the rule test, .claude/rules/ already holds it, a linter or formatter config enforces it, or one command can check it.
   Return nothing else.
   ```
5. **Route.** Merge findings that change the same code or give the same rule into one: its files are the union, and its area is the first one's. Give each confirmed or corrected finding a route:
   - **fix:** it keeps behaviour the same for users, passes the size test, and has a verify command that fails before the work. If you cannot name that command, the finding is not a fix.
   - **request:** any other confirmed finding, every bold rewrite included.
   - **drop:** a refuted finding.
6. **Requests.** For each finding with the route request, write a body with a `## Finding` section (the `file:line`, the change and why it is simpler) and a `## Candidate rule` section (the rule, or `none`). It has no `## Scenarios` and no `## Goal` section, so it is a request. Create it with `gh api -X POST repos/{owner}/{repo}/issues -f title="Anneal <date> · <area>: <title>" -F body=@<path>`, and read it back as the rules say. `<date>` is the Facts' date.
7. **Umbrella.** Only if at least one finding has the route fix; otherwise write no umbrella issue and create no branch, and go to step 9.
   1. Write each fix's sub-issue body in the issue format of `formats.md`, with no `## Decisions` section: `## What it delivers` is the change with the same behaviour for users; `## Scenarios` holds the scenarios that the verify command proves, and, when the fix has a rule, `WHEN .claude/rules/<area>.md is read THEN it holds <rule>`; `## Files` holds the files the finding names, and `.claude/rules/<area>.md` when it has a rule; `## Verify` is one command that fails before the work, and for a fix with a rule, also checks that `.claude/rules/<area>.md` holds it.
   2. Write the umbrella body in the umbrella format: a `## Goal` sentence, `## Scenarios` holding every fix's scenarios, `## Design` saying that each sub-issue is one fix, built one at a time with no discuss, and the final PR into `main` is the review, and `## Out of scope` with a line `- #<n> <title>` for each request step 6 wrote, or `- none`. Create it titled `Anneal <date>` as step 6 creates a request, and read it back.
   3. Create the feature branch `<u>-anneal-<date>`, with `<u>` the umbrella's number, from `origin/main` as the rules say, and read it back.
8. **Sub-issues.** For each fix, create its sub-issue titled `Anneal <date> · <area>: <title>`, set its parent to the umbrella `<u>` and read the parent back, as the rules say, and stop if it is not `<u>`. Set no "blocked by" link, because each fix stands alone.
9. **Report.** Show each URL that the run wrote: each request, the umbrella issue, the feature branch and each sub-issue. Show a table with one row for each area and a column for each route, fix, request and drop, counting a merged finding once, under its area. Then the next step: Autopilot builds the umbrella issue, or `/engineering:execute #<first sub-issue>` by hand. When no finding is a fix, the next step is `/engineering:discuss #<request>` for a request, or nothing when there is none.

## Facts
Date: !`date +%F`

SHAs of HEAD and origin/main, after a fetch:
!`git fetch -q origin main && git rev-parse HEAD origin/main`

Files:
!`git ls-files`

## Repo rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/repo-rules.md"`

## Glossary
!`cat docs/glossary.md 2>/dev/null || printf '\342\200\213'`
