---
title: "Research: Claude Code docs (v2.1.296)"
date: 2026-10-10
source: research subagent report, unedited
---

> Research subagent report from 2026-10-10, saved unedited. Paths under `/tmp/claude-1000/...` point to an ephemeral scratchpad and no longer exist.

I read the current docs at code.claude.com/docs as of v2.1.296 (October 9, 2026). The page index is at https://code.claude.com/docs/llms.txt, and raw markdown copies are saved in /tmp/claude-1000/-home-calle-projects-cargus-forge/ea3ae446-4d33-5368-8304-92a9a4c30e4d/scratchpad/d/. Version tags such as "v2.1.287" give the minimum Claude Code version.

---

## 1. Plugins
Sources: https://code.claude.com/docs/en/plugins/manifest-reference, /plugins/components, /plugins/loading, /plugins/dependencies, /plugins/marketplace-reference, /plugins/cli-reference, /plugin-evals

**Standard layout** (all paths are relative to the plugin root; nothing except `plugin.json` goes inside `.claude-plugin/`):

| Path | Contents |
| :- | :- |
| `.claude-plugin/plugin.json` | Manifest. Optional; without it, the name comes from the marketplace entry or the directory name |
| `skills/<name>/SKILL.md` | Skills |
| `commands/*.md` | Legacy commands; skills supersede them |
| `agents/*.md` | Agents; scanned recursively, and subfolders become part of the name (`plugin:review:security`) |
| `hooks/hooks.json` | Hooks, wrapped in a top-level `"hooks"` key |
| `.mcp.json` | MCP servers |
| `.lsp.json` | LSP servers |
| `output-styles/` | Output styles |
| `workflows/*.js` | Workflows |
| `themes/` | Themes |
| `monitors/monitors.json` | Monitors |
| `bin/` | On the Bash tool's PATH, after the user's own PATH. claude.ai and Cowork refuse to install a plugin that has a top-level `bin/` |
| `settings.json` | Only the `agent` and `subagentStatusLine` keys take effect |

- A `CLAUDE.md` at the plugin root is not loaded, and `validate` warns about it. Put instructions that should load into context in a skill.
- A plugin with a `SKILL.md` at its root and no `skills/` directory loads as a single skill. Set `name` in that skill, or a marketplace install names it after the cache directory.

