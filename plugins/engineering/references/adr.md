# ADRs

An ADR (architecture decision record) states one current decision of a repo and the alternatives it rejected, so that a later reader knows why the code is the way it is and does not propose a rejected alternative again.
## Location
- One file for each decision: `docs/adr/ADR-NNN-<slug>.md`. `NNN` has three digits. The slug is lowercase ASCII, about 40 characters at most, and fixed once the file is committed; only the title inside the file can change.
- A new ADR takes the highest number in `docs/adr/` plus one. A number is never reused.
- `docs/adr/README.md` indexes them, one table row for each ADR: `| [ADR-NNN](<file>) | <title> | <status> | <notes> |`, under the header `| ADR | Title | Status | Notes |`. The Notes cell holds at most `builds on ADR-NNN`. If the file does not exist, create it with a `# Architecture decision records` heading, the line "Each ADR states one current decision. ADRs are living documents, and git holds their history." and the table.

## Litmus test
A decision earns an ADR only when all four are true:
1. **Clear decision:** one assertive sentence states it.
2. **Real trade-off:** at least one real alternative was considered and rejected, with a reason.
3. **Hard to reverse:** changing it later costs something.
4. **Surprising without context:** a later reader would ask why it was done this way.

A decision that fails one stays a decision in its issue only.

## Living documents
- An ADR states the current decision. When a decision is refined or changed, edit its ADR in place. Git holds the history.
- A reversed choice moves to Rejected alternatives, with the reason it was dropped. It is the strongest rejected alternative, because it was tried.
- An ADR has no "amended by" or "superseded by" note, no change marker and no narration, such as "we decided" or "after the discussion". It states its reasons as facts.
- An ADR uses the glossary's terms. A term that it settles or changes gets its own `Term` decision in the same issue, as `domain-model.md` says.

## Edit or new
The question is whether the decision answers the same question as an existing ADR.

| Decision | Action |
|---|---|
| Refines or extends an existing ADR | Edit that ADR in place. |
| Reverses or replaces an existing ADR | Rewrite its decision, and move the old choice to its Rejected alternatives with the reason it was dropped. |
| A new question that passes the litmus test | Write a new ADR. If it narrows what an existing ADR states, edit that ADR too, so that no ADR states something false. |
| The decision area no longer applies | Set `status: deprecated`, keep the file, and add one line that says why. |

## Format
```markdown
---
adr: NNN
title: <title, the same as in the H1>
status: active
---

# ADR-NNN: <title>

- **Decision:** <the decision in one or two sentences>
- **Builds on:** [ADR-NNN](<file>)
- **Source:** [#<n>](<issue URL>)

## Details
- <what the decision means in practice>

## Rejected alternatives
- **<alternative>:** <why it was rejected>

## Consequences
- <what follows from the decision, good and bad>
```

- `status` is `active` or `deprecated`.
- The floor is the frontmatter, the Decision and one rejected alternative. Add `Builds on`, `Source`, Details and Consequences only when the decision needs them.
- An ADR stays readable in about five minutes: about 100 lines at most. Detail beyond that belongs in the issue and the code.
