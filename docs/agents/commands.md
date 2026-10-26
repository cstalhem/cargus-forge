# Commands

This repo has no build, tests or lint. A plugin is checked by validating it and by loading it in a session.

| Task | Command |
|---|---|
| Validate a plugin (pre-PR check) | `claude plugin validate ./plugins/<name> --strict` |
| Load a plugin for a test, without installing it | `claude --plugin-dir ./plugins/<name>` |
| Reload an installed plugin after an edit | `/reload-plugins` |

- `--plugin-dir` takes precedence over an installed copy of the same plugin.
- A change to a plugin also bumps `version` in its `plugin.json`. On a feature branch, the version is `main`'s plus the largest bump that any of the branch's changes needs, so a sub-issue bumps only when its change needs a larger level than the branch has (see `.claude/rules/conventions.md`).
