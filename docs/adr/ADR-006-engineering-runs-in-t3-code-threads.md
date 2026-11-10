---
adr: 006
title: Engineering runs in T3 Code threads on one host
status: active
---

# ADR-006: Engineering runs in T3 Code threads on one host

- **Decision:** Every engineering skill runs in a T3 Code thread on one always-on host. Skills reach GitHub through `gh`, by the simplest command for each operation, create branches with `git push`, and find branches by their names in git.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md), [ADR-002](ADR-002-feature-branch-per-umbrella.md)
- **Records:** #78 D1, D4, D5, D7 and D9 to D16. D2, D3 and D6 are replaced, and so is D10's linked branch (see Rejected alternatives). Also #144 D1, #181 D3 and D5, #185 D1 and D2, #233 D4, #265 D2, #292 D2 and #368 D2, D4 to D7, D16 and D17.

## Details
- **One surface:** a T3 Code thread, started on an always-on host that the phone and the laptop both reach. A plain `claude` session still runs each skill. Only execute's PENDING resume and Autopilot stop there, when the `schedule_task` tool or a T3 tool cannot be loaded.
- **Each operation has one command** (#368 D5): whichever of a `gh api` REST call, a GraphQL call or a `gh issue` or `gh pr` command is simplest, and no skill gives one operation two commands.
- **Reads** go through `gh api` REST: `issues/<n>`, `/parent`, `/sub_issues`, `/dependencies/blocked_by`, `pulls/<n>` and `pulls?base=<base>` (D1).
- **Lists** are read with `gh api --paginate` (#368 D7). Each list path passes `per_page=100`, to read fewer pages, and a `--jq` filter runs once for each page. `read_list` in `scripts/lib.sh` makes one `--paginate --slurp` call and joins the pages with `jq add`.
- **Writes** go through `gh api` REST, and a write that works stays as it is (D9, #368 D5). Each body is written to a file first and passed as `-F body=@<path>`. No skill calls a GitHub MCP tool, `gh issue create`, `gh issue edit`, `gh issue comment`, `gh pr create` or `gh pr comment`.
  - discuss creates an issue with `POST issues` and rewrites it with `PATCH issues/<n>`. execute and ship open a PR with `POST pulls`, execute with `draft: true`. execute rewrites the title and body of a PR that is already open with `PATCH pulls/<pr>`. verify posts with `POST issues/<n>/comments`.
  - Every write is read back through REST. If a required fact is missing (a sub-issue's parent, a blocked-by link, a PR's base and draft state, a posted comment, a created branch), the skill stops and names the gap.
- **Marking a PR ready exists only in GraphQL**, so a skill runs `gh pr ready <pr>` and reads the PR back through REST, with no fallback (#368 D6). verify's `allowed-tools` pre-approves the command.
- **Branches** are created with `git push origin <sha>:refs/heads/<n>-<slug>`, after `git fetch origin <base>` only when `<sha>` is `origin/<base>` (#181 D5, #212 D2). No branch is linked to its issue, because no REST route links one.
- **The feature branch** is found by its name in git (D4). execute, verify and ship take the one remote branch from `git ls-remote --heads origin` that matches the plugin's fixed `<n>-<slug>` pattern (`references/issue-tracker.md`) for the umbrella's number. They stop if none or more than one match.
- **The issue branch** is the issue's `<n>-<slug>` branch, in the session's worktree (#185 D1). execute needs a checkout with no changes and no commits that are not on a remote, and otherwise stops and asks. If `git ls-remote` lists no issue branch, execute creates it from the base with `git push`. If it lists one, execute fetches it. Either way, execute switches to it with `git switch`. On resume, it syncs and reads `git log --oneline origin/<base>..HEAD`. The `<n>-<slug>` name keeps the branch findable by name for `next`, slice and a later execute run.
- **Blockers** are GitHub "blocked by" links (D11). slice sets each parent link with `POST issues/<umbrella>/sub_issues` and each blocked-by link with `POST issues/<n>/dependencies/blocked_by`, both with the other issue's `id`, and reads each one back. A sub-issue's body does not list its parent or its blockers, so slice writes no text that could disagree with a link (#181 D3). execute reads blockers from the links only.
- **The work so far** is found on the current branch (D12). execute's size-test stop hands off to slice or discuss in the same session, so the current branch is the issue branch, `<n>-<slug>`. A re-split reads the work from there.
- **The draft PR** is opened in one place, execute's step 3, after each push when the branch has no open PR, with a placeholder body (#292 D2). The PR step only rewrites the PR with `PATCH pulls/<pr>` and reads it back.
- **The size-test stop** leaves a draft PR for a sub-issue (D16). The push opens it through step 3 with the placeholder body, and the failing criterion reaches slice only as its arguments. A later run on the narrowed sub-issue then takes the existing resume path from the issue branch. A single issue keeps no PR, because its branch becomes the feature branch, so execute closes the one that the push opened.
- **A single issue that becomes an umbrella** keeps its work so far as the start of the feature branch (D13). If the issue's own `<n>-<slug>` branch exists, slice makes it the feature branch. If not, slice creates the feature branch from the current branch's head, not `main`. Its plan lists those commits, so you can drop them. slice treats a detached `HEAD` with no commits beyond `main` as no work so far, and creates the feature branch from `main`. It stops and asks if a detached `HEAD` holds commits (#185).
- **Checks:** ship runs `gh pr checks <pr> --watch` and shows the result (D7).
  - verify reads the PR's check runs through `commits/<sha>/check-runs` once in PR scope, after its grading agent returns, and does not wait either (#144 D1). A failed run fails the verdict, and a pending run gives a PENDING verdict that keeps the PR a draft.
  - **A PENDING verdict in a T3 Code thread** makes execute schedule its own resume, in 10 minutes, at most three times (#233 D4, #265 D2). It loads the `schedule_task` tool and uses a task with a `once` schedule and `bindToCurrentThread` true, and execute stops when the tool cannot be loaded or the host has no `once` schedule (T3 Code v0.1.7, or a nightly from 2026-11-01 on). The thread is idle between checks. The scheduled message runs execute again on the same branch, with a `PENDING resume <k> of 3` suffix that carries the count, and that run calls verify again. After the third resume, or when the task cannot be scheduled, execute stops and you run it again once CI has finished. An unattended Build ([ADR-008](ADR-008-autopilot-builds-ready-issues-unattended.md)) needs the resume, because no one is there to run execute again. A spent `once` task stays in T3's scheduled tasks list until T3 deletes it with its thread, and execute deletes none.

## Rejected alternatives
- **Claude Code cloud sessions, as the main surface or as an option** (#368 D17): their proxy refuses GraphQL and `git/refs` writes, which forces a REST-only rule and a workaround for each refusal.
- **Write with `gh` first and fall back to the GitHub MCP tools after the first refusal, with each body in the tool's text parameter** (#78 D2 and D3, replaced by D9): the REST writes that the skills need work. A second write path doubles what each skill must handle, and the MCP tools can neither link a branch nor set a blocked-by link.
- **Blockers only as first-line text, with a link-blocked-by workflow that turns the text into links, and execute reading the union of links and text** (#78 D6, replaced by D11): `POST issues/<n>/dependencies/blocked_by` works, so slice sets the links itself. A workflow is extra setup in each repo, and two sources can disagree.
- **After a size-test stop, resume from commits tied to the issue** (#78 D16): no convention ties a commit to an issue.
- **Keep the failing criterion in the size-test stop's PR body:** it needs a second way to open the PR that restates step 3's condition, no skill reads the line, and the next run's PR step rewrites the body.
- **State the condition and the open command in the PR step, and point step 3 and the size-test stop there:** step 3 opens the PR first, so the first write would point to a later step, and the PR step would keep its fork between opening and rewriting.
- **A REST-only rule, with lists read page by page and `POST pulls/<n>/ccr/ready_for_review` as the fallback for marking a PR ready** (#368 D5 to D7): it served the cloud proxy, which the plugin no longer supports, and each rule cost a workaround in every skill.
- **Create a branch linked to its issue through GraphQL, and fall back to `git push` on the 403** (#78 D10, replaced by #181 D5): no REST route links a branch, so the link exists only on some surfaces, and the lookup by name makes it unneeded. Two ways to create one branch double what each skill must handle.
- **Find the feature branch by its link to the issue:** reading the link needs GraphQL, no skill creates the link, and deleting a merged branch also removes it.
- **A line in the umbrella body that names the feature branch:** it is hand-written state (ADR-001), and `formats.md` allows no extra section.
- **Stop and ask the user to run execute again on a PENDING verdict:** a step with no decision in it, which an unattended Build cannot take.
- **Wait for CI inside a T3 Code thread:** the thread stays working for the whole CI run, and Autopilot starts nothing meanwhile.
- **An interval scheduled task that the resumed run deletes, for the PENDING resume:** a missed delete fires it every 10 minutes forever, and the resume count cannot stop it.

## Consequences
- discuss, slice, execute, verify and ship work the same from the desktop, the laptop and the phone, because each reaches the one host.
- Skills need `gh`, installed and authenticated, and no GitHub MCP tools.
- Every blocker is a GitHub link, so the Blocked icon shows for it.
- No branch is linked to its issue. The branch name and the PR's first line carry that tie.
- A deleted feature branch makes execute, verify and ship stop with a reason, because no remote branch matches.
- execute waits for CI by sleeping: it wakes up to three times, 10 minutes apart, and a CI run longer than that still ends in a stop.
