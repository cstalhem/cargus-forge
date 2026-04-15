---
name: task-conventions
description: >
  Todoist and Obsidian task formatting conventions,
  project organization, and sync rules. Referenced
  by the task-manager agent and other skills that
  work with tasks.
---

# Task Conventions

You are reading this skill because you are syncing tasks between Todoist and Obsidian, creating new tasks, or resolving annotations the user left on a daily note. Follow the rules below exactly. Todoist is the source of truth for task state; the daily note is an editable view.

## Project Organization

Tasks live in two top-level Todoist projects:

- **Personal**: personal tasks and individual work
- **B3**: business-related tasks

Categorisation within those projects uses **Todoist labels**, which map to client names, project names, or topical areas. When you need to pick a project or label during task creation, use `find-projects` and `find-labels` to resolve names; never guess an ID.

## Creating Tasks in Todoist

When you create a task (either from a new note line without a `[↗]` link or from meeting notes), follow these rules:

1. Start the title with a strong verb: "review", "draft", "deploy", "analyze", "update".
2. Keep titles short and actionable.
3. If the task is for someone else, prefix with their name and a colon: `Alice: Review the proposal`.
4. Infer a due date when the source material gives you one.
5. Make the title self-contained. The title must be understandable without the Todoist project or label hierarchy, because it is rendered standalone in daily notes.
   - Reject: "Review the document"
   - Accept: "Review Acme Corp onboarding proposal draft"
   - Reject: "Fix the login bug"
   - Accept: "Fix login timeout in Sales Flow dashboard"
   - Exception: inherently unambiguous personal tasks like "Book dentist appointment" need no extra context.
6. When extracting tasks from a meeting note, include enough meeting or project context that the task stands alone.

After creating the task, write the returned `[↗]` link back to the source line.

## Todoist Reference Format

Every synced task carries a clickable reference back to Todoist:

```
[↗](https://app.todoist.com/app/task/{id})
```

`{id}` is the alphanumeric Todoist task ID (for example, `6g23fM8CVFmr8vrC`). In Obsidian reading mode it renders as a small arrow.

A task line **without** a `[↗](...)` suffix is a new task you must create in Todoist.

To extract a task ID from a line, use this regex:

```
\[↗\]\(https://app\.todoist\.com/app/task/([A-Za-z0-9]+)\)
```

## Obsidian Task Format

### Simple task (no due date)

```markdown
- [ ] Simple and straightforward task [↗](https://app.todoist.com/app/task/6g23fM8CVFmr8vrC)
```

### Task with due date

The leading `(@YYYY-MM-DD)` prefix is the authoritative due date for sync purposes:

```markdown
- [ ] (@2026-03-10) Task with a deadline [↗](https://app.todoist.com/app/task/6g2vQVhpRg533Qcj)
```

### Task for someone else

```markdown
- [ ] Alice: A task Alice should do [↗](https://app.todoist.com/app/task/6g68gR6vhJ3pr48j)
```

### New task (not yet in Todoist)

```markdown
- [ ] New task without Todoist link yet
```

### Checkbox states

Read the checkbox state as the primary signal for completion:

| Syntax  | Meaning   | Action on close                                                                                                                               |
| :------ | :-------- | :-------------------------------------------------------------------------------------------------------------------------------------------- |
| `- [ ]` | Open      | No action. The task stays open in Todoist and will reappear in tomorrow's pull if it still matches the daily-note filter                      |
| `- [x]` | Completed | Call `complete-tasks` on the linked Todoist ID                                                                                                |
| `- [-]` | Cancelled | Call `complete-tasks` on the linked Todoist ID. The `[-]` is for the user's own record; Todoist does not distinguish cancelled from completed |

Never delete a task automatically. If the user explicitly asks to delete, confirm via AskUserQuestion before calling `delete-object`.

## Annotation Bullets

The user expresses changes to a task by adding one or more indented bullets directly below the task line. Treat each sub-bullet as a plain-language instruction for the parent task.

Example:

```markdown
- [ ] (@2026-04-13) Följa upp med Elina om ramavtalsmärkning [↗](.../6gGj73M9hxwQ57vC)
  - Update due date to Monday
  - Add label urgent
  - Reassign to Alice
```

Process each sub-bullet as follows:

1. Determine whether it is an instruction or a note. A bullet prefixed with `note:` is context for the user and must be ignored. Anything else is an instruction.
2. Interpret the instruction and map it to a Todoist MCP call (`update-tasks`, `reschedule-tasks`, `manage-assignments`, etc.).
3. Resolve relative dates against the **daily note's own date** (read it from the filename or the `# YYYY-MM-DD` heading), not against today's system date. Default to the nearest future occurrence: "Monday" on a Wednesday note means the following Monday. Use "last Monday" or similar for explicit past references.
4. Resolve names (people, labels, projects) by looking them up. If zero or multiple matches, stop and ask via AskUserQuestion before writing.
5. After applying the instruction, rewrite the sub-bullet by marking it `- [x]` so it does not re-fire on a later close. Do not delete the line; the completed marker preserves an audit trail.

Example after processing (daily note was for 2026-04-15):

```markdown
- [ ] (@2026-04-20) Följa upp med Elina om ramavtalsmärkning [↗](.../6gGj73M9hxwQ57vC)
  - [x] Update due date to Monday
```

Unrecognised or ambiguous instructions: stop, do not write to Todoist, and ask the user via AskUserQuestion. It is better to ask than to guess.

Notes that should not be parsed as instructions:

```markdown
- [ ] Sales-Flow: Review Q2 features [↗](...)
  - note: waiting on input from Joakim before I can close this
```

## Sync Behaviour

When closing a daily note, process each task line in this order. Skip later steps for a line as soon as one step is decisive.

1. No `[↗]` link on the line? Create the task in Todoist per "Creating Tasks in Todoist", then write the returned `[↗]` link back to the line. Apply any sub-bullets afterwards.
2. Checkbox is `[x]` or `[-]`? Call `complete-tasks`. Skip the remaining diff steps on this line. Still process sub-bullets marked as instructions, in case the user wants a label or assignee change captured before close.
3. Title text (between the checkbox and the `[↗]` link, excluding the `(@...)` prefix) differs from the Todoist task content? Call `update-tasks` with the new title.
4. `(@YYYY-MM-DD)` differs from the Todoist `dueDate`? Call `reschedule-tasks`.
5. Indented sub-bullets are present? Process them per "Annotation Bullets", and mark each applied bullet `[x]`.

Never modify the daily note file during a close beyond:

- writing back `[↗]` links for newly created tasks, and
- marking applied annotation sub-bullets as `[x]`.

All other state lives in Todoist.

## Context Enrichment (Todoist → Obsidian)

When you pull tasks from Todoist into a daily note or any other Obsidian view: if the Todoist title does not already mention the task's label or project, prepend the label as a prefix so the rendered line is self-contained.

- Todoist task "Review PR #42" with label "Sales-Flow" renders as: `Sales-Flow: Review PR #42`
- Skip the prefix if the title already contains the label or project name.
- This is render-time enrichment only. Do not modify the Todoist task name.

## Deduplication

Before inserting a new task line into a note, scan the target note for existing `[↗]` references. Never insert a second line for a task ID that already appears in the note.

Before creating a new task in Todoist from a note line without `[↗]`, search Todoist via `find-tasks` for an existing task with the same or near-identical title in the likely project. If a plausible match exists, ask the user via AskUserQuestion whether to link to it rather than creating a duplicate.
