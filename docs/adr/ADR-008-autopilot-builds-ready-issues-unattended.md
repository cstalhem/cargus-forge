---
adr: 008
title: Autopilot builds ready issues unattended
status: active
---

# ADR-008: Autopilot builds ready issues unattended

- **Decision:** An hourly scheduled task starts a fresh cloud session that runs `/engineering:autopilot`, which builds each ready issue in a child session, one at a time, answers each child's questions, merges sub-issue PRs that verify marked ready, starts ship, and hands only PRs into `main` and stuck issues to the user.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md), [ADR-004](ADR-004-skills-load-on-demand-scripts-fetch-facts.md), [ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)
- **Source:** [#224](https://github.com/cstalhem/cargus-forge/issues/224)

## Details
- **Shape stays with the user.** Autopilot runs neither discuss nor slice, and leaves requests alone. It starts at a ready issue, one with a `## Scenarios` section and no open blocker, and ends at a PR into `main`: a single issue's PR or a final PR, which the user reviews and merges.
- **A typed skill.** `autopilot` has `disable-model-invocation: true`, so it costs no context until typed, and the scheduled task's prompt is exactly `/engineering:autopilot` ([ADR-004](ADR-004-skills-load-on-demand-scripts-fetch-facts.md)). It runs only in a Claude Code cloud session, where the session and scheduled task tools exist ([ADR-006](ADR-006-engineering-runs-in-cloud-sessions.md)).
- **No state of its own.** Each run reads the facts: the account's scheduled tasks through `list_triggers`, its sessions through `list_sessions`, `get_session` and `list_events`, each issue's status through `status.sh` ([ADR-001](ADR-001-github-is-the-work-state-store.md)), and hand-offs as comments on the issue or the PR. The sessions tagged `autopilot`, titled `execute #<n>` or `ship #<u>`, are the claim on an issue, whatever the session's state.
- **One child at a time**, sub-issues in blocked-by order. A child is a cloud session on this repo, started with `create_session`, whose prompt is the typed `/engineering:execute #<n>` or `/engineering:ship #<u>`, so execute keeps its required argument and `disable-model-invocation`. It inherits the environment, model and permission mode. Its system prompt holds one report line: when its turn ends, for any reason, it sends one message to Autopilot's session, `<title>: finished`, `<title>: stopped on a question` or `<title>: stopped: <reason>`, with the PR and, for a question, its recommended answer. That report starts the next run. A child loads the engineering plugin from the environment it inherits, never from the checkout's skill files: in this repo, `CLAUDE_CODE_PLUGIN_DIRS` set on the cloud environment loads the plugin in place from the checkout; in another repo, the environment's setup script installs it. The plugins synced from claude.ai do not reach a child. A run checks the environment with `claude plugin list` before it starts a child, and a child whose typed prompt did not load as a skill reports `<title>: stopped: engineering plugin not loaded in this environment` and does nothing else.
- **Answers.** Autopilot answers a child with the child's recommended answer, or with the answer that changes no scenario and no decision of the issue, at most three times. Each answer starts with `Autopilot: answer <k> of 3`, so a run counts the answers in the child's events. execute records each answer under the PR's `## Deviations` as `Autopilot: <question> → <answer>, because <why>`, and ship gathers those lines into the final PR, so the user reads them at review.
- **Merges.** Autopilot squash-merges a sub-issue PR once verify has marked it ready ([ADR-002](ADR-002-feature-branch-per-umbrella.md)). When a child's verify passed but could not mark the PR ready, because the permission was denied in the child, Autopilot marks it ready itself first. It merges no single-issue PR and no final PR. execute, verify and ship merge nothing, as before, so a Build skill run by hand changes nothing about who merges.
- **Hand-offs.** There are four: a child stopped on a permission prompt; a child that asks a fourth question after three answers; a child that stopped for another reason, such as execute sending a single issue back to discuss or the plugin not loading in the child; and a single issue's PR or a final PR that is ready for review. Each is one comment, `Autopilot: stopped, <why>` on the issue or `Autopilot: ready for your review` on the PR, and one push notification. The comment is the record, so a run hands the same thing off only once.
- **One model.** The scheduled task runs on the model of the session that created it, for every run and every phase.
- **The hourly run is the backstop.** A lost report or a missed answer waits at most one hour, because the next run reads the same facts and the same events.
- **The scheduled task** is created from a manual run, after the user's yes: `engineering: autopilot`, `0 * * * *`, a fresh session each firing, in the environment of the session that created it. The user pauses or deletes it in the scheduled tasks list on claude.ai, and a manual run reports a paused one.
- **No trial run.** The first real issue Autopilot builds is its test, and what it shows broken becomes a new issue.

## Rejected alternatives
- **Shape over issue comments:** discuss and slice are questions and yes gates, so an unattended run saves no work and needs a comment protocol, a waiting status and an event trigger.
- **One hourly run per sub-issue:** an umbrella would take days.
- **Parallel children:** sub-issues touch the same `plugin.json` and skill files, and execute never merges the feature branch into a sub-issue branch.
- **A bare `/engineering:execute` that picks the first ready issue:** a scheduled task's prompt holds one command, and the orchestration then lives in execute.
- **One persistent Autopilot session:** it needs a manual start, must survive forever and compacts over months, while a fresh session reads every fact from the service.
- **Polling children with `send_later`:** a line in the child's system prompt makes it report when its turn ends.
- **A claim label on the issue:** it copies the session list and goes stale when a child dies before its PR, which needs a repair step.
- **A child that follows the skill file from the checkout when its typed prompt did not load:** it works only in the plugin's own repo, and it bypasses `$ARGUMENTS`, the injected rules and `allowed-tools`, so the child runs an untyped copy of the skill.

## Consequences
- The user shapes requests in discuss and reviews PRs into `main`. Everything between runs unattended, and the plugin still works without Autopilot.
- A sub-issue PR reaches the feature branch with no human review. The review happens on the final PR, which gathers every deviation and every answer Autopilot gave.
- A child that needs a human waits for the user, and the issue's comment names the session to open.
- The scheduled task starts a session every hour, which costs tokens even when the run finds nothing to do.
- The cloud environment must provide the plugin to children, through `CLAUDE_CODE_PLUGIN_DIRS` in this repo or the setup script elsewhere, and a setup-script copy goes stale for up to a week until the script changes.
- A plugin bug that a child hits ends as a stopped issue with one comment, and becomes a new issue, not a silent retry loop.
