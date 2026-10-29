---
adr: 005
title: Engineering replaces knowledge-system and adr-management
status: active
---

# ADR-005: Engineering replaces knowledge-system and adr-management

- **Decision:** The engineering plugin takes over the roles of knowledge-system and adr-management. It takes their ideas and copies no files. The two older plugins are deprecated when engineering is stable.

## Details
- `references/domain-model.md` holds only the glossary rules: the format, the gate, and how discuss and execute use it.
- Engineering does not hold the ADR rules from adr-management yet, nor the knowledge tiers or the reflection step from knowledge-system. `reflect`, the skill for the reflection step, is a request in #202.
- knowledge-system and adr-management stay until engineering holds these.
- codex-review stays as it is.

## Rejected alternatives
- **Keep both older plugins, and leave ADR and knowledge skills out of engineering:** the plugin is smaller, but you must install three plugins.
- **Keep both older plugins next to their copies in engineering:** two skills answer the same trigger.
