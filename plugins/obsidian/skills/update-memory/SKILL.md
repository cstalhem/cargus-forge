---
name: update-memory
description: Update client or project memory files based on recent interactions, notes, or new information. Use when memory needs updating outside of meeting processing or daily note workflows.
---

# Update Memory

Arguments provided: $ARGUMENTS

The arguments should indicate the client or project to update, and optionally what information to incorporate. Examples:
- `/update-memory acme-corp` — review recent notes and update memory
- `/update-memory acme-corp based on today's discussions` — incorporate specific context

Ask questions with the AskUserQuestion tool to get clarifications when needed.

Read the memory system instructions before continuing.

## Step 1: Read the memory system reference
Read `llm-context/memory-system.md` to understand the full memory architecture and writing rules.

## Step 2: Identify scope
Determine which client or project to update from the arguments:
- Client: look in `kunder/{client-name}/`
- B3 project: look in `b3/projects/{project-name}/`
- B3 general: look in `b3/`

## Step 3: Read current state
1. Read `ABOUT.md` for the identified client/project.
2. Read `memory/INDEX.md` to understand what context already exists.

## Step 4: Identify new information
Depending on the arguments, look for new information in:
- Recent daily notes (last 1-3 days) that reference this client/project
- Recent meeting notes in the client/project's `meetings/` folder
- Information provided directly in the arguments

## Step 5: Update memory files
Apply updates following the writing protocol in the memory system reference:
1. **People**: Create or update `memory/people/{name}.md` files.
2. **Activity log**: Append decisions and events to `memory/activity-log.md`.
3. **Context notes**: Create or update `memory/context/{topic}.md` for new topics.
4. **ABOUT.md**: Update current focus, recent decisions, key people, or constraints.
5. **Glossary**: Add new terms to `memory/glossary.md` or ABOUT.md's key terms section.
6. **INDEX.md**: Update if any new files were created.

## Step 6: Report changes

After updating, briefly summarise what was changed:
- Which files were created or updated
- Key information that was added
- Anything that seemed unclear or worth the user reviewing
