---
adr: 005
title: Engineering replaces knowledge-system and adr-management
status: active
---

# ADR-005: Engineering replaces knowledge-system and adr-management

- **Decision:** The engineering plugin takes over the roles of knowledge-system and adr-management. It takes their ideas and copies no files. The two older plugins are deprecated when engineering is stable.

## Details
- `domain-model` takes the ADR rules from adr-management: the litmus test, living ADRs, and glossary alignment.
- `ship` and its push hook take the reflection step and the knowledge tiers from knowledge-system.
- `verify` can use a second opinion in the style of codex-review. codex-review stays as it is.

## Rejected alternatives
- **Keep both older plugins, and leave ADR and knowledge skills out of engineering:** the plugin is smaller, but you must install three plugins.
- **Keep both older plugins next to their copies in engineering:** two skills answer the same trigger.
