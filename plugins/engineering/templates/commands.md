<!-- The template of docs/agents/commands.md. /engineering:setup writes that file once, in one of the two forms below, without these comments. The repo owns the file after that. -->
<!-- Form 1: the repo has commands. One row for each command the user accepted. execute, verify and ship run each row whose task ends with "(pre-PR check)". -->
# Commands

| Task | Command |
|---|---|
| {{task}} | `{{command}}` |
<!-- Form 2: the repo has no build, tests or lint. The second sentence says how a change is checked, or is left out. -->
# Commands

This repo has no build, tests or lint. {{how a change is checked}}
