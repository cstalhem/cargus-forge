---
description: >
  Todoist and Obsidian task formatting conventions,
  project organization, and sync rules. Referenced
  by the task-manager agent and other skills that
  work with tasks.
---

# Task Conventions

## Project Organization

Tasks are organized into two main projects:
- **Personal**: Personal tasks and individual work
- **B3**: Business-related tasks

Tasks are categorized using **Labels** in Todoist that correspond to client names, project names, and other relevant topics.

## Task Creation Guidelines

1. **Start with strong verbs**: "review," "draft," "deploy," "analyze," "update"
2. **Keep tasks short and actionable**
3. **Prefix tasks for others**: e.g. "Alice: Review the proposal"
4. **Infer due dates** when context allows
5. **Make tasks self-contained**: Every task must be understandable without its Todoist project/label hierarchy for context.
   - Bad: "Review the document"
   - Good: "Review Acme Corp onboarding proposal draft"
   - Bad: "Fix the login bug"
   - Good: "Fix login timeout in Sales Flow dashboard"
   - If a task is inherently unambiguous (e.g., "Book dentist appointment"), no extra context is needed.
   - When extracting tasks from meeting notes, include enough meeting/project context that the task stands alone.

## Todoist Reference Format

Each synced task carries a clickable reference linking back to Todoist:

```
[↗](https://app.todoist.com/app/task/{id})
```

- `{id}` is the alphanumeric Todoist task ID (e.g., `6g23fM8CVFmr8vrC`)
- In Obsidian reading mode this renders as a small clickable arrow -- minimal visual clutter
- A task line **without** a `[↗](...)` suffix is a **new task** that needs to be created in Todoist

**Parsing regex** to extract the task ID from a line:

```
\[↗\]\(https://app\.todoist\.com/app/task/([A-Za-z0-9]+)\)
```

## Obsidian Task Format

### Simple task (no due date)

```markdown
- [ ] Simple and straightforward task [↗](https://app.todoist.com/app/task/6g23fM8CVFmr8vrC)
```

### Task with due date

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

## Context Enrichment

When syncing from Todoist to Obsidian: if a task's content does not already mention its label/project/client, prepend the Todoist label as a prefix.
- E.g. task "Review PR #42" with label "Sales-Flow" becomes "Sales-Flow: Review PR #42"
- Skip the prefix if the task content already contains the label/project name
- This is rendering-time enrichment only -- the Todoist task name stays as-is

## Deduplication

Before inserting a task, scan the target note for existing `[↗]` references with the same task ID. Do not insert duplicates.