**plugin.json fields:**
- `name` is the only required field. It must be kebab-case. Names starting with `claude-`, `anthropic-` or `cc-plugin-` are reserved and refused.
- Optional: `displayName`, `version`, `description`, `author{name,email,url}`, `homepage` (must parse as a URL), `repository`, `license`, `keywords`, `metadata` (free-form; Claude Code doesn't read it), `defaultEnabled` (default true), `dependencies`, `settings`, `userConfig`, `channels`, `types` (a `.d.ts` file for mods).
- Component keys: `skills`, `commands`, `agents`, `hooks`, `mcpServers`, `lspServers`, `outputStyles`, `workflows`.
- `experimental{themes, monitors, evals}`.
- Directory-listing fields, which Claude Code ignores at load: `icon`, `documentationUrl`, `supportUrl`, `privacyPolicyUrl`, `termsOfServiceUrl`.

**How component keys combine with default locations:**
- These replace the default scan: `commands`, `agents`, `outputStyles`, `workflows`, `themes`, `monitors`.
- `skills` adds to the default `skills/` scan.
- `hooks`, `mcpServers` and `lspServers` merge with the default files.
- Every path must start with `./` and stay inside the plugin. Paths containing `..` and symlinks that lead outside the plugin are rejected.
- An unknown top-level key is stripped and only produces a warning. An unknown key inside `userConfig`, `channels`, `lspServers` or `monitors` is an error and the plugin doesn't load.

**Path variables:**
- `${CLAUDE_PLUGIN_ROOT}` is the versioned install directory. It changes on every update, so never write state there.
- `${CLAUDE_PLUGIN_DATA}` is `~/.claude/plugins/data/<id>/`. It survives updates and is deleted when the plugin is uninstalled from its last scope (`--keep-data` keeps it).
- `${CLAUDE_PROJECT_DIR}` is the project root.
- Where they resolve: inline in hook `command`/`args`, MCP/LSP config, and the body of skills, agents and commands.
- Hook processes also get them as environment variables, plus `CLAUDE_PLUGIN_OPTION_<KEY>`.
- They are not set in the environment of Bash tool calls, so write `${...}` in the skill body and let Claude Code substitute it.
- In shell-form hooks, wrap the variable in double quotes (`"\"${CLAUDE_PLUGIN_ROOT}\"/scripts/x.sh"`), or use exec form with `args`.

**userConfig:**
- Each option is a strict object: `type` (string, number, boolean, directory or file), `title`, `description`, plus optional `required`, `default`, `options` (v2.1.271), `multiple`, `sensitive`, `min`, `max`.
- The user is prompted on `/plugin install` or enable. `claude plugin install` in the shell never prompts; use `--config KEY=VALUE` or `claude plugin configure --values-stdin`.
- Non-sensitive values are stored in `pluginConfigs` in settings. Sensitive values go to the OS keychain.
- Reference a value as `${user_config.KEY}` in MCP/LSP config, exec-form hook args and skill/agent content (sensitive values become a placeholder there), or read `CLAUDE_PLUGIN_OPTION_KEY` in hook processes.
- Shell-form hooks, monitors and `headersHelper` reject `${user_config.*}`.

**Versioning and caching (this matches your critical-patterns rule):**
- Installed copies live at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.
- Version resolution order: `plugin.json` `version`, then the marketplace entry's `version`, then the git commit SHA (12 characters) for github, url and git-subdir sources and for relative paths inside a git-hosted marketplace.
- Pinning `version` keeps every user on the cached copy until the string changes. Leave `version` out of both the manifest and the entry if users should track commits.
- Relative-path plugins in a marketplace added from a local path load in place, so edits apply at the next session or `/reload-plugins` without a version bump.
- Old version directories get an `.orphaned_at` marker and are deleted after 14 days.
- Auto-update runs after a random delay of up to 10 minutes. It is off by default for third-party marketplaces and toggled per marketplace.
- If the plugin root has `package.json` plus `bun.lock` or `package-lock.json`, npm or bun dependencies are auto-installed into the cache copy. The install is frozen, uses `--ignore-scripts`, and times out after 60 seconds.

**Dependencies:**
- Declared as `"dependencies": ["name", "name@mkt", {name, version:"~2.1.0", marketplace}]`.
- A range resolves against git tags named `<plugin>--v<version>`. `claude plugin tag [--push|--dry-run]` creates that tag after validating and checking that the manifest and marketplace entry agree on the version.
- Cross-marketplace dependencies require `allowCrossMarketplaceDependenciesOn` in the marketplace file.
- A plugin can be a "bundle": just a `name` and a `dependencies` list.

**marketplace.json:**
- Required: `name`, `owner{name}`, `plugins[]`. Optional: `description`, `version`, `metadata.pluginRoot`, `forceRemoveDeletedPlugins`, `renames`, `allowCrossMarketplaceDependenciesOn`.
- Each entry needs `name` and `source`. Sources can be a relative path, github, url, git-subdir, npm, archive or command.
- Entry-only fields: `category`, `tags`, `strict` (default true), `relevance`, `headers`, `headersHelper`.
- Display fields set on the entry (`displayName`, `description`, `author`, and so on) override `plugin.json`. The manifest's `version` overrides the entry's.

**CLI:**
- `claude plugin init <name> --with skills hooks …` scaffolds into `~/.claude/skills/<name>`, which loads as `<name>@skills-dir`.
- `claude plugin validate <path> [--strict] [--json]` also checks MCP entries, from v2.1.281.
- Other commands: `claude plugin eval` / `eval init` (v2.1.269), `claude plugin test` (mods), `claude plugin tag`, `claude plugin configure`, `claude plugin prune`, `claude plugin details`.
- Session commands and flags: `/reload-plugins`, `--plugin-dir`, `--plugin-url`.

**Evals (new, v2.1.269):**
- Layout: `evals/<case>/prompt.md` plus `graders/*.md`.
- Grader types: `regex`, `tool_used`, `tool_order`, `file_exists`, `llm`, `baseline`.
- Runs compare against a no-plugin baseline by default, and support MCP mocks and `--threshold` for CI.

**Other plugin capabilities:**
- Monitors (experimental): background processes with `when: "always"` or `"on-skill-invoke:<skill>"`.
- Channels: chat bridges bound to one of the plugin's MCP servers.
- `force-for-plugin` on an output style applies it automatically while the plugin is enabled.

## 2. Skills
Source: https://code.claude.com/docs/en/skills

**Frontmatter.** All fields are optional; Claude Code silently ignores unknown fields.
- `name`: the command name. In a plugin it replaces only the last segment, so the command is `/<plugin>:<name>`.
- `description`: recommended. `description` plus `when_to_use` are truncated at **1,536 characters** combined in the listing. Put the key use case first.
- `when_to_use`, `argument-hint`, `arguments` (named positional arguments, giving `$name` placeholders).
- `disable-model-invocation`: only the user can invoke the skill. Its description is then not in context, and it can't be preloaded into subagents or run by scheduled tasks.
- `user-invocable: false`: only Claude can invoke it.
- `allowed-tools`: a permission grant that lasts only for the invoking turn. It accepts `Bash(${CLAUDE_SKILL_DIR}/scripts/x.sh *)`.
- `disallowed-tools`.
- `model`: for the current turn only; accepts `inherit`.
- `effort`: low, medium, high, xhigh or max.
- `context: fork`, plus `agent` (Explore, Plan, general-purpose or a custom agent; default general-purpose).
- `background` (v2.1.218): forked skills run in the background by default; set `false` to wait for the result.
- `hooks`: registered on invoke and kept for the rest of the session; `once: true` removes a hook after its first successful run.
- `paths`: globs; the skill auto-loads only when Claude works on matching files.
- `shell`: bash or powershell.
- Agent Skills spec fields `metadata`, `license`, `compatibility`. Only `name`, `description`, `license`, `compatibility`, `metadata` and `allowed-tools` are allowed when uploading to claude.ai or the API; any other key is a hard error there.

**Substitutions:**
- `$ARGUMENTS`, `$ARGUMENTS[N]` / `$N`, `$name`.
- `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`.
- `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}`, in plugin skills only.

**Dynamic context:**
- `` !`cmd` `` at the start of a line or after whitespace, or a ` ```! ` fenced block for multi-line commands, runs before Claude sees the skill.
- A non-zero exit aborts the whole invocation. Search and compare commands may exit 1 without aborting; append `|| true` to anything else that can exit non-zero.
- The commands never prompt for permission. A deny rule, or anything that isn't an allow, aborts the invocation outside auto mode, so pre-approve them with `allowed-tools`.
- Each command has a 2-minute timeout. Output is not re-scanned for further placeholders.
- The `disableSkillShellExecution` setting turns this off. It never runs for skills synced from claude.ai.

**Loading and lifecycle:**
- The listing (names and descriptions) is always in context. Its budget is about 1% of the context window (`skillListingBudgetFraction` or `SLASH_COMMAND_TOOL_CHAR_BUDGET`). When it overflows, descriptions of the least-used skills are dropped first. `skillOverrides` can set a skill to `"name-only"`.
- The full body loads only when the skill is invoked. It then stays in the conversation as one message; the file is not re-read.
- After compaction, invoked skills are re-attached at up to **5,000 tokens each and 25,000 tokens total**, most recent first, keeping the start of each file. Put critical instructions at the top.
- Keep `SKILL.md` under 500 lines. Supporting files (`reference.md`, `scripts/`) are loaded or executed on demand and should be linked from `SKILL.md`.
- Locations: enterprise, `~/.claude/skills`, project `.claude/skills` (including parent directories up to the repo root), nested `.claude/skills` (loaded lazily when Claude touches files there), plugin, and claude.ai-synced (`~/.claude/skills/synced/`).
- Adding `.claude-plugin/plugin.json` to a skill folder turns it into a `@skills-dir` plugin.
- Tools: `/doctor` and `/skill-doctor` show listing cost and unused skills. `/doctor prompt-audit` (v2.1.283) audits CLAUDE.md, skills and agents for prompting patterns written for older models.

**Skill vs command:** commands (`commands/*.md`) are the legacy format, take the same frontmatter except `name` and `paths`, and can't carry supporting files. Use skills for new work.

## 3. Subagents
Source: https://code.claude.com/docs/en/sub-agents

**Scopes, by priority:** managed, then `--agents` JSON, then `.claude/agents/` (walked up to the repo root), then `~/.claude/agents/`, then plugin `agents/` (lowest). Files are watched and hot-reload.

**Frontmatter (camelCase):**
- Required: `name` (up to 256 characters, no `:`) and `description`.
- `tools` and `disallowedTools`.
- `model`: sonnet, opus, haiku, fable, a full ID, or `inherit`.
- `permissionMode`, `maxTurns`.
- `skills`: preloads the full skill content into the agent.
- `mcpServers`, `hooks`.
- `memory`: user, project or local.
- `background`.
- `omitClaudeMd` (v2.1.271).
- `effort`.
- `isolation: worktree`: branches from the default branch and is auto-removed if the agent made no changes.
- `color`, `initialPrompt`.
- `experimental.cacheTtl`: 5m or 1h.
- `autoCompactWindow` (new in v2.1.296).

**Plugin agents ignore** `permissionMode`, `hooks`, `mcpServers` and `initialPrompt`.

**Model resolution order:**
1. The per-call `model` parameter
2. The agent's frontmatter
3. `CLAUDE_CODE_SUBAGENT_MODEL`
4. The main conversation's model

`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` forces one model everywhere. Explore and Plan skip CLAUDE.md and git status.

**Memory:**
- `user` → `~/.claude/agent-memory/<agent>/`
- `project` → `.claude/agent-memory/<agent>/` (recommended)
- `local` → `.claude/agent-memory-local/<agent>/`
- The agent's prompt gets the first 200 lines or 25 KB of its `MEMORY.md`, and Read, Write and Edit are enabled automatically.
- It requires auto memory to be on.

**Background and forks:**
- Fork mode is on by default in interactive sessions (v2.1.232). Spawned subagents run in the background, and their permission prompts surface in the main session.
- Background agents get a narrower tool set.
- `/subtask <task>` forks the full conversation into a background agent that shares the prompt cache. It was `/fork` on older versions.
- Nesting depth defaults to 3 (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`). The concurrency limit is 20 (`CLAUDE_CODE_MAX_CONCURRENT_…`).
- `/tasks` shows each agent's model and effort. Ctrl+B sends a running task to the background.

**Related:**
- Agent teams are experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).
- Agent view (`claude agents`) manages background sessions.
- Cross-session messaging works between your own sessions (v2.1.224).
- Worktrees: `claude --worktree <name>` creates `.claude/worktrees/<name>` on branch `worktree-<name>`; `.worktreeinclude` copies gitignored files into it.

## 4. Hooks
Sources: https://code.claude.com/docs/en/hooks, /hooks-guide

**Events:**
- Session: `SessionStart` (sources include `compact`), `Setup`, `SessionEnd`
- Prompts: `UserPromptSubmit`, `UserPromptExpansion`
- Tools and permissions: `PreToolUse`, `PermissionRequest`, `PermissionDenied`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`
- Display: `Notification`, `MessageDisplay`
- Agents and tasks: `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`
- Turn end: `Stop`, `StopFailure`
- Configuration and files: `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove`
- Compaction and models: `PreCompact`, `PostCompact`, `PreModelSwitch`, `PostModelSwitch`
- MCP: `Elicitation`, `ElicitationResult`

**Handler types:** `command`, `http`, `mcp_tool`, `prompt` (single-turn model judgment), `agent` (experimental).
- Common fields: `if` (one permission-rule pattern, such as `"Bash(git *)"`), `timeout`, `statusMessage`, `once` (skills only).
- `async`: run in the background.
- `onFailure: "block"`: new in v2.1.295.
- Default timeouts: command, http and mcp_tool 600 seconds; prompt 30; agent 60.

**Exit codes:** 0 is success and JSON output applies. 2 blocks, with stderr as the reason. Anything else is a non-blocking error.
- `additionalContext`, `systemMessage` and plain stdout are capped at 10,000 characters.

**Locations:** user, project and local settings, managed settings, plugin `hooks/hooks.json`, skill frontmatter, agent frontmatter.

**Plugin specifics:**
- Plugin hooks register when the plugin loads, not when one of its skills runs. Narrow them with `matcher`.
- Plugin MCP tools are named `mcp__plugin_<plugin>_<server>__<tool>`.
- Plugin hooks also fire inside subagents; the input carries `agent_id`.
- `$CLAUDE_CODE_REMOTE` is `"true"` in cloud sessions, and `$CLAUDE_CODE_BRIDGE_SESSION_ID` is set while Remote Control is active.

## 5. Remote Control
Source: https://code.claude.com/docs/en/remote-control

**What it is:** claude.ai/code or the Claude iOS/Android app becomes a window onto a session that keeps running on your machine. Files, MCP servers, tools and config all stay local, and the connection is outbound HTTPS only.

**Requirements:**
- Pro, Max, Team or Enterprise. On Team and Enterprise an Owner must turn it on first.
- A claude.ai login. API keys, Bedrock, Vertex, Foundry, a custom `ANTHROPIC_BASE_URL`, and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` all rule it out.

**Ways to start it:**
- **Server mode:** `claude remote-control` serves the repo. Flags:
  - `--name`
  - `--spawn same-dir|worktree|session` (press `w` to toggle while running)
  - `--capacity N` (default 32)
  - `--[no-]create-session-in-dir`
  - `--permission-mode`
  - `--chrome`
  - `-c/--continue` and `--session-id` resume a session for about 4 hours after the server stops.
  - Press space to show a QR code.
- **Interactive:** `claude --remote-control "name"` (alias `--rc`), or `/remote-control` (`/rc`) inside a running session, which carries the history over. This also works from VS Code and Desktop.
- **Auto-connect:** `remoteControlAtStartup: true` in user or managed settings, or via `/config`.

**From a phone or browser you can:**
- Chat.
- `@`-autocomplete local file paths.
- Attach photos and files. Files are downloaded to your machine as `@` references.
- See subagent and workflow progress, and stop them.
- Use a **diff pane**: changes since the branch split from the default branch plus uncommitted edits, or only uncommitted edits when on the default branch.
- Change model and effort.
- Answer permission prompts and `AskUserQuestion`.
- Get push notifications: `/config` → "Push when Claude decides" / "Push when actions required".
- Commands that work remotely: `/compact`, `/clear`, `/context`, `/usage`, `/model`, `/effort`, `/rename`, `/reload-plugins` (and a few more).

**Limitations:**
- One remote session per interactive process; server mode is needed for several.
- The local process must keep running; use tmux on remote machines.
- Server mode gives up after about 10 minutes offline.
- Local-only commands such as `/plugin` and `/resume` don't work remotely.
- Dialogs other than permission prompts and questions expire after 5 minutes (`dialogExpiry`).
- Not available with Zero Data Retention or HIPAA. Transcripts are stored on Anthropic's servers.
- Trusted Devices (beta) can require device enrollment and biometric re-authentication every 18 hours.

**Viewing files and plans remotely:** the docs describe the diff pane but no dedicated remote plan or file viewer. Plans live in `~/.claude/plans/` (configurable with `plansDirectory`). The practical way to read a plan or report on a phone is to publish it as an Artifact. Sessions started with `claude remote-control` can publish artifacts from v2.1.281 when you started the session yourself, and no browser tab opens on the host machine for remote prompts.

## 6. Artifacts
Source: https://code.claude.com/docs/en/artifacts

**What they are:**
- A live, interactive HTML or `.md` page that Claude publishes from the session to a private URL (claude.ai/code/artifact/…).
- It updates in place when republished, and every publish becomes a version.
- Gallery: claude.ai/code/artifacts. Reopen the latest with `Ctrl+]`, list with `/artifacts`; a `⧉` pill sits below the prompt.

**Requirements:**
- Pro, Max, Team or Enterprise, with a claude.ai `/login` and the Anthropic API.
- Not available with CMEK, HIPAA or ZDR.
- CLI or Desktop. Off by default with `-p`, the SDK and GitHub Actions.

**Sharing and collaboration:**
- Private by default. Can be shared with the organization (Team/Enterprise, with viewers or editors) or publicly.
- Comment threads: an editor's "Send to Claude" or an `@claude` mention reaches the session. Claude can auto-reply within your permission mode, capped at 60 per hour per artifact (v2.1.221 and v2.1.228).

**Capabilities:**
- Live MCP connector calls, run as the *viewer's* account (v2.1.209).
- File downloads.
- Templates: `/slides` and `/design`. Claude Docs is reached as a connector.

**Constraints:**
- One self-contained page under a strict CSP. Scripts may come only from cdnjs, unpkg, jsDelivr `/npm/`, the Tailwind CDN and the jQuery CDN; fonts only from Google Fonts. No external images.
- No backend. Rendered size up to 16 MiB.
- The artifact tool in this session also supports supporting files and assets, which the doc page does not yet describe.

**When Claude asks before publishing:** in plan mode, when the page declares capabilities, on a public artifact, and when the publish comes from a turn a scheduled task started.

**Turning it off:** `enableArtifact: false`, `CLAUDE_CODE_DISABLE_ARTIFACT=1`, or `Artifact` in deny rules.

**Producing artifacts from a skill or plugin:** the docs define no plugin component type for this. A skill's instructions tell Claude to write an HTML or `.md` page and publish it with the `Artifact` tool. Claude applies a built-in design skill, and a "Design system" section in CLAUDE.md overrides its choices.

## 7. Mods (new: "Added Claude Mods" in v2.1.287, October 1, 2026)
Sources: https://code.claude.com/docs/en/plugins/mods/overview, /mods/reference, /mods/interface, /mods/events, /mods/api

**What a mod is:** a plugin whose `hooks/hooks.json` has `"modules": ["./register.js"]`, pointing to an ES module (JS or TS) that exports `register(on, options)`. `options` holds the `userConfig` values.

**Hook API:** `on(event, matcher?, async ($, e, next) => …)`. The middleware can observe (`next(e)`), rewrite (`next({...e, x})`) or answer (return an object without calling `next`).

**Events:**
- Tools: `tool.call`, `tool.check`, `tool.describe`
- Prompts: `prompt.*`, `prompt.autocomplete`
- Turns: `turn.step`
- Agents: `agent.spawn` (can set a subagent's model or refuse it)
- Interface: `ui.render`, `ui.press`, `ui.input`, `ui.select`, `ui.close`, `ui.message`, `ui.fault`
- Session: `session.end`
- Models: `model.complete`

**Render sites:**
- New surfaces: `Pane` (docked or inline) and `AbovePrompt` (the "band").
- Restyling Claude Code's own UI: `Spinner`, `ToolUse`/`ToolResult`/`ToolGroup`, `UserMessage`, `AssistantMessage`, `AskUserQuestion`, `PromptHint`, `SessionMode`, `TurnDuration`, `InfoNotice`, `CommandOutput`.

**Elements:** `Box`, `Text`, `Button`, `Link`, `Code`, `Markdown`, `Input`, `Select`, `Svg` (Desktop only), `Raster` and `Image` (terminal only), `Client`.

**`$` API namespaces:**
- `$.ui`: `open`, `toast`, `status`, `notice`, `ask`, `invalidate`, `notify`, and more
- `$.command.register`: runs code with no Claude turn
- `$.tool.register`, `$.agent`, `$.model.complete` (with caching)
- `$.prompt.submit`, `$.session` (including `usage()` and `send`)
- `$.fs`, `$.store` (4 MiB, shared across sessions), `$.state` (reactive, typed through `types/index.d.ts`)
- `$.clock`, `$.http`, `$.process`, `$.mcp`, `$.audio`

**Limits:**
- 10 seconds per hook (50 ms for `prompt.edit`).
- `$.fs` up to 4 MiB per file.
- Redraws throttled to 10 per second.
- Toasts last 4 seconds by default.

**Where mods run:**
- The terminal and the Desktop Code tab draw them.
- In the VS Code chat panel, `-p` and cloud sessions the hooks run but nothing is drawn.
- Under Remote Control the hooks run, and the drawing appears only in the local terminal.

**Not sandboxed:** a mod runs with full user permissions.

**Build and test:**
- The built-in `plugin-authoring` skill writes mods.
- `claude plugin test` runs `*.test.ts` files.
- Sample mods: anthropics/claude-code-playground, `claude-code/mods`.
- Built-in mods include `cc-plugin-diff` and `cc-plugin-you-should-know`.

**Status line is a separate feature** (https://code.claude.com/docs/en/statusline): a `statusLine` command script in settings, or `/statusline <description>`. A plugin can only set `subagentStatusLine`, not the main status line; a mod can redraw the UI instead.

## 8. Other relevant features

**Memory and rules** (https://code.claude.com/docs/en/memory)
- CLAUDE.md and CLAUDE.local.md load from the working directory and every parent. Subdirectory files load lazily when Claude touches files there.
- `@path` imports go up to 4 hops deep. HTML comments are stripped.
- Target under 200 lines per file; files over 4 MiB are skipped.
- `.claude/rules/**/*.md`: the only frontmatter field read is `paths` (a glob list with brace expansion). Rules without `paths` load at launch.
- Path-scoped rules are summarized away by compaction and reload on demand. Drop `paths` if a rule must survive compaction.
- User-level rules live in `~/.claude/rules/`.

**Auto memory:**
- Stored in `~/.claude/projects/<project>/memory/`, one directory per git repository, shared across worktrees.
- The first 200 lines or 25 KB of `MEMORY.md` load every session; topic files are read on demand.
- Each memory file's frontmatter has a `type` (user, feedback, project or reference) and an auto-added `modified` timestamp.
- Controls: `autoMemoryEnabled`, `autoMemoryDirectory`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY`.
- Not loaded into subagents, except forks.

**Plan mode** (https://code.claude.com/docs/en/permission-modes)
- Enter with Shift+Tab, `/plan <prompt>`, or `--permission-mode plan`.
- Ctrl+G opens the plan in your editor.
- Plan files live in `~/.claude/plans/` (`plansDirectory`) and are re-injected after compaction.
- Make it the default with `defaultMode: "plan"`.

**Tasks / todo** (https://code.claude.com/docs/en/tools-reference)
- `TaskCreate`, `TaskGet`, `TaskUpdate` and `TaskList` (formerly `TodoWrite`) are available by default **only on older models** (Claude 3.x, Opus 4–4.7, Sonnet 4–4.6, Haiku 4.5).
- Newer models (Opus 5.x, Sonnet 5.x, Fable) don't get them unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` is set.
- Ctrl+T toggles the list. `CLAUDE_CODE_TASK_LIST_ID` shares a list across sessions.

**Workflows** (https://code.claude.com/docs/en/workflows)
- A JavaScript script with `export const meta = {name, description}`, then `agent()`, `pipeline()`, `parallel()`, `phase()`, `log()` and `args`. `agent()` accepts a JSON `schema`.
- Triggered by the `ultracode` keyword or `/effort ultracode`. `/deep-research` is bundled. Progress shows in `/workflows`.
- Save with `s` to `.claude/workflows/`. Plugins ship workflows in `workflows/`, invoked as `/<plugin>:<name>`.
- Limits: 16 concurrent agents, 1,000 agents per run, 4,096 items per `pipeline`.
- No imports, no direct filesystem access, and `Date.now()` throws, so runs can resume.
- Allow rule: `Workflow(<name>)`.
- `/workflow-authoring` is the bundled skill for editing scripts.
- `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` is new in v2.1.296.

**Routines and scheduling** (https://code.claude.com/docs/en/routines, /scheduled-tasks, /goal)
- Routines (research preview) run in the cloud with a prompt, repos and connectors. Triggers: schedule (minimum hourly), API POST, or GitHub events. Manage them at claude.ai/code/routines or with `/schedule`. Limits: 100 scheduled runs per hour per account; 30 Run-now/API/re-run actions per hour per routine.
- `/loop [interval]` runs in-session and expires after 7 days.
- Desktop scheduled tasks run locally.
- `/goal <condition>` keeps Claude taking turns until a model judges the condition met.

**GitHub and Code Review** (https://code.claude.com/docs/en/code-review)
- Managed Code Review (Team and Enterprise, research preview): a multi-agent review posts inline findings with severity levels, triggered by `@claude review` or `@claude review always`.
- Tune it with a `REVIEW.md` at the repo root (severity, nit caps, skip rules, verification bar). CLAUDE.md violations are flagged as nits.
- Locally, `/code-review [target] [--fix|--comment|--max-findings n]` runs as a background subagent. `/review` is an alias.
- GitHub Actions and GitLab CI are documented separately.

**Output styles** (https://code.claude.com/docs/en/output-styles)
- Built-ins: Default, Proactive, Concise, Explanatory, Learning.
- Custom styles are `.md` files in `~/.claude/output-styles` or `.claude/output-styles`, or in a plugin's `output-styles/`.
- Frontmatter: `name`, `description`, `keep-coding-instructions`, and `force-for-plugin` (plugin styles only).
- Select with `/output-style`. Changes need a restart.

**Context management** (https://code.claude.com/docs/en/context-window, /best-practices)

What survives compaction:

| Content | After compaction |
| :- | :- |
| Project-root CLAUDE.md and unscoped rules | Re-injected from disk |
| Auto memory | Re-injected from disk |
| Plan file | Re-injected from disk |
| Files Claude read or edited | Up to 5 re-read, most recently modified first; files over 5k tokens come back as path references |
| Skill bodies | 5k tokens each, 25k total |
| `SessionStart` hooks with the `compact` matcher | Re-run, output added |

Tools and guidance:
- `/compact <focus>`, `/autocompact 500k`, `/rewind` with "Summarize from/up to here", `/btw` for side questions, `/context`.
- Best practices: give Claude a way to verify its work; explore, then plan, then code; prune CLAUDE.md ("would removing this cause mistakes?"); `/clear` between tasks; delegate research to subagents; add an adversarial review subagent but tell it to flag only real gaps to avoid over-engineering.

## Recent changes that matter (v2.1.250–v2.1.296, August–October 2026)
- Mods (v2.1.287)
- `onFailure: "block"` for hooks (v2.1.295)
- Subagent `autoCompactWindow` (v2.1.296)
- `claude plugin validate` checks MCP entries (v2.1.281) and suggests an install line when the README lacks one
- `claude plugin eval` (v2.1.269)
- `claude plugin configure` and `--config` on install
- `claude plugin install --marketplace`
- `userConfig` `options` (v2.1.271)
- `omitClaudeMd` for agents (v2.1.271)
- Plugin `metadata` field (v2.1.222)
- Directory-listing fields in `plugin.json`
- `/doctor prompt-audit` (v2.1.283)
- Remote Control: model and effort control from devices, artifacts from server mode, Trusted Devices
- Sonnet 5.5 and Haiku 5.5 added as default models
- Agent tool `effort` parameter

## Implications for an engineering-workflow plugin
- Ship guidance as skills, not as a CLAUDE.md in the plugin, because that file isn't loaded.
- Keep `description` plus `when_to_use` under 1,536 characters.
- Use `${CLAUDE_PLUGIN_DATA}` for any state the plugin keeps.
- Plugin agents can't carry hooks or MCP servers; declare those at the plugin level.
- Don't rely on `TaskCreate` existing on new models.
- Plugin-level workflows (`workflows/`) and artifacts are the new ways to handle multi-agent work and output you can read on a phone.
- Bump the version for every user-visible change, or tag `<name>--v<version>` with `claude plugin tag` if you want dependency-range resolution.
