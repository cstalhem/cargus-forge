---
name: today
description: >
  Close yesterday's daily note and open today's: creates task notes
  from meeting action items, links meeting notes, refreshes client/project
  memory, and sets up today's daily note with calendar and a live task view.
  Use when starting the workday or creating today's daily note.
disable-model-invocation: false
allowed-tools: Read Write Edit Glob Grep Bash Task AskUserQuestion TodoWrite
---

# Task and instructions

- When asked by the user, close the previous day's note and open a new one for today according to the workflow below.
- The new note follows the Daily Note template (`templates/daily-note.md`).
- Use the **task-manager** agent for all task operations. Task rules live in `llm-context/tasks.md`.
- Memory rules live in `llm-context/memory-system.md` (entry point; read the detail files it points to).
- Ask questions with the AskUserQuestion tool when needed.

# Dates

- Today: !`date +%Y-%m-%d`
- Yesterday: !`date -v-1d +%Y-%m-%d`

# Workflow

Before dispatching any sub-agent prompt below, substitute `yesterday_path` and `today_path` with the absolute paths resolved in step 1.

1. **Resolve paths.** Locate yesterday's daily note and today's target path following the daily-note path convention in `llm-context/`. If no note exists for yesterday, use the latest available daily note as `yesterday_path`.
2. **Close the previous day's note** (parallel sub-agents):
   - **task-manager agent**: "Process the daily note at `yesterday_path` and its linked meeting notes per `llm-context/tasks.md`: create task notes from meeting action items and from checkbox lines Calle wrote that are not yet task notes. Do not change the status of existing tasks."
   - Add any meeting notes for that day that are missing from the Meetings table, linking the meeting name to the note.
   - **Update client and project memory** from the daily note and that day's meeting notes:
     1. Read `llm-context/memory-system.md`, then `llm-context/memory/writing.md` and `llm-context/memory/activity-log.md`.
     2. For each client/project referenced, read its ABOUT.md.
     3. Append only what qualifies under "Log these" in `llm-context/memory/activity-log.md`. Never log hours, missing notes, empty days or meta-commentary.
     4. Update people, context notes, ABOUT.md and INDEX.md per the writing rules.
3. **Open today's note:**
   - Wait for the sub-agents to complete.
   - Create today's note from the template. The Tasks section embeds the live TaskNotes view. **Do not copy tasks into the note.**
   - **task-manager agent**: "Suggest follow-ups for today's note at `today_path` per the 'Suggested follow-ups' section in `llm-context/tasks.md`, based on `yesterday_path`." (Max 3 plain bullets, possibly none.)
   - If a calendar is available, add today's meetings to the Meetings table and set up meeting note files from the meeting template. If no calendar is available, leave the table empty without commentary.

# Other considerations

- Never mention open tasks in `templates/`; they are template examples, not real tasks.
- Do not write notes in the daily note about tools being unavailable, missing data or skipped steps.
