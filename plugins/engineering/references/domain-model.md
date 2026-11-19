# Domain model

The glossary is the one list of domain terms that developers and agents share. The skill that reads this file loads `docs/glossary.md` into its own body. Check terms against that text, except where that skill says to read the file again. The format and the gate apply in every skill that reads this file.

## Format
- The file starts with a `# Glossary` heading. Then comes one entry per term: `**<Term>**: <definition>`, with an optional `_Avoid_: <words>` line under it. A blank line separates entries.
- The definition is one or two sentences. It says what the thing is, it can replace the term in a sentence, and it does not define the term by the term itself.
- An entry has no status, history, code or "not to be confused with" field. A contrast that a reader needs goes into the definition.
- `_Avoid_` lists the words that people use for the same thing but that the project does not use.
- The file gets one section per context only once a homonym appears: one word with two meanings in two parts of the project.

Example:
```markdown
**Sub-issue**: An issue under an umbrella issue; its PR goes into the feature branch.
_Avoid_: child issue, ticket
```

## Gate
- A term goes in only if it is specific to the project and an agent would get it wrong without the entry. A word in its plain meaning, or a general programming word, stays out.
- A name that the work makes up for a new thing, such as a new section, file, step or state, is specific to the project, but it passes the gate only when more than one skill, script or doc reads or writes it.
- Edit an entry in place. Do not add a second entry for the same term.
- A rename moves the old word into the new entry's `_Avoid_` line.
- A curation pass may not make the file longer.
