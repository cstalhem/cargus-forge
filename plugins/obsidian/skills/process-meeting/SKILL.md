---
name: process-meeting
description: Process Obsidian meeting transcripts into structured meeting notes following vault conventions, then update project/client memory.
argument-hint: <transcript-file> <meeting-note-file>
context: fork
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit
---

# Process Meeting Transcript

Arguments provided: $ARGUMENTS

## Step 1: Resolve file paths

The arguments may be relative paths or @ mentions. First, resolve them to absolute paths from the current working directory using `pwd`.

- Argument 1 (transcript): the source transcript file
- Argument 2 (meeting note): the target output file

## Step 2: Process the transcript (REQUIRED)

**You MUST run this script to get the transcript content. Do NOT use Read on the transcript file.**

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/process-meeting/scripts/process-transcript-outline.sh" "/absolute/path/to/transcript"
```

Replace `/absolute/path/to/transcript` with the resolved absolute path from Step 1.

Capture the stdout output — this is your source material.

## Step 3: Read reference files

Read the vault's meeting template, tagging conventions, and note-taking conventions from `llm-context/`.

## Step 4: Create the meeting note

Transform the script output into a structured meeting note:

- Follow meeting template section order exactly
- Capture action items with owners and due dates
- Update front matter and tags
- Separate on-topic from off-topic discussion
- Use short, scannable bullet points
- Write notes in the same language as was spoken in the meeting

## Step 5: Write output

- Write or merge the result to the resolved absolute path of argument 2.
- Create the file if it doesn't exist.
- Check for a daily note with the same date as the meeting transcript. If one exists, link the meeting name in the meetings table.

## Step 6: Update memory

After creating the meeting note, update the relevant client/project memory. Read the memory system reference in `llm-context/memory-system.md` for full details.

1. **Determine scope**: Infer the client or project from the meeting note's front matter (`client:`, `project:`) or from the file path.
2. **Read ABOUT.md** for the relevant client/project to understand current state.
3. **Update memory files** based on what was discussed:
   - **People**: For each participant, check if a `memory/people/{name}.md` file exists. Create or update as needed with any new information about their role, opinions, or preferences.
   - **Decisions**: Append any decisions made to `memory/activity-log.md`.
   - **Context**: If a substantial new topic was discussed (architecture, process, integration, etc.), check if a relevant `context/` note exists. Update it or create a new one.
   - **ABOUT.md**: If the meeting shifted project focus, introduced new key people, or changed constraints, update ABOUT.md accordingly.
4. **Update INDEX.md** if any new files were created in `context/` or `people/`.
5. Follow all writing rules from the memory system reference — check line counts, keep notes atomic, use templates from `templates/memory/`.
