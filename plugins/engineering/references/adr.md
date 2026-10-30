# ADRs

An ADR (architecture decision record) states one current decision of a repo and the alternatives it rejected, so that a later reader knows why the code is the way it is and does not propose a rejected alternative again. The skill that reads this file follows every section up to `In discuss`, then the section for that skill.

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

## In discuss
discuss writes no ADR. An ADR reaches `docs/adr/` only as an `ADR` decision in the issue, which execute's PR writes, so the "yes" to the draft and the PR review are the human approvals.

- **Read the ADRs.** Read `docs/adr/`, if it exists, so that you know each current decision.
- **Raise an ADR question** for each decision in the rounds that is one of these:
  - a decision that passes the litmus test;
  - a decision that changes what an existing ADR states. It gets an `ADR` decision that edits that ADR, so that no ADR states something false after the PR.
- **Ask it as a numbered question** in the round, with the other questions. Say which case it is, and write out the full `ADR` decision that you recommend.
- **Record each accepted ADR** in the draft's `## Decisions` section as an `ADR` decision, the shape in `formats.md`. Its rejected alternatives are the ones that the rounds rejected, each with its reason, because execute sees only the issue.
- **List its files.** An issue with an `ADR` decision lists the ADR's file under `## Files`, as `docs/adr/ADR-NNN-<slug>.md` for a new ADR, and `docs/adr/README.md`.

## In execute
- **Write each `ADR` decision:** the issue's own, and each `#<umbrella> D<n>` line in its `## Decisions` whose decision in the umbrella is an `ADR` decision. Read `docs/adr/` on the issue branch first.
- **A new ADR:** number it as `Location` says, write it in the format above, and add its row to `docs/adr/README.md`.
- **An existing ADR:** edit it as `Edit or new` says, and update its index row if its title or status changed.
- **Fill it from the issue.** The Decision holds the decision's sentence, and Rejected alternatives holds each of its rejected alternatives with its reason. Write Details and Consequences from the issue's other decisions and scenarios, only where the decision needs them.
- **Check each ADR** against the format and the length before you commit it. If an `ADR` decision does not fit them, stop and ask. Do not change the decision, because it is the user's.
- **A change that makes an ADR false** and that no `ADR` decision covers is a change to the architecture: deviation rule 4, so stop and ask.
- Commit each ADR with the code that it records.
- **Name it in the PR.** Under `## What it delivers`, name each ADR that the PR adds or edits, with the decision it serves.
