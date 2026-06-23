---
name: plugin-release
description: "Release workflow for a Cargus Forge plugin — validate, version-bump, sync descriptions, commit, PR, merge"
when_to_use: "When shipping a change to any plugin in this repo: cutting a release, bumping a version, or opening and merging a plugin PR"
---

# Releasing a plugin

The end-to-end workflow for shipping a change to a plugin in this marketplace.

## Steps

1. **Validate** — `claude plugin validate ./plugins/<name>` (use `--strict` to treat warnings as errors). Wrong field types (e.g. a string where an array is expected) are load errors; unrecognized fields are warnings only.
2. **Bump the version** — edit `plugins/<name>/.claude-plugin/plugin.json` `version` in the same commit as the change. SemVer: MAJOR for breaking changes, MINOR for new features, PATCH for fixes.
3. **Sync descriptions** — if the plugin's description changed, update it identically in `plugin.json`, `.claude-plugin/marketplace.json`, and the README plugin index.
4. **Branch & commit** — branch from `main`; commit the plugin change and the version bump together.
5. **Push & PR** — push the branch and open the PR against `main`.
6. **Merge** — rebase-merge to keep `main` linear, and delete the branch.

## Anti-Patterns

- **What went wrong:** Pushed plugin changes without bumping `version`.
  **Why:** With an explicit `version`, Claude Code caches by version string, so users never receive the update and `/plugin update` reports "already at the latest version" — a silent no-op.
  **Fix:** Always bump `version` in the same commit (see `.claude/rules/conventions.md` and `.claude/rules/critical-patterns.md`).

- **What went wrong:** `git push` or `gh pr create` hung with an SSH timeout, or failed with `Permission denied (publickey)`.
  **Why:** Those commands need the unsandboxed environment (SSH keys and network egress); the remote configuration itself is fine.
  **Fix:** Run `git push` and `gh` outside the command sandbox. Do not work around it by rewriting the SSH remote to an HTTPS push.
