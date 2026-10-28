# Domain model

The glossary is the one list of domain terms that developers and agents share. The skill that reads this file loads `docs/glossary.md` into its own body. Check terms against that text, except where that skill's section says to read the file again. The format and the gate apply in every skill that reads this file. Then follow the section for that skill.

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
- A name that the work makes up for a new thing, such as a new section, file, step or state, is specific to the project, so it passes the gate.
- Edit an entry in place. Do not add a second entry for the same term.
- A rename moves the old word into the new entry's `_Avoid_` line.
- A curation pass may not make the file longer.

## In discuss
discuss never writes the glossary. A term reaches it only as a `Term` decision in the issue, which execute's PR writes, so the "yes" to the draft and the PR review are the human approvals.

- **Find the terms.** Check each domain word in the request, in the user's answers and in the code that the request touches against the glossary.
- **Raise a term question** for each word that passes the gate and is one of these:
  - a domain term that the glossary lacks;
  - a word used in a sense that differs from its entry;
  - a word that the glossary lists under `_Avoid_`. Recommend the entry's term instead.
- **Sharpen fuzzy words.** If a word could name two things, ask which one it names, and recommend a term for each.
- **Check against the code.** If the code names the thing by another word, or does not work the way the user says, state what the code shows in the question.
- **Ask it as a numbered question** in the round, with the other questions. Say which of the cases above it is. Write out the full entry that you recommend, in the format above: the term, the definition and the `_Avoid_` words. Do this also when the entry already exists, so the user sees what the word means. Write `_Avoid_: none` when no other word is in use, and the entry then has no `_Avoid_` line.
- **Record each accepted term** in the draft's `## Decisions` section as `D<n> · Term: **<Term>**: <definition> _Avoid_: <words>`, the shape in `formats.md`. Leave out ` _Avoid_: <words>` when the entry has no `_Avoid_` line. For a changed entry, the decision holds the whole new entry, and a rename puts the old word into `_Avoid_`. An answer that keeps an entry as it is adds no decision.
- Change no file in the repo, `docs/glossary.md` included.

## In execute
execute writes the glossary in the issue's PR. The PR review is the human approval of each entry that no `Term` decision holds. execute loads the glossary before its step 2, which can switch or update the branch, so read `docs/glossary.md` on the issue branch, if it exists, before you judge that no entry covers a name, and before you write an entry.

- **Write each `Term` decision**, the issue's own and each one it points to as `#<umbrella> D<n>`. Add its entry to `docs/glossary.md`, or edit the entry for that term in place. The entry is the decision's text: `**<Term>**: <definition>`, with the decision's `_Avoid_` words on a line under it. If the file does not exist, create it with the `# Glossary` heading.
- **Add a missing term.** If the code needs a new domain name that passes the gate, and no `Term` decision and no entry covers it, add an entry for it. This is deviation rule 6.
- **Record a rename.** If the work renames a domain name, edit its entry in place, or add one if it has none and passes the gate. The entry gets the new term, and the old word goes into its `_Avoid_` line. Unless a `Term` decision holds the rename, this is deviation rule 6.
- **Use the terms.** Name new code and doc text with the glossary's terms, and not with a word that it lists under `_Avoid_`.
- **Check each entry** against the format and the gate before you commit it. If a `Term` decision does not fit them, stop and ask. Do not change the decision, because it is the user's.
- Put a new entry at the end of the file. Commit each entry with the code that uses its term.
- **Name it in the PR.** Under `## What it delivers`, list `docs/glossary.md` with each entry that the PR adds or edits. Under `## Deviations`, name each entry from deviation rule 6. If the issue's `## Files` does not list `docs/glossary.md`, name the file under `## Deviations` too.
