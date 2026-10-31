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

- The body starts with `## What it delivers`. A sub-issue's parent and blockers live only in GitHub's links, a parent link and "blocked by" links, which slice sets and reads back. The body does not list them.
- `## Decisions` is optional. Add it only if the issue settles something that its scenarios do not state, or points to an umbrella decision.
- When a sub-issue depends on an umbrella decision, point to it as `#<umbrella> D<n>`. Do not copy its text. A bare `D<n>` always means a decision of the issue itself.

## Term decision
A decision that settles one domain term, in the `## Decisions` section of an umbrella issue or an issue. It holds the whole glossary entry for `docs/glossary.md`, in the format of `references/domain-model.md`:

```markdown
- D<n> · Term: **<Term>**: <definition> _Avoid_: <words>
```

Leave out ` _Avoid_: <words>` when the entry has no `_Avoid_` line. An issue whose work writes a `Term` entry lists `docs/glossary.md` under `## Files`.

## ADR decision
A decision that tells execute to write a new ADR or edit an existing one in `docs/adr/`, in the `## Decisions` section of an umbrella issue or an issue. It holds what the ADR needs from the discuss rounds, because execute sees only the issue. `references/adr.md` says when a decision earns one.

```markdown
- D<n> · ADR: <ADR-NNN | new: <title>> · <decision in one sentence> · Rejected: <alternative>: <why>; <alternative>: <why>
```

`ADR-NNN` edits that ADR. `new: <title>` makes a new ADR, which execute numbers when it writes it. An issue whose work writes an ADR lists its file and `docs/adr/README.md` under `## Files`.

## Final PR body
The one PR that takes a feature branch into `main`. It closes the umbrella and each sub-issue that is still open. Where the repo runs the close-sub-issue workflow (`templates/close-sub-issue.yml`), each sub-issue closed when its PR merged into the feature branch. A repo without it leaves them open, because GitHub reads closing keywords only on PRs into the default branch. The `Verify` line links the umbrella's verify comment, because ship runs verify on the umbrella before the PR exists. `## Deviations` gathers every line of the merged sub-issue PRs' `## Deviations` sections, grouped by sub-issue, so the user reads all of them in the one PR they review. Leave the section out when no merged sub-issue PR has one.

```markdown
<one paragraph: what the feature does>

Verify: **PASS**, <URL of the umbrella's verify comment>

## Deviations
- #<sub-issue> (PR #<pr>):
  - <one line, as it stands in that PR's `## Deviations`>

Closes #<open sub-issue>
Closes #<umbrella>
```
