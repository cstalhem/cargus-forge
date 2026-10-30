---
adr: 005
title: Engineering replaces knowledge-system and adr-management
status: active
---

# ADR-005: Engineering replaces knowledge-system and adr-management

- **Decision:** The engineering plugin takes over the roles of knowledge-system and adr-management. It takes their ideas and copies no files. The two older plugins are deprecated when engineering is stable.

## Details
- `references/domain-model.md` holds only the glossary rules: the format, the gate, and how discuss and execute use it.
- `references/adr.md` holds the ADR rules: the litmus test, the format, when to edit an ADR instead of writing a new one, and how discuss and execute use them. It is a reference that discuss and execute read, not a skill. discuss records each ADR as an `ADR` decision in the issue, execute writes it, and verify grades it.
- ADRs stay living documents: each one states the current decision, and git holds its history.
- Engineering does not hold the knowledge tiers or the reflection step from knowledge-system yet. `reflect`, the skill for the reflection step, is a request in #202.
- adr-management stays until engineering is stable. It and knowledge-system are deprecated together then.
- codex-review stays as it is.

## Rejected alternatives
- **Keep both older plugins, and leave ADR and knowledge skills out of engineering:** the plugin is smaller, but you must install three plugins.
- **Keep both older plugins next to their copies in engineering:** two skills answer the same trigger.
- **An `adr` skill in engineering:** while adr-management is installed, a second skill answers its "create an ADR" trigger.
- **Deprecate adr-management now:** knowledge-system's role (#202) is not covered yet, and the two older plugins are deprecated together.
- **Immutable ADRs that a new ADR supersedes:** a reader follows a chain of ADRs to find the current decision.
- **A path-scoped ADR rule that setup copies into each repo:** the copy drifts from the plugin, whose contract stays in the plugin ([ADR-001](ADR-001-github-is-the-work-state-store.md)).
