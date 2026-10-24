---
name: discuss
description: Shape a request into one GitHub issue through question rounds. Writes a single issue if the request passes the size test, or an umbrella issue with a Design section if it fails.
argument-hint: "<request or #issue>"
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
- Change no file in the repo, `docs/glossary.md` included. A domain term reaches the glossary only as a `Term` decision in the issue.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. Call the Skill tool with `engineering:domain-model` and `discuss`, every time, not only when a term comes up. If the request is `#<n>`, read the issue with `gh api repos/{owner}/{repo}/issues/<n>`. When execute stopped on that issue, it left the work so far on the current branch. Read it with `git rev-parse --abbrev-ref HEAD`, `git fetch origin main`, `git log --oneline origin/main..HEAD` and `git diff origin/main...HEAD`, so the rounds and the draft account for it. Read the code that the request touches.
2. **Rounds.** Each round lists, as numbered questions, at most five questions whose prerequisites are settled, the ones that unblock others first. Each question has a recommended answer. "yes" accepts every recommendation; "yes, except 2: …" overrides one. Raise the term questions that `domain-model` asks for, against the Glossary section at the end of this skill. A small request needs one or two rounds. Stop when no question remains.
3. **Draft.** Run the size test. Show the draft issue body in the format it picks (pass: issue; fail: umbrella issue), then the verdict for each of the four criteria. Record each accepted term as a `Term` decision, as `domain-model` says. Wait for "yes". If the user changes something, update the draft and show it again.
4. **Write.** After "yes", write the body to a file as the rules say, then run one of these two commands.
   - A new request: `gh api -X POST repos/{owner}/{repo}/issues -f title="<title>" -F body=@<path>`.
   - An existing issue `#<n>`: add its original body at the end, under `## Request`. Then run `gh api -X PATCH repos/{owner}/{repo}/issues/<n> -f title="<title>" -F body=@<path>`.
   - Then set the issue's label as the rules say, on the `number` that the POST returns or on `<n>`: `status:ready` for a single issue, which replaces any other status label; `umbrella` for an umbrella issue, which removes every status label, so an issue that discuss turns into an umbrella keeps none.
5. **Hand off.**
   - Pass: show the issue URL. The next step is execute on this issue.
   - Fail: show the issue URL, then call the Skill tool with `engineering:slice` and the issue number.

## Glossary
!`cat docs/glossary.md 2>/dev/null || printf '\342\200\213'`
