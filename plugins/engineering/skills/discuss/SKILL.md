---
name: discuss
description: Shape a request into one GitHub issue through question rounds. Writes a single issue if the request passes the size test, or an umbrella issue with a Design section if it fails.
argument-hint: "<request or #issue>"
disable-model-invocation: true
allowed-tools: Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
---

# discuss

Request: $ARGUMENTS

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Write nothing to GitHub until the user answers "yes" to the draft.
- Never ask what the code can answer. Read the code, and ask only what is left.

## Steps
1. **Load.** Read `${CLAUDE_PLUGIN_ROOT}/references/size-test.md` and `${CLAUDE_PLUGIN_ROOT}/references/formats.md`. If the request is `#<n>`, read the issue with `gh issue view <n>`. Read the code that the request touches.
2. **Rounds.** Each round lists, as numbered questions, at most five questions whose prerequisites are settled, the ones that unblock others first. Each question has a recommended answer. "yes" accepts every recommendation; "yes, except 2: …" overrides one. A small request needs one or two rounds. Stop when no question remains.
3. **Draft.** Run the size test. Show the draft issue body in the format it picks (pass: issue; fail: umbrella issue), then the verdict for each of the four criteria. Wait for "yes". If the user changes something, update the draft and show it again.
4. **Write.** After "yes", write the body to a file as the rules say, then run one command.
   - A new request: `gh issue create --title "<title>" --body-file <path>`.
   - An existing issue `#<n>`: add its original body at the end, under `## Request`. Then run `gh issue edit <n> --title "<title>" --body-file <path>`.
5. **Hand off.**
   - Pass: show the issue URL. The next step is execute on this issue.
   - Fail: show the issue URL, then call the Skill tool with `engineering:slice` and the issue number.
