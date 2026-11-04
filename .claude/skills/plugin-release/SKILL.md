---
name: plugin-release
description: "The reasons behind how a Cargus Forge plugin change is validated and merged: load errors versus warnings, squash-merge, and why plugins carry no version"
when_to_use: "When shipping a change to any plugin in this repo: reading a validator error or warning, or merging a plugin PR"
---

# Releasing a plugin

The reasons behind the rules for shipping a change to a plugin in this marketplace. The commands are in `docs/agents/commands.md`.

## Reasons

- **Validate:** wrong field types (e.g. a string where an array is expected) are load errors; unrecognized fields are warnings only.
- **Merge:** squash-merge, so the PR becomes one commit and `main` stays linear, and delete the branch. The squash message is the PR title and description, so write the description for `git log`. Do not rebase-merge: it replays each commit and drops merge commits, so a branch that merged `main` in hits the same conflicts again.

## Anti-Patterns

- **What went wrong:** Added a `version` to a `plugin.json` or a marketplace entry, for example to quiet the validator's "No version specified" warning.
  **Why:** With an explicit `version`, Claude Code caches by version string, so users keep their cached copy until the string changes and `/plugin update` reports "already at the latest version" — a silent no-op. Every PR that bumped the version from the same `main` also conflicted with the others. Without a `version`, Claude Code versions a plugin by its commit SHA, so each change reaches users with no bump.
  **Fix:** Leave `version` out. `scripts/validate-plugins.sh` ignores the missing-version warning (see `.claude/rules/conventions.md` and `.claude/rules/critical-patterns.md`).

- **What went wrong:** `git push` or `gh pr create` hung with an SSH timeout, or failed with `Permission denied (publickey)`.
  **Why:** Those commands need the unsandboxed environment (SSH keys and network egress); the remote configuration itself is fine.
  **Fix:** Run `git push` and `gh` outside the command sandbox. Do not work around it by rewriting the SSH remote to an HTTPS push.
