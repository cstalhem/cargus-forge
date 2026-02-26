---
description: Manage and find tasks using the Todoist MCP. Use when working with tasks, todos, action items, or when syncing tasks between Obsidian and Todoist.
---

# Task Management with Todoist

## Source of Truth

The Todoist MCP is the single source of truth for task organization and status. Always sync task changes to and from Todoist to maintain consistency.

## Project Organization

Tasks are organized into two main projects:

- **Personal**: Personal tasks and individual work
- **B3**: Business-related tasks

Tasks are categorized using **Labels** in Todoist that correspond to:

- Client names
- Project names
- Other relevant topics

## Task Creation Guidelines

When creating or updating tasks:

1. **Start with strong verbs**: Use action-oriented verbs like "review," "draft," "deploy," "analyze," "update"
2. **Keep tasks short and actionable**: Tasks should be concise and clearly describe what needs to be done
3. **Prefix tasks for others**: If a task is for someone other than your user, prefix it with their name (e.g., "Alice: Review the proposal")
4. **Infer due dates**: When a due date is not explicitly stated but can be inferred from context, set an appropriate due date

## Obsidian Task Format

When writing tasks in Obsidian, follow these formats:

### Simple task (no due date)

```markdown
- [ ] Simple and straightforward task [#TodoistTaskId]
```

### Task with due date

```markdown
- [ ] (@YYYY-MM-DD) Task with a deadline [#TodoistTaskId]
```

### Task for someone else

```markdown
- [ ] Name: A task Name should do [#TodoistTaskId]
```

## Syncing Workflow

### From Todoist to Obsidian

1. Query Todoist MCP for tasks using available filters (due date, project, labels)
2. Transform task data into Obsidian format
3. Include due dates in `(@YYYY-MM-DD)` format when present
4. Prefix with person's name if task is assigned to someone else

### From Obsidian to Todoist

1. Parse task format from Obsidian notes
2. Extract due dates from `(@YYYY-MM-DD)` pattern
3. Identify task owner from name prefix
4. Create or update tasks in Todoist with appropriate:
   - Project assignment (Personal or B3)
   - Labels based on context
   - Due dates when specified or inferred
   - Task content following the strong verb convention
5. Do not create duplicate tasks
