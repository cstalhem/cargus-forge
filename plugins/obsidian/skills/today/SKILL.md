---
description: Create a daily summary for the user
disable-model-invocation: true
---

# Task and instructions

- When asked by the user, close the previous day's note and open a new one for today according to the workflow below.
- The new note should follow the Daily Note template.
- Use the **task-manager** agent for all task operations (syncing, closing, pulling, creating).
- Check `llm-context/memory-system.md` for how the memory system works.
- Ask questions with the askUserQuestions tool to get clarifications when needed.

# Workflow

1. Check today's date and time.
2. **Close the previous day's note:**
   - Using parallel sub-agents, do the following:
     - **task-manager agent**: "Close/sync tasks from yesterday's daily note at {path}. Close completed tasks in Todoist, process any notes/annotations on tasks (closing, moving, updating dates/notes/names/etc.)."
     - **task-manager agent**: "Check the linked meeting files associated with yesterday's daily note at {path} and create any new open tasks found in those files in Todoist."
     - Look for meeting notes for that day and add any that does not already exist to the Meetings table. Link the meeting name in the table to the note.
     - Update client and project memory based on the daily note and any meeting notes from that day:
       1. Follow the writing rules in `llm-context/memory-system.md` when working through the below instructions.
       2. For each client/project referenced in the daily note or its linked meetings, read the relevant ABOUT.md.
       3. Append significant events or decisions to `memory/activity-log.md`.
       4. Update `memory/people/` files if new information about people was captured.
       5. Update ABOUT.md "Current Focus" or "Recent Decisions" if anything shifted.
       6. Create or update `memory/context/` notes for any new substantial topics.
       7. Update `memory/INDEX.md` if new files were created.
3. **Open note for today:**
   - Wait for the sub-agents to complete, then:
     - **task-manager agent**: "Pull tasks for today's daily note. Include overdue, due today, and a couple of undated relevant tasks. Format in Obsidian task format."
     - Check for access to a calendar. If you have it, check what is on the agenda today and include today's meetings in the daily note.
     - Set up the relevant meeting note files according to the meeting note template.

# Other considerations

- Never mention that there are open tasks in the `templates/` directory since these are only for use in templates and not real tasks.
- If there is no immediate note for yesterday, look at the latest available daily note instead, then close that day.
