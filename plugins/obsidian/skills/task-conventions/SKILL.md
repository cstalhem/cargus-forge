---
name: task-conventions
description: >
  TaskNotes task conventions for the Obsidian vault: data model,
  creation rules, what may become a task, and suggested follow-ups
  in daily notes. Referenced by the task-manager agent and other
  skills that work with tasks.
user-invocable: false
---

# Task Conventions

The authoritative rules are in the vault at `llm-context/tasks.md`. Read that file and follow it exactly. This skill only summarises the essentials.

- Tasks are TaskNotes notes in `tasks/` (archive: `tasks/archive/`), tagged `task`, filename = title.
- Link client/project via the `projects` property: `[[kunder/{client}/ABOUT]]` or `[[b3/projects/{project}/ABOUT]]`.
- Status values: `none`, `open`, `in-progress`, `done`. Priority: `none`, `low`, `normal`, `high`.
- Create tasks only from meeting action items, Calle's own unconverted checkboxes, or explicit requests. Never invent tasks.
- Closed means done. No verification tasks, no meta tasks about the vault.
- Calle closes tasks. Never change status unless asked. Never delete task notes.
- Daily notes embed a live view. Never copy or carry forward tasks. Suggested follow-ups are max 3 plain bullets.
