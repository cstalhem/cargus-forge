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
Sub-issue of #<umbrella> · Blocked by #<a>, #<b>

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

- The first line is for sub-issues only. Leave out ` · Blocked by …` when nothing blocks the sub-issue. Set the parent as a GitHub link too. Each blocker is only text here: the link-blocked-by workflow turns it into a "blocked by" link where it runs.
- `## Decisions` is optional. Add it only if the issue settles something that its scenarios do not state.
- When a sub-issue depends on an umbrella decision, point to it as `#<umbrella> D<n>`. Do not copy its text. A bare `D<n>` always means a decision of the issue itself.

## Final PR body
The one PR that takes a feature branch into `main`. It closes the umbrella and each sub-issue that is still open. Where the repo runs the close-sub-issue workflow (`templates/close-sub-issue.yml`), each sub-issue closed when its PR merged into the feature branch. A repo without it leaves them open, because GitHub reads closing keywords only on PRs into the default branch.

```markdown
<one paragraph: what the feature does>

Closes #<open sub-issue>
Closes #<umbrella>
```
