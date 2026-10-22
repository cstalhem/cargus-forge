# Glossary

**Size test**: The four checks that decide whether a piece of work fits one session.

**Shape**: The phases that turn a request into issues, from discuss through slice.

**Build**: The phases that take one issue to a merged PR: execute, verify, then merge. For an umbrella issue, ship comes last.

**Issue**: A unit of work that fits one session: a single issue or a sub-issue. An umbrella issue is not one.
_Avoid_: task, ticket

**Single issue**: An issue with no umbrella issue; its PR goes into `main`.

**Umbrella issue**: The one record of a feature that needs more than one session: goal, scenarios, decisions, design and out of scope.
_Avoid_: epic

**Sub-issue**: An issue under an umbrella issue; its PR goes into the feature branch.
_Avoid_: child issue, ticket

**Scenario**: One acceptance criterion written as `WHEN … THEN …`; each one becomes a test.
_Avoid_: test case, user story

**Feature branch**: The branch of an umbrella issue, which its sub-issue PRs merge into.

**Final PR**: The one PR that takes a feature branch into `main`; ship opens it.
