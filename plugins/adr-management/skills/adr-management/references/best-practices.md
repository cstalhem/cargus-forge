# ADR Best Practices — Reference

Detailed best practices for Architecture Decision Records, derived from industry guidance
(AWS, Google Cloud, Microsoft Azure, Martin Fowler) and adapted for a living-document model.

## Sources

- [AWS — Master ADRs: Best Practices](https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/)
- [AWS — ADR Process](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html)
- [Google Cloud — Architecture Decision Records Overview](https://cloud.google.com/architecture/architecture-decision-records)
- [Microsoft Azure — Maintain an ADR](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record)
- [Martin Fowler — Architecture Decision Record](https://martinfowler.com/bliki/ArchitectureDecisionRecord.html)
- [TechTarget — Best Practices for ADRs](https://www.techtarget.com/searchapparchitecture/tip/4-best-practices-for-creating-architecture-decision-records)
- [ADR GitHub Organization](https://adr.github.io/)
- [Joel Parker Henderson — ADR Repository](https://github.com/joelparkerhenderson/architecture-decision-record)
- [Matt Pocock — grill-with-docs skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs) (the four-part litmus test, the "what qualifies" list, and the optional-sections floor are adapted from its ADR format)

## When to Create an ADR

Create an ADR when:
- A technical challenge has no existing basis for a decision (no standard, no prior ADR).
- Two or more valid approaches exist and the choice has lasting consequences.
- The decision affects system architecture, performance, security, or maintainability.
- Someone reviewing the codebase later would wonder "why was it done this way?"

### What typically qualifies

- **Architectural shape.** The data model's backbone, the deployment topology, the
  authorization boundary ("one events table", "main is production", "the trust boundary
  is enforced at the database").
- **Technology choices that carry lock-in.** Database, auth provider, deployment target —
  not every library, just the ones that would take weeks to swap out.
- **Boundary and scope decisions.** What owns which data, and the explicit no's
  ("preview environments share the production database", "no i18n framework") — the no's
  are as valuable as the yes-es.
- **Deliberate deviations from the obvious path.** Anything where a reasonable reader
  would assume the opposite; the record stops a later change from "fixing" something
  that was deliberate.
- **Constraints not visible in the code.** Plan limits, account allowances, compliance,
  device or interaction constraints that shaped a choice.
- **Rejected alternatives where the rejection is non-obvious.** Otherwise the alternative
  gets proposed again in six months.

## When to Skip an ADR

Skip an ADR when:
- The decision is not architectural (implementation detail, configuration value).
- It is minimal-risk, self-contained, or limited in scope/time/cost.
- It is already covered by an existing ADR, standard, or documentation.
- It is temporary (workaround, proof of concept, experiment).
- There are no meaningful rejected alternatives — the decision follows naturally from
  existing ADRs or the use case.

## The Litmus Test

A decision earns an ADR when all four hold:
1. **Clear decision** — it can be stated in one assertive sentence.
2. **Real trade-off** — at least one genuine alternative was considered and discarded,
   with rationale.
3. **Hard to reverse** — the cost of changing the choice later is meaningful.
4. **Surprising without context** — a future reader would wonder "why was it done
   this way?"

If a decision is easy to reverse, skip the record — you'll just reverse it. If it isn't
surprising, nobody will wonder why. If there was no real alternative, there is nothing
to record beyond "the obvious thing was done" — that is an implementation detail that
belongs in a design document, not an ADR.

## Living Documents vs the Immutable Model

Classical ADR guidance (AWS, Google Cloud, Azure, the ADR organisation) treats records
as **immutable**: changes are appended, amended by a new record, or superseded by a
replacement, and the record set doubles as an audit trail of who knew what when.

This skill defaults to a different model: **ADRs are living documents.** Each ADR owns one
decision area and its body always states the current decision. The reasons:

- **Git history already provides provenance.** Version control over the decisions
  directory records what any ADR said on any date and why it changed — the audit trail
  the immutable model maintains by hand is captured automatically.
- **Immutability optimises for provenance at the cost of navigability.** Readers must
  chase "amended by" chains across files to learn what is currently true, and every new
  decision forces back-link bookkeeping edits in the records it touches.
- **The one thing immutability protects that git surfaces poorly** — *why an abandoned
  approach was abandoned* — is preserved explicitly instead: a reversed decision moves
  into the ADR's Rejected alternatives section with the reason it lost.

### When to prefer the immutable model instead

The living-document model fits teams that trust git history as the audit trail and value
"what is true now" over "what was true when". Prefer the classical immutable model when:

- **Compliance or regulatory requirements** mandate an append-only, tamper-evident record
  of decisions and their timing.
- **The decision log is read outside version control** (exported to a wiki, shared with
  auditors or stakeholders who never see git), so git history is not an accessible trail.
- **A large or distributed org** relies on stable, citable record IDs whose content must
  not shift under existing references.

If any of these apply, keep records immutable: supersede with a new record and link
forward, rather than editing in place.

## Handling Changes to Existing ADRs

The decisive question: **does the change answer the same question an existing ADR
answers?** Same question → edit that ADR. New question → new ADR.

### Edit in place (refinement, extension, new info)
- Edit the ADR body so it states the current decision as fact.
- Remove nothing from Rejected alternatives; extend Consequences as needed.
- No change markers, datestamps, or "updated because" narration — git is the changelog.

### Rewrite (reversal or replacement)
- Rewrite the decision text to the new choice.
- Move the abandoned approach into Rejected alternatives, stated factually with the
  reason it was dropped ("initially built this way; replaced because …").

### New ADR (genuinely new question)
- Create the new record as usual.
- If the new decision narrows or changes what an existing ADR states, edit that ADR's
  body to remain currently true, linking to the new ADR for the rationale. Never leave
  a record asserting something another decision has made false.

### Deprecate (decision area gone)
- Set `status: deprecated` and reduce the body to the decision heading plus one line on
  why the area no longer exists. Keep the file: numbers are never reused, and references
  from code, migrations, and other documents must not break.

### Decision table

| Scenario                                                    | Action                                                                                  |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| New info, refinement, or extension of an existing decision  | Edit the ADR in place so it states the current decision                                 |
| Decision reversed or replaced                               | Rewrite the ADR; move the old approach to Rejected alternatives with why it was dropped |
| New question with its own alternatives (passes litmus test) | New ADR; edit any existing ADR the new decision narrows                                 |
| Decision area no longer relevant                            | Set `status: deprecated`; keep the file with one line saying why                        |

## Scope and Length Guidelines

- **One ADR = one decision area.** If multiple decisions are tightly coupled (same
  discussion, same use case), they may share an ADR, but each should be clearly
  identifiable.
- **Readable in ~5 minutes.** Target 20-80 lines for most ADRs. Complex cross-cutting
  decisions may reach 80-100 lines.
- **Sections are optional; disclosure is proportional to decision weight.** The floor is
  the frontmatter, the Decision bullet, and a one-line rejected alternative. Context and
  Consequences sections are added only when they earn their place — a simple choice is
  complete at a few lines.
- **Keep records assertive, on-topic, and factual.** ADRs are not design guides. Link to
  companion design documents for detailed reasoning, walkthroughs, and edge cases.
- **No conversational artifacts.** Records read as current fact statements; rationale is
  stated inline as fact, never as discussion residue ("we decided", "as discussed",
  "this changes what ADR-N said").
- **Companion design documents** live in `docs/designs/`. Reference them from the ADR:
  "See `docs/designs/feature-name.md` for detailed design discussion."

## Length Reference

| Category               | Typical length | Notes                                          |
|------------------------|----------------|------------------------------------------------|
| Simple choice          | 4-15 lines     | Frontmatter + Decision + one rejected option   |
| Moderate architecture  | 20-45 lines    | Add Context and Consequences sections          |
| Complex cross-cutting  | 60-100 lines   | Link out to a companion design document        |

ADRs exceeding ~100 lines should be reviewed for content that belongs in a design document.

## ADR Format

ADRs are stored as one file per decision under the decisions directory (default
`docs/adr/`), with a `README.md` index in that directory. Each ADR follows this format:

```markdown
---
adr: NNN
title: Title (matches the H1 below)
status: active                  # active | deprecated
---

# ADR-NNN: Title

- **Decision:** One-sentence summary of what was decided.
- **Builds on:** (if applicable) Link to the ADR(s) this decision rests on.
- **Design notes:** (if applicable) Link to companion design document.

### Section headings as needed
- Rationale, alternatives considered, consequences, schema changes, deferred items, etc.
```

Cross-references are plain links in the body ("Builds on", or inline where a fact is
established by another ADR). They are one-directional and informational — no back-link
bookkeeping. The `README.md` index lists all ADRs in one table, with deprecated records
marked in place.

## Design Documents vs ADRs

| Aspect         | ADR                                    | Design Document                         |
|----------------|----------------------------------------|-----------------------------------------|
| Purpose        | Record what was decided and why        | Capture how to implement and edge cases |
| Audience       | Anyone wondering "why this way?"       | Someone about to implement the feature  |
| Content        | Decision, alternatives, consequences   | Walkthroughs, mappings, scenarios       |
| Length         | 20-100 lines                           | Unlimited                               |
| Mutability     | Living — always the current decision   | Living — updated as implementation evolves |
| Location       | `docs/adr/ADR-NNN-*.md`                | `docs/designs/`                         |
