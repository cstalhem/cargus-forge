# Issue formats

A scenario is one acceptance criterion as `WHEN <condition> THEN <result>`. Each scenario becomes a test.

Use exactly the sections of the format, in its order, and add no other section. The one exception: when discuss rewrites an existing issue, it adds the original body at the end under `## Request`.

## Umbrella issue
The one record of a feature that needs more than one session.

```markdown
## Goal
<one sentence: who can do what>

## Scenarios
- WHEN <condition> THEN <result>

## Decisions
- D1 · <decision> (<ADR link if one exists>)

## Design
<modules, seams, data shapes>

## Out of scope
- <item>
```

## Issue (single issue or sub-issue)
One session of work.

```markdown
Sub-issue of #<umbrella> · Blocked by #<n>

## What it delivers
<one behaviour>

## Scenarios
- WHEN <condition> THEN <result>

## Decisions
- D1 · <decision>
- #<umbrella> D<n>

## Files
<paths>

## Verify
<one command that fails before the work and passes after it>
```

- The first line is for sub-issues only. Set the parent and "blocked by" as GitHub links where possible, not only as text.
- `## Decisions` is optional. Add it only if the issue settles something that its scenarios do not state.
- When a sub-issue depends on an umbrella decision, point to it as `#<umbrella> D<n>`. Do not copy its text. A bare `D<n>` always means a decision of the issue itself.

## Final PR body
The one PR that takes a feature branch into `main`. GitHub reads closing keywords only on PRs into the default branch, so this PR closes every sub-issue and the umbrella.

```markdown
<one paragraph: what the feature does>

Closes #<sub-issue>
Closes #<sub-issue>
Closes #<umbrella>
```
