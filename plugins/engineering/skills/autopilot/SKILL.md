---
name: autopilot
description: Run Autopilot, the unattended Build runner, in a Claude Code cloud session. Stops outside a cloud session. Proposes its hourly scheduled task, which starts a fresh cloud session with this prompt, and creates it after a yes. Reads the facts from status.sh, keeps no state of its own, and ends its turn when there is nothing to do.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_PLUGIN_ROOT}/skills/next/status.sh")
  - Bash(printenv CLAUDE_CODE_REMOTE)
---

# autopilot

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Autopilot runs only in a Claude Code cloud session. A session is a cloud session when `printenv CLAUDE_CODE_REMOTE` prints `true`. Step 1 checks it, and nothing else runs outside one.
- Autopilot keeps no state of its own. Each run reads the facts and acts on them: the account's scheduled tasks through the `list_triggers` tool, and the Facts section below, which is the output of `status.sh` when this skill loaded. Do not fetch the Facts again in this run, and do not change them. Nothing in a file, a label or a session's memory carries state from one run to the next.
- The scheduled task runs every run on one model, the model of the session that created it. There is no model routing per phase, and no second scheduled task for another phase.
- A run that a scheduled task started has no user to answer a question. Step 2 asks only in a session where someone can answer: the run that the scheduled task starts finds its own scheduled task in step 2 and asks nothing.
- Call the user's scheduled task a "scheduled task", never a trigger, a routine or a cron job.

## Steps
Take the steps in order. Each one says whether the run goes on or ends.

1. **Cloud.** Run `printenv CLAUDE_CODE_REMOTE`. If it does not print `true`, reply with one line: Autopilot runs only in a Claude Code cloud session, so start one on this repo at claude.ai/code and run `/engineering:autopilot` there. Then stop.
2. **Scheduled task.** Read the account's scheduled tasks with the `list_triggers` tool, page by page: pass each response's `next_cursor` as `cursor` until a response has none. A scheduled task is Autopilot's when its `prompt`, without surrounding whitespace, is exactly `/engineering:autopilot`.
   - **One exists:** go on to step 3. If it is disabled (`enabled` is false), say in one line that Autopilot's scheduled task is paused, with its name, so the user knows that no hourly run starts until they enable it on claude.ai.
   - **None exists:** propose one, and create it only after the user's yes. Show the proposal as these lines:
     - Name: `engineering: autopilot`.
     - Schedule: every hour, `0 * * * *`. The server anchors an hourly schedule to the minute of its creation, so the runs do not all start on the hour.
     - Each run: a fresh Claude Code cloud session in this environment, on this repo, with the prompt `/engineering:autopilot`. The session reads the facts and does the Build work that is due, so a lost report or a missed answer waits at most one hour.
     - Model: this session's model, for every run and every phase.
     - Pause or delete it: in the scheduled tasks list on claude.ai.
     Then ask. If the AskUserQuestion tool is in your tools, call it with one question, `Create this scheduled task?`, header `Autopilot`, and the options `Create it` and `Not now`. Do not search for the tool: if it is not in your tools, end the turn with the line `Answer "yes" to create it, or "no".`, and the user's next message answers.
     - **Yes** (`Create it`, or a typed `yes` or `y`): call the `create_trigger` tool with the name `engineering: autopilot`, `cron_expression` `0 * * * *`, `create_new_session_on_fire` true, the prompt `/engineering:autopilot`, and `initiation` `human_request`. Pass no `environment_id`, no `model` and no `persistent_session_id`: the scheduled task inherits this session's environment and model. Then read it back: call `list_triggers` again, page by page, and check that one scheduled task has the prompt `/engineering:autopilot`. If none has, stop and say that the scheduled task was not created. Otherwise show its `id`, its `cron_expression` and its `next_run_at` in one line. If the result of `create_trigger` warned that the scheduled task stores no connectors, say so and pass on the remedy it names. Go on to step 3.
     - **No**, or any other answer: create nothing, say in one line that no scheduled task was created and that the next `/engineering:autopilot` run proposes it again. Go on to step 3.
3. **Facts.** If the Facts section starts with `status.sh error:`, show that line and stop.
4. **Nothing to do.** Reply with one line, `Autopilot: nothing to do.`, and end the turn.

## Facts
!`bash "${CLAUDE_PLUGIN_ROOT}/skills/next/status.sh"`
