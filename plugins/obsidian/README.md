# Obsidian Plugin

## About

This plugin defines the command and skill prompts used to automate tasks inside the Obsidian vault, such as generating daily notes or scaffolding new notes with consistent structure.

## Skills


| Skill               | Description                                                                                                                 |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `today`             | Closes yesterday's daily note and opens today's, syncing tasks, meetings, and memory.                                       |
| `new-note`          | Creates a new note from the vault templates.                                                                                |
| `process-meeting`   | Processes a meeting transcript into structured notes with summary, tasks, and decisions, then updates client/project memory. |
| `create-new`        | Scaffolds the folder structure and memory files for a new client or project.                                                |
| `update-memory`     | Updates client or project memory files based on recent interactions, notes, or new information.                             |
| `task-conventions`  | Reference skill: Todoist/Obsidian task formatting and sync rules. Not user-invocable — loaded by other skills and agents.   |

## Agents

| Agent          | Description                                                                                                   |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| `task-manager` | Bridges Todoist and Obsidian — syncs tasks, closes/completes, pulls for daily notes, and creates new tasks.   |


## TODO

- Add more daily note automation, such as tagging rules or automatic links to related notes.
- Expand available skills to cover more common vault workflows.
- Add an "Initiate vault" skill

