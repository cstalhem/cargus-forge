# Issue tracker

- **Repo:** GitHub, `cstalhem/cargus-forge`. Default branch: `main`.
- **Branch pattern:** `<n>-<slug>`, the form `gh issue develop` makes. Create every branch with `gh issue develop <n> --name <n>-<slug> --base <base>`, so it is linked to its issue.
  - Feature branch of an umbrella issue: base `main`.
  - Sub-issue branch: base the umbrella's feature branch.
  - Single issue: base `main`.

## PR targets and `Closes` lines
GitHub reads closing keywords only on PRs into `main` ([ADR-002](../adr/ADR-002-feature-branch-per-umbrella.md)).

| PR | Target | `Closes` lines |
|---|---|---|
| Sub-issue PR | the umbrella's feature branch | none; it would close nothing |
| Single-issue PR | `main` | `Closes #<issue>` |
| Final PR of an umbrella | `main` | one `Closes #<n>` for each sub-issue, and one for the umbrella |
