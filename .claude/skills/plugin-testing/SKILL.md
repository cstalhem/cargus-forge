---
name: plugin-testing
description: "Headless test runs of a plugin's skills with claude -p: keeping a run out of the current session, seeing what a skill loaded, testing a skill that another skill calls, and injecting files into a skill body with ${CLAUDE_PLUGIN_ROOT}"
when_to_use: "When running a manual or verify test of a plugin skill with claude -p, checking what a skill's body holds after it loads, or writing a !`command` injection or allowed-tools line in a plugin skill"
---

# Testing plugin skills headless

Supports the "Testing plugins" rules in `.claude/rules/conventions.md`.

## Run in a fresh session

```bash
env -u CLAUDE_CODE_SESSION_ID claude -p --session-id "$(python3 -c 'import uuid; print(uuid.uuid4())')" \
  --plugin-dir ./plugins/<name> "<prompt>" < /dev/null
```

A `claude -p` started from inside a Claude Code session inherits `CLAUDE_CODE_SESSION_ID`. Without its own `--session-id`, the run writes its events into the parent session's transcript. `uuidgen` is not installed in every environment, so the example uses Python. `< /dev/null` skips the 3-second wait for stdin.

## See what a skill loaded

- Add `--output-format stream-json --verbose`, and `--max-turns 1` or `2` to keep the run short.
- Ask the model to quote a section of the skill exactly and then stop.
- A skill called through the Skill tool: its loaded body is the user event right after the Skill tool result. Check that injected text is there and the literal `` !`…` `` line is not.
- A typed skill (`/<plugin>:<skill>`): the loaded body is in the run's session transcript.
- Check `permission_denials` in the `result` event.

## Test a skill that another skill calls

In `claude -p`, the Skill tool needs approval. Pass `--allowedTools Skill`, or the call is denied and the run only reports that the skill did not load.

## Inject a file into a skill body

- `` !`cat "${CLAUDE_PLUGIN_ROOT}/references/<file>.md"` `` runs when the skill loads, and the model sees only the output, as part of the skill body.
- `${CLAUDE_PLUGIN_ROOT}` is substituted as plain text, both in the injection line and in `allowed-tools`. So `allowed-tools: Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/<file>.md")` pre-approves exactly that command.
- Quote the path, because an install path can contain spaces. A path with `"`, `$` or a backtick would still break it.
- A read-only `cat` runs without approval in `default` mode. A command that is not read-only needs a matching `allowed-tools` line, or the skill does not load.
- If the command fails or is blocked:
  - a typed skill stops with 0 turns, an empty result and `is_error: false` in `claude -p`;
  - a skill called through the Skill tool gets the error as the tool result, and the model reports it.
- `claude plugin validate --strict` does not catch a missing injected file. Check it in the verify step, for example with `test -f`.

## Anti-Patterns

- **What went wrong:** Test runs of `claude -p` started from inside a session added their events to that session's transcript.
  **Why:** The child process inherits `CLAUDE_CODE_SESSION_ID` and reuses the session unless it gets its own `--session-id`.
  **Fix:** Unset the variable and pass a new UUID, as in "Run in a fresh session".
- **What went wrong:** A skill with a broken injection line ran in `claude -p`, returned an empty result and reported success.
  **Why:** A failed or blocked `` !`…` `` command stops a typed skill before the first turn, and `claude -p` does not mark that as an error.
  **Fix:** Check the injected file in the verify step, and check `num_turns` in the result, not only `is_error`.
