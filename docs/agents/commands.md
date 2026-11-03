# Commands

This repo has no build or lint. A plugin is checked by validating it and by loading it in a session, and the tests are the `*.test.sh` scripts.

| Task | Command |
|---|---|
| Validate every plugin and the marketplace root (pre-PR check) | `scripts/validate-plugins.sh` |
| Check plugin descriptions and marketplace entries (pre-PR check) | `scripts/check-descriptions.sh` |
| Run the tests (pre-PR check) | `for t in $(git ls-files '*.test.sh'); do bash "$t" > /dev/null || exit 1; done` |
| Load a plugin for a test, without installing it | `claude --plugin-dir ./plugins/<name>` |
| Reload an installed plugin after an edit | `/reload-plugins` |

- `--plugin-dir` takes precedence over an installed copy of the same plugin.
