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
5. **Make tasks self-contained**: Every task must be understandable on its own, without needing its Todoist project or label hierarchy for context. Include the specific deliverable, system, or artifact the task relates to.
   - Bad: "Lägga in rubriker på kostnadsgrafer och formatera datum på svenska"
   - Good: "Formatera kostnadsgrafer i Q1-presentationen for Sales Flow -- rubriker och svenska datum"
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

When writing tasks in Obsidian, follow these formats:

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

## Syncing Workflow

### From Todoist to Obsidian

1. Query Todoist MCP for tasks using available filters (due date, project, labels)
2. **Context enrichment**: If a task's content does not already mention its label/project/client, prepend the Todoist label as a prefix (e.g., task "Review PR #42" with label "Sales-Flow" becomes "Sales-Flow: Review PR #42"). Skip the prefix if the task content already contains the label/project name. This is rendering-time enrichment only -- the Todoist task name stays as-is.
3. Transform task data into Obsidian format:
   - Include due dates in `(@YYYY-MM-DD)` format when present
   - Prefix with person's name if task is assigned to someone else
   - Append Todoist reference: `[↗](https://app.todoist.com/app/task/{id})`
4. **Dedup**: Before inserting a task, scan the target note for existing `[↗]` references with the same task ID. Do not insert duplicates.

### From Obsidian to Todoist

1. Parse task format from Obsidian notes
2. Extract due dates from `(@YYYY-MM-DD)` pattern
3. Identify task owner from name prefix
4. **New tasks** (no `[↗]` reference): Create in Todoist with appropriate project, labels, due dates, and content following the task creation guidelines. After creation, append `[↗](https://app.todoist.com/app/task/{id})` to the task line in Obsidian.
5. **Existing tasks** (have `[↗]` reference): Extract the task ID from the URL and update the corresponding Todoist task as needed.
6. Do not create duplicate tasks -- always check for existing references first.
