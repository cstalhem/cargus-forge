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
