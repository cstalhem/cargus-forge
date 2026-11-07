---
adr: 011
title: Build acts only on items by trusted authors
status: active
---

# ADR-011: Build acts only on items by trusted authors

- **Decision:** `status.sh`, `next` and both Autopilots act on an issue, a PR or a comment only when its author is a trusted author, and discuss shapes an outside issue into a new issue that the user writes.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md)
- **Source:** [#362](https://github.com/cstalhem/cargus-forge/issues/362)

## Details
- The repo is public, so anyone can open an issue or post a comment, and Autopilot builds each ready issue unattended ([ADR-008](ADR-008-autopilot-builds-ready-issues-unattended.md)).
- A trusted author is a GitHub user whose `author_association` is OWNER, MEMBER or COLLABORATOR. `scripts/lib.sh` holds one jq definition, `trusted`, next to `has_section`, and `status.sh` and `bodies.sh` both load it.
- `author_association` comes with the open-issue and open-PR lists that the scripts already read, so the check adds no API call. A merged PR, a branch, a sub-issue link and a "blocked by" link all need write access to create, so only those two lists need it.
- An outside issue is a request whatever its body, so it sits under `### To shape` with the fact `from <login>, not a trusted author`, and `labels.sh` keeps `engineering:shaped` off it. An outside PR names no issue, so it gives no fact. `bodies.sh` prints the heading of an outside issue and that fact in place of its body.
- A comment is a fact only when its author is a trusted author. One line in `references/rules.md` says so for every skill that reads a comment, `autopilot-t3` included, so no Autopilot step changes.
- An outside item gets no hand-off and no push notification: an outside issue waits under To shape, and an outside PR waits on GitHub.
- discuss shapes an outside issue into a new issue with the original body under `## Request`, comments `Shaped as #<new>.` on the original and closes it. This rests on the unchecked assumption that GitHub lets an issue's author edit its body after the repo owner rewrites it.

## Rejected alternatives
- **Also trusting the token's user:** every comment a session posts already reads as OWNER, so it adds nothing.
- **A permission call per author:** it costs a call per item, and `author_association` only errs towards leaving out a trusted person.
- **A separate report group for outside items:** an outside issue is a request and an outside PR is no fact, so no new status or reader is needed.
- **A hand-off per outside item:** a stranger could page the user by opening issues.
- **Shaping an outside issue in place:** its author stays a stranger, who can edit the body after the yes.
- **A private repo or GitHub's interaction limits:** the marketplace install needs a public repo, and the limits expire after six months.
- **A fix in each Autopilot step that reads a comment:** one line in `rules.md` covers every comment read in every skill.

## Consequences
- A trusted person whose `author_association` GitHub reports as something else, such as a member who hides their organisation membership, is left out until they are made a collaborator.
- A request from outside the repo needs the user to run `/engineering:discuss #<n>`, which writes a new issue, before Build touches it.
