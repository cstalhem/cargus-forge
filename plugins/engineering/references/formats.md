# Issue formats

A scenario is one acceptance criterion as `WHEN <condition> THEN <result>`. Each scenario becomes a test.

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

## Files
<paths>

## Verify
<one command that fails before the work and passes after it>
```

- The first line is for sub-issues only. Set the parent and "blocked by" as GitHub links where possible, not only as text.
