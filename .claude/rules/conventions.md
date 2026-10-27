---
description: "Cross-cutting conventions for maintaining the Cargus Forge plugin marketplace"
---

# Conventions

## Plugins & manifests

- Bump the plugin's `plugin.json` `version` (SemVer) in the same commit as any change to that plugin (see skill: plugin-release).
- On a feature branch, a plugin's version is `main`'s plus the largest bump that any of the branch's changes needs: a sub-issue bumps only when its change needs a larger level than the branch has (see skill: plugin-release).
- SemVer: bump MAJOR for breaking changes, MINOR for new features, PATCH for fixes.
- Register every new plugin in both `.claude-plugin/marketplace.json` and the README plugin index.
- Keep each plugin's description identical across its `plugin.json`, `marketplace.json`, and the README.
- Update a plugin's README when its commands, setup or requirements change.
- A marketplace entry's `source` must point to the plugin's real directory under `plugins/`.
- Edit `plugin.json` and `marketplace.json` by hand — they are not package-manager files.
- `author`/`owner` use `{ "name": "Carl Stålhem" }`; a plugin's `author` also includes `"url"`.

## Git workflow

- Branch from `main`; never commit plugin changes directly to `main`.
- Squash-merge every PR, so each PR is one commit and `main` stays linear (see skill: plugin-release).
- Validate with `claude plugin validate ./plugins/<name>` (add `--strict` in CI) before opening a PR.

## Testing plugins

- Run headless skill tests as `env -u CLAUDE_CODE_SESSION_ID claude -p --session-id <new uuid>`, so they do not write into the current session (see skill: plugin-testing).
- Pass `--allowedTools=Skill`, with `=`, when a `claude -p` test calls a skill that has `allowed-tools` through the Skill tool (see skill: plugin-testing).
- When a skill injects a file with `` !`cat …` ``, check in its verify step that the file exists; `claude plugin validate` does not (see skill: plugin-testing).
