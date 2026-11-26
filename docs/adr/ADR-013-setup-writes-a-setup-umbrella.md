---
adr: 013
title: Setup analyses the repo and writes a ready umbrella issue
status: active
---

# ADR-013: Setup analyses the repo and writes a ready umbrella issue

- **Decision:** Setup changes no file; Opus agents analyse the repo by area, and after one yes setup writes a setup umbrella whose sub-issues name exactly what to write, with the final PR as the review.
- **Source:** [#456](https://github.com/cstalhem/cargus-forge/issues/456)

## Details
- Setup writes the setup umbrella with `engineering:shaped` and `engineering:umbrella`, its feature branch from `main`, and one sub-issue for each accepted proposal, each with its parent link and `engineering:shaped`.
- A repo with no code needs no analysis: setup starts no agent and proposes the repo profile and the close-sub-issue workflow.
- Each sub-issue stands alone and has no "blocked by" link, and execute and verify build and grade it like any other.
- A repo setting is a note for the user in the setup umbrella's Design. Setup changes no setting.
- The setup umbrella is found by its first body line, `<!-- engineering:setup umbrella -->`, and by nothing else.

## Rejected alternatives
- **Files written to the working tree after a yes:** nothing takes effect until they are committed and merged by hand.
- **Setup opens its own PR:** it copies what execute and verify do.
- **Analysis inside each sub-issue:** such a sub-issue fails the size test, because what to write is an open question and no command fails before the work.
- **A greenfield skill and a brownfield skill:** a repo with no code needs no analysis, so the split holds almost nothing.
- **A skill for each area:** a skill that another skill calls is listed in every session of every repo.
- **A stop on each repo setting:** a setting does not keep setup from writing the umbrella.

## Consequences
- Every file that setup used to write arrives through a PR that verify grades.
- The user's yes covers GitHub writes only, so a wrong proposal costs a closed issue and no revert.
