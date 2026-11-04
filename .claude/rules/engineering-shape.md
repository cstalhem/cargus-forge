---
paths:
  - "plugins/engineering/**"
---

# Engineering shape

- A reference file never repeats a line from references/rules.md, because every skill already injects rules.md.
- A skill never points at another skill's step; shared GitHub write commands live in references/rules.md.
- A skill's test never re-checks what scripts/check-descriptions.sh or scripts/validate-plugins.sh already checks.
- A skill never restates a format that it loads from references/formats.md.
- A reference file holds only its definition; what a skill does with the result lives only in that skill.
