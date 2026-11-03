---
description: "High-impact WRONG/CORRECT patterns — mistakes that break builds, cause data loss, or create security issues"
---

# Critical Patterns

<!--
This file captures high-impact mistakes in WRONG/CORRECT format.
Only add patterns here that meet the severity threshold:
- Build-breaking errors
- Data loss or corruption
- Security vulnerabilities
- Silent failures that are hard to debug

Format for each entry:

## <Short description>

WRONG:
```
code or command that causes the problem
```

CORRECT:
```
code or command that avoids the problem
```

Why: One-line explanation of the root cause.
-->

## Setting a version in a plugin manifest

WRONG:
```
# "version": "1.2.3" in plugins/<name>/.claude-plugin/plugin.json or in a marketplace.json entry,
# for example to quiet the validator's "No version specified" warning
```

CORRECT:
```
# no "version" in plugin.json or marketplace.json; scripts/validate-plugins.sh ignores that warning
```

Why: A pinned version keeps users on their cached copy until the string changes, and `/plugin update` reports "already at the latest version" — a silent no-op that is hard to debug.
