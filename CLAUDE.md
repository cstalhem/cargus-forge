# Cargus Forge

A marketplace monorepo of Claude Code plugins for knowledge management, note-taking workflows, and Claude Code productivity.

## Repository layout

- `plugins/<name>/` — one self-contained plugin each:
  - `.claude-plugin/plugin.json` — manifest (`name`, `description`, `author`)
  - `skills/<skill>/SKILL.md`, `agents/`, `hooks/hooks.json` — components, auto-discovered when the plugin is installed
- `.claude-plugin/marketplace.json` — root marketplace listing every plugin (`name`, `source`, `description`)
- `README.md` — human-facing plugin index
- `docs/adr/` — architecture decision records (ADR-NNN, living documents, indexed in `docs/adr/README.md`)
- `.github/workflows/close-sub-issue.yml` — a byte-identical copy of `plugins/engineering/templates/close-sub-issue.yml`, because this repo holds the plugin. Change the template, then copy it.

## Commands

Commands (pre-PR checks, tests, load a plugin without installing it, reload after an edit): `docs/agents/commands.md`

## Component authoring

For how to write skills, agents, hooks, commands, MCP/LSP config, and plugin directory structure, use the installed **`plugin-dev`** plugin and the official docs. This repo's rules and skills do not restate that general guidance — they capture only this repo's wiring and conventions.

# Rules and skills

- Conventions are one-line rules in `.claude/rules/`, with steps and examples in a backing skill in `.claude/skills/`; `plugins/engineering/references/repo-rules.md` defines both, and execute's reflect step adds them ([ADR-009](docs/adr/ADR-009-conventions-are-claude-code-rules.md)).
- A convention or gotcha you find goes in a rule, never in the memory directory.

