---
name: discuss
description: Shape a request into one GitHub issue through question rounds. Writes a single issue if the request passes the size test, or an umbrella issue with a Design section if it fails.
argument-hint: "<request or #issue>"
model: fable
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(cat docs/glossary.md 2>/dev/null || printf '\342\200\213')
---

# discuss

Request: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Write nothing to GitHub until the user answers "yes" to the draft.
- Never ask what the code can answer. Read the code, and ask only what is left.
- Change no file in the repo, `docs/glossary.md` and `docs/adr/` included. A domain term reaches the glossary only as a `Term` decision in the issue, and an ADR reaches `docs/adr/` only as an `ADR` decision.
- One exception to the read scope above, for discuss only: to check a fact that a design rests on, you may run a command or tool call that changes nothing, also outside the repo, and show its output.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. Read `${CLAUDE_PLUGIN_ROOT}/references/domain-model.md` every time, not only when a term comes up, and follow its `In discuss` section. Read `${CLAUDE_PLUGIN_ROOT}/references/adr.md` every time, not only when a decision comes up, and follow its `In discuss` section. If the request is `#<n>`, read the issue with `gh api repos/{owner}/{repo}/issues/<n>`. When execute stopped on that issue, it left the work so far on the current branch. Read it with `git rev-parse --abbrev-ref HEAD`, `git fetch origin main`, `git log --oneline origin/main..HEAD` and `git diff origin/main...HEAD`, so the rounds and the draft account for it. Read the code that the request touches.
2. **Rounds.** Each round lists, as numbered questions, at most five questions whose prerequisites are settled, the ones that unblock others first. Each question has a recommended answer. "yes" accepts every recommendation; "yes, except 2: …" overrides one. Raise the term questions that `domain-model.md` asks for, against the Glossary section at the end of this skill. Raise the ADR questions that `adr.md` asks for. A small request needs the challenge and at most two more rounds. Stop when no question remains.
   - **Challenge:** the first round questions the request before any question about how to build it. It opens with one line for the request and one for each requirement: `- <requirement> · <source> · keep | simplify | delete`. A source is the user's words in the request, an issue, an ADR or the code, never a person. A requirement with no source gets delete. Each simplify or delete verdict is a numbered question whose recommended answer says why. If the request is to speed up or automate a step, first ask whether that step, or the part that makes it needed, could be deleted or simplified instead; speed and automation come only in a later round. If every line is keep, the round is the one line `Challenge: nothing to cut`.
   - **Human boundary:** if the request automates or delegates work, the challenge also asks as a numbered question where the human boundary lies: which steps the user keeps, and which must never wait for the user. Later rounds design for that boundary. A recommendation that leaves a step with the user says that the step crosses the human boundary, and why.
   - A requirement that the challenge cuts gets no decision and stays out of the draft. Removing a part that exists in the repo becomes `D<n> · Delete: <part>`, with a scenario `WHEN … THEN <part> is gone`. Sources stay in the round, not in the issue.
   - **Design recommendations:** each recommendation of how to build the request gets these checks, shown in the round where it first appears:
     - **Trace:** if it adds a part that runs, such as a session, a script, a scheduled task or a hook, show a trace of one dated run: numbered, one line per step, saying who acts, what it reads or keeps, and whether it waits for the user. A change that adds no part that runs, such as a text-only change, gets no trace.
     - **State:** each part that keeps state, such as memory, a timer, a note, a label or a lock, gets one line, found by reading the trace's lines: the state, where its truth lives, and what happens when the two disagree. A part that keeps nothing gets no line. A part that keeps a copy of a fact that a command can read gets simplify or delete, as the challenge does for the request.
     - **Rules:** read each `.claude/rules/` file that loads for the files it touches, and check the recommendation against each line; a recommendation never contradicts one, so it changes, or the round asks as a numbered question whether the issue edits that rule too.
     - **Need:** name the scenario or decision that needs each part it adds, such as a script, a section, a check or a file; a part that none needs stays out of the design, and in an umbrella issue it goes under `## Out of scope`, so it can come back when a real run needs it.
     - **Must be true:** end the recommendation with `Must be true:` and the facts it rests on. Check each fact in the code, or with a command or tool call that changes nothing, and show the output. Ask a fact that you cannot check as a numbered question that names it as unchecked.
     - **Unchecked or not shown:** record a fact accepted as unchecked, or a result only a merged and synced plugin can show, as the decisions in `formats.md` say.
   - **Plain questions:** each question states the situation, what the recommended answer does in practice, and why. Name tools by what they do, not by their API names.
   - **Defaults:** a point with one sensible answer is not a question; state it in the round as one line, `Default: <answer>, because <why>`, before the numbered questions; "yes" accepts it, and the user can override it as they would a question.
3. **Draft.** Run the size test. Show the draft issue body in the format it picks (pass: issue; fail: umbrella issue), then the verdict for each of the four criteria. Record each accepted term as a `Term` decision, as `domain-model.md` says, and each accepted ADR as an `ADR` decision, as `adr.md` says. An umbrella issue for a design that adds a part that runs holds the trace of the accepted design in its `## Design`. Wait for "yes". If the user changes something, update the draft and show it again.
4. **Write.** After "yes", write the body to a file as the rules say, then run one of these two commands.
   - A new request: `gh api -X POST repos/{owner}/{repo}/issues -f title="<title>" -F body=@<path>`.
   - An existing issue `#<n>`: add its original body at the end, as the exception line in `formats.md` says. Then run `gh api -X PATCH repos/{owner}/{repo}/issues/<n> -f title="<title>" -F body=@<path>`.
5. **Hand off.**
   - Pass: show the issue URL. The next step is execute on this issue.
   - Fail: show the issue URL, then call the Skill tool with `engineering:slice` and the issue number.

## Glossary
!`cat docs/glossary.md 2>/dev/null || printf '\342\200\213'`
