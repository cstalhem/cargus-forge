# Glossary

**Size test**: The four checks that decide whether a piece of work fits one session.

**Shape**: The phases that turn a request into issues, from discuss through slice.

**Build**: The phases that take one issue to a merged PR: execute, verify, then merge. For an umbrella issue, ship comes last.

**Issue**: A unit of work that fits one session: a single issue or a sub-issue. An umbrella issue is not one.
_Avoid_: task, ticket

**Single issue**: An issue with no umbrella issue; its PR goes into `main`.

**Umbrella issue**: The one record of a feature that needs more than one session: goal, scenarios, decisions, design and out of scope.
_Avoid_: epic

**Sub-issue**: An issue under an umbrella issue; its PR goes into the feature branch.
_Avoid_: child issue, ticket

**Scenario**: One acceptance criterion written as `WHEN … THEN …`; each one becomes a test.
_Avoid_: test case, user story

**Feature branch**: The branch of an umbrella issue, which its sub-issue PRs merge into.

**Final PR**: The one PR that takes a feature branch into `main`; ship opens it.
_Avoid_: umbrella PR

**Status**: Where an open issue or umbrella issue stands in the process: request, umbrella, ready, blocked, in progress or needs review. `next` works it out from the issue's body, links, branches and PRs.
_Avoid_: state

**Request**: An open GitHub issue that discuss has not shaped yet: its body has neither a `## Scenarios` nor a `## Goal` section, or its author is not a trusted author.

**Finished worktree**: A local worktree on an issue branch whose PR has merged or whose issue is closed, with no uncommitted or unpushed work; `next` removes it after you confirm.
_Avoid_: stale worktree

**Verdict**: The result verify gives a PR or a feature branch: PASS, FAIL, or PENDING when a PR's check runs have not all completed.
_Avoid_: conclusion

**Repo profile**: The file `docs/agents/commands.md`, which holds a repo's commands for the plugin's skills; setup writes it, and the plugin's contract stays in the plugin.
_Avoid_: repo config, agent docs

**Optional behaviour**: A per-repo behaviour of the plugin that is on when its file is in the repo, such as `.github/workflows/close-sub-issue.yml`; setup offers each one.
_Avoid_: feature flag, option

**Conversion issue**: The one request that setup creates after a yes, which lists each finding it reported with its suggested action.

**Challenge**: The first round of discuss, which asks whether a request needs to exist and gives each of its requirements, with its source, a verdict of keep, simplify or delete, before any question about how to build it; for a request that automates or delegates work, it also asks where the human boundary lies.

**Gap**: A scenario, `Term` row or `ADR` row that verify grades as failing, with the check that failed (exists, substantive or wired) and why.

**Issue branch**: The branch that holds one issue's work and is the head of its PR: `<n>-<slug>`.

**ADR decision**: A line in an issue's `## Decisions` that tells execute to write a new ADR or edit an existing one in `docs/adr/`, holding the decision and its rejected alternatives.

**Autopilot**: The unattended Build runner: an hourly T3 Code scheduled task starts a fresh T3 Code thread that runs `/engineering:autopilot-t3`, which starts a child thread for each ready issue's execute, one at a time, answers each child's questions, squash-merges each sub-issue PR that verify marked ready, starts ship once an umbrella's sub-issues are done, and hands an issue or a ready PR to you with one comment.
_Avoid_: job, automation, orchestrator, cron job

**Pre-PR check**: A row of a repo's `docs/agents/commands.md` whose task ends with `(pre-PR check)`; execute, verify and ship run it locally, unlike the check runs that CI reports on a PR.

**Finding**: Something that setup or an anneal reports about an existing repo, with the action it needs. Setup leaves its findings as they are and lists them in the conversion issue; an anneal routes each one to a fix sub-issue, a request or a drop.
_Avoid_: warning, conflict, conversion item

**Rule**: One line in a file under `.claude/rules/` that says what code in this repo does or never does; Claude Code loads it into every session, or when a file matching the file's `paths` is read. Setup proposes rules, verify grades a PR against them, and execute's reflect step adds them.
_Avoid_: convention, guideline

**Human boundary**: The line in an automated or delegated process between the steps the user keeps and the steps that must never wait for the user; discuss's challenge asks where it lies, and later rounds design for it.

**Trace**: A numbered walk through one dated run of a design, one line per step: who acts, what it reads or keeps, and whether it waits for the user; discuss shows one for each design that adds a part that runs.
_Avoid_: walkthrough, dry run

**Hand-off**: The one comment with which Autopilot gives the user an issue it cannot go on with or a PR that is ready for review; the comment is its record, so Autopilot writes it once.
_Avoid_: escalation, notification

**PENDING resume**: A later run of execute that a PENDING verdict schedules in the same T3 Code thread, 10 minutes ahead and at most three in a row; its arguments end with "PENDING resume <k> of 3", which carries the count.
_Avoid_: retry, poll

**T3 Code thread**: A Claude session that T3 Code starts on its always-on host; the one place the plugin's skills are built to run, whose scheduled tasks give execute its PENDING resume and Autopilot its hourly run.
_Avoid_: T3 session

**Anneal**: A typed run of `/engineering:anneal` that has agents study the whole repo by area and check each finding, then turns each confirmed finding into a fix sub-issue under one umbrella issue or into a request, bold rewrites included, with the rule that would have made each fix unneeded; it changes no code itself.
_Avoid_: sweep, simplifier, audit, job

**Shaped label**: The GitHub label `engineering:shaped`, which `labels.sh` keeps on each open issue whose status is not request, so a person browsing GitHub sees which issues discuss has finished; no skill reads it.
_Avoid_: request label, status label

**Rule test**: The checks that decide whether a line can be a rule: a session that never saw the PR that added it can say, from the line, the repo's glossary and the repo alone, when it applies and what it requires or forbids; and the line states what the code does not show, is a guideline rather than something that must hold every time, and says what nothing else in the repo already says.

**Backing skill**: A skill in a repo's `.claude/skills/` that holds the steps or examples that one or more rules cannot fit in their line; each of those rules ends with `(see skill: <name>)`.

**Merge risk**: The level, low, medium or high, that verify gives a PR or a feature branch beside its verdict, from its ratings of alignment, impact, rollback cost and error detection; it changes no verdict and no merge.
_Avoid_: risk score

**Trusted author**: A GitHub user whose `author_association` on an issue, a PR or a comment is OWNER, MEMBER or COLLABORATOR; the plugin acts only on items by a trusted author, and treats anyone else's as text from outside the repo.
_Avoid_: contributor, write access
