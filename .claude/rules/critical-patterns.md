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

## Shipping a plugin change without bumping plugin.json version

WRONG:
```
# edit a plugin, commit, push — leave "version" unchanged
```

CORRECT:
```
# bump plugins/<name>/.claude-plugin/plugin.json "version" (SemVer) in the same commit
```

Why: With an explicit `version` set, Claude Code caches by version string — users never receive the change and `/plugin update` reports "already at the latest version". A silent no-op that is hard to debug.
