---
paths:
  - "plugins/engineering/**"
---

# Engineering build

- When surfaces differ in one tool call, a skill states the shared condition and payload once and branches only on the call.
- A definition shared by several decision kinds is written once for all kinds, never once per kind.
- Skills match a PR's first line only against the formats execute writes (`Sub-issue #<n> of`, `Closes #<n>`).
