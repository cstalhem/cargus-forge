# Commands

This repo has no build, and its one lint counts comment lines ([ADR-012](../adr/ADR-012-code-carries-no-comments.md)). A plugin is checked by validating it and by loading it in a session, and `scripts/test.sh` runs the tests.

| Task | Command |
|---|---|
| Validate every plugin and the marketplace root (pre-PR check) | `scripts/validate-plugins.sh` |
| Check plugin descriptions and marketplace entries (pre-PR check) | `scripts/check-descriptions.sh` |
| Run the tests (pre-PR check) | `scripts/test.sh` |
| Check that no file has more comment lines than its baseline (pre-PR check) | `scripts/check-comments.sh` |
| Lower the comment baseline after deleting comments | `scripts/check-comments.sh --update` |
| Load a plugin for a test, without installing it | `claude --plugin-dir ./plugins/<name>` |
| Reload an installed plugin after an edit | `/reload-plugins` |
| Update the installed plugin to `main` after a merge | `claude plugin marketplace update && claude plugin update <name>@cargus-forge --scope user` |

- `--plugin-dir` takes precedence over an installed copy of the same plugin.
- A new folder copies the user-scope install's version on its first launch, so `claude plugin marketplace update` alone leaves it on the old version.
