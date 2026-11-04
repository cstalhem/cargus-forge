# Repo rules

How a repo's rules and the skills behind them are defined, judged and written. The repo may have none of `.claude/rules/`, `.claude/skills/` or a glossary: where one is absent, the sentence that names it does not apply, and the test uses the repo's own files and plain words instead.

## What a rule is
- A rule is one line in a file under `.claude/rules/`, with no code, that says what code in this repo does or never does. Claude Code loads each rule file into every session, or, when the file has `paths:` frontmatter, when a file that matches one of its paths is read.
- A rule has no source tag. It may end with a short reason clause when the reason tells a session when the rule bends; a line that needs more than that fails the rule test or gets a backing skill.
- A rule file has `paths:` frontmatter when every rule in the file applies to files under one folder, and none when any of its rules applies elsewhere.
- A rule that has a backing skill ends with `(see skill: <name>)`, with `<name>` the skill's folder name under `.claude/skills/`.

## Rule test
A line can be a rule only when all of these hold:
1. A session that never saw the PR that added it can say, from the line, the repo's glossary and the repo alone, when it applies and what it requires or forbids.
2. The line states what the code does not show: a convention, a constraint or a trap that reading the code does not reveal.
3. It is a guideline rather than something that must hold every time; what must hold every time, and one command can check, is a check.
4. It says what nothing else in the repo already says: no other rule, no doc such as CLAUDE.md, AGENTS.md or CONTRIBUTING.md, no linter or formatter config, and no pre-PR check.

## When a rule goes
A rule goes, or is reworded, when one of these is true:
- it fails the rule test;
- a pre-PR check, a linter or formatter config, or another rule covers it;
- it names a thing that no longer exists: a file, command, term or tool;
- it contradicts another rule.

## Backing skill
- A rule gets a backing skill only when following it right takes steps or an example that its line cannot hold. A line that passes the rule test needs none, because each skill that Claude can invoke costs context on every turn.
- A backing skill is `.claude/skills/<name>/SKILL.md`. Its frontmatter has:
  - `description`: what the skill holds, in the third person, with the key terms of its area, so a search for those terms finds it;
  - `when_to_use`: the situation the rule applies in, so the skill loads when that situation arises.
- Its body holds the steps and wrong/right examples, and says what to do rather than why. It never restates a rule line.
- Each rule that the skill backs ends with `(see skill: <name>)`, and the name must match a skill in `.claude/skills/`.
