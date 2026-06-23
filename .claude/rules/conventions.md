---
description: "Cross-cutting conventions for maintaining the Cargus Forge plugin marketplace"
---

# Conventions

## Plugins & manifests

- Bump the plugin's `plugin.json` `version` (SemVer) in the same commit as any change to that plugin (see skill: plugin-release).
- SemVer: bump MAJOR for breaking changes, MINOR for new features, PATCH for fixes.
- Register every new plugin in both `.claude-plugin/marketplace.json` and the README plugin index.
- Keep each plugin's description identical across its `plugin.json`, `marketplace.json`, and the README.
- A marketplace entry's `source` must point to the plugin's real directory under `plugins/`.
- Edit `plugin.json` and `marketplace.json` by hand — they are not package-manager files.
- `author`/`owner` use `{ "name": "Carl Stålhem" }`; a plugin's `author` also includes `"url"`.

## Git workflow

- Branch from `main`; never commit plugin changes directly to `main`.
- Rebase-merge PRs to keep `main` history linear.
- Validate with `claude plugin validate ./plugins/<name>` (add `--strict` in CI) before opening a PR.
