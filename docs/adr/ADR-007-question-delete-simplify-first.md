---
adr: 007
title: Question, delete and simplify before speeding up or automating
status: active
---

# ADR-007: Question, delete and simplify before speeding up or automating

- **Decision:** The engineering plugin follows five principles, in this order, in its own design and in the process it runs. discuss applies them to every request in its challenge round.
- **Source:** [#181](https://github.com/cstalhem/cargus-forge/issues/181)

## Details
- **The principles, in order:**
  1. Question every requirement. Each one has a source, and a requirement from a trusted source is questioned too.
  2. Delete any part or step you can. Some will come back later, and that is expected.
  3. Simplify and optimise what is left. Never simplify a part that should not exist.
  4. Speed up the cycle time, only after the first three.
  5. Automate last, once the first four leave nothing to cut.
- **The challenge round** is discuss's first round. It lists the request and each of its requirements with a source and a verdict of keep, simplify or delete, and asks each simplify or delete verdict as a question with the reason for its recommendation. A request to speed up or automate a step first gets the question whether the step could be deleted or simplified.
- **A source, not a person:** a source is the user's words in the request, an issue, an ADR or the code. A requirement with no source gets the verdict delete.
- **Deletions are decisions:** removing a part that exists in the repo is a `D<n> · Delete: <part>` decision with its own scenario, so verify checks that the part is gone. A requirement cut from a request gets no decision; the original wording stays under the issue's `## Request`.
- **Only discuss challenges.** slice, execute and verify take the shaped issue as it is.
- **The plugin applies them to itself:** #181 runs the plugin's own skills through the challenge.

## Rejected alternatives
- **Name the person behind each requirement:** in a repo with one maintainer the person is nearly always the user, so it rules out little. A source can be checked.
- **A challenge in every phase:** more process, which is what the principles cut.
- **Sources in the issue body:** longer issues for no change in what gets built. The decisions already record what the challenge settled.
- **Skip the challenge for small requests:** discuss would then decide what counts as small, and requirements slip through there.
- **Track the rule that at least 10% of deletions come back:** discuss has nothing to measure it against, and git keeps what was deleted.

## Consequences
- Every discuss run has one more round. It is one line, `Challenge: nothing to cut`, when every verdict is keep.
- The challenge is checked by reading discuss's output, not by a test: the issue's verify command proves only that the text is there.
