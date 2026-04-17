---
name: create-new
description: Scaffold the folder structure and memory files for a new client or project. Use when onboarding a new client or starting a new project.
argument-hint: <type> <client and/or project name>
---

# New Client / Project Setup

Arguments provided: $ARGUMENTS

The arguments should specify the type and name. Examples:
- `/create-new client Acme Corp` — create a new client
- `/create-new project Internal Dashboard` — create a new B3 project
- `/create-new project Acme Corp/Internal Dashboard` — a new project for client Acme Corp

## Step 1: Read reference
Read `llm-context/memory-system.md` to understand the memory architecture.

## Step 2: Determine type and location
- **Client**: `kunder/{client-name}/` (kebab-case folder name)
- **B3 project**: `b3/projects/{project-name}/` (kebab-case folder name)

Ask the user to confirm the folder name if the name-to-slug conversion is ambiguous.

## Step 3: Create folder structure

Set up the folder structure according to `llm-context/standard-folder-structure.md`

## Step 4: Populate from templates

Use templates from `templates/memory/` to populate:
- `ABOUT.md` — from `templates/memory/ABOUT.md`
- `memory/INDEX.md` — from `templates/memory/INDEX.md`
- `memory/activity-log.md` — from `templates/memory/activity-log.md`

Replace `{Client or Project Name}` in ABOUT.md with the actual name.
Set the date fields to today's date.

Do NOT create a glossary.md yet — that gets created later when there are enough terms.

## Step 5: Gather initial context

Ask the user for initial information to populate ABOUT.md using the askUserQuestions tool:
- What is this client/project about? (Summary)
- Who are the key people involved? (Key People)
- What is the current focus or first priority? (Current Focus)
- Any known constraints or preferences? (Preferences & Constraints)

If the user provides information about specific people, also create the corresponding `memory/people/{name}.md` files using the `templates/memory/person.md` template and add them to INDEX.md.

## Step 6: Confirm setup

List all created files and their locations. Remind the user that:
- ABOUT.md is the entry point for any agent working with this client/project
- `memory/` files are updated as the agent learns more over time
- Meeting notes go in `meetings/`, general notes go in `notes/`
