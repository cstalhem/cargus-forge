---
name: delete-comment
description: Delete the code comments under a path, or in the whole repo. Sorts each comment as a tautology, stale, an excuse or a decision record, deletes the first two, files a request for the code that an excuse covers, moves a decision record into an ADR, and then lowers the repo's comment baseline, or adds a lint with one. Leaves its changes uncommitted.
argument-hint: "[path]"
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
---

# delete-comment

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- Change comment lines only. The code behaves the same after the run: fix no code that a comment excuses, file the request instead.
- Sort every comment in scope before you delete one, and delete none that you have not read with the code around it.
- A shebang, a linter directive, a licence header and a comment inside a test fixture or a template string are not comments: leave them.
- Ask no question. Leave the changes in the working tree, and commit nothing.

## Steps
1. **Scope.** The scope is the path in the argument, or every tracked file when there is none. List the comment lines of each code file in scope with `git grep -nE` and the comment pattern of its language, such as `'^[[:space:]]*#( |$)'` for shell, YAML and Python, and `'^[[:space:]]*(//|/\*|\*)'` and trailing `//` for JavaScript. Count the lines of those files with `wc -l` for step 6.
2. **Sort.** Read each file in scope whole, and give each comment the first category that fits:
   - **stale:** it names code, a file, an argument or behaviour that is no longer there. Check each name it holds with `git grep`.
   - **excuse:** it explains why code may stay incomplete or fragile: a limit that is not enforced, a case that is left out, a guess, a match on an error's text, a `TODO`, a "for now".
   - **decision record:** it gives a reason that the code cannot show: why this way and not the obvious one, a limit of an outside system, a security or data-loss guard.
   - **tautology:** anything else. It says what the code, a name or a test already says.
3. **Decision records.** Read `${CLAUDE_PLUGIN_ROOT}/references/adr.md` and each ADR in `docs/adr/`. For each decision record:
   - an ADR already states the reason: delete the comment;
   - it passes the litmus test: edit the ADR that answers the same question, or write a new ADR, as `adr.md` says, then delete the comment;
   - it fails the litmus test and the comment names its issue, such as `#179 D1`: the issue holds it, so delete the comment;
   - it fails the litmus test and nothing else holds the reason: keep the comment, and count it in step 6.
4. **Excuses.** Merge the excuses for the same weakness into one. Search the open issues for it, and only if none covers it, create a request as the rules say, with the title `<area>: <the weakness, as a fact>` and a body with one `## Finding` section: the file and function, the deleted comment quoted, what goes wrong and with which input, and the change you would make. Add no label. Then delete the comments.
5. **Delete.** Delete each stale and tautology comment, and each one that steps 3 and 4 released. Delete the whole line, and a blank line that the deletion leaves doubled. Where a deleted comment named a test's case or a helper's arguments and the name does not, rename it instead of keeping the comment. If the repo runs a byte-identical copy of a changed file, copy it again. Run the pre-PR checks, and stop on a failure with its output.
6. **Ratchet.** Find the repo's comment lint: a row of `docs/agents/commands.md`, or a linter rule.
   - **It exists:** lower its baseline to the counts that are left, by the command it names.
   - **It does not:** add one. Use a rule of the repo's linter when it has one that bans comments and supports a per-file allowance. Otherwise write one script that counts the comment lines of each tracked code file, compares each count with a tracked baseline file of `<count> <path>` lines, fails when a count is above its baseline or below it, and lowers the baseline, never raises it, on `--update`. A file with no line has a baseline of 0. Add its test, its row to `docs/agents/commands.md` as a pre-PR check, and its step to CI.
7. **Report.** Print the number of comments in each category; each ADR edited or written; each request with its number; each comment kept and why; and the lines before, the lines now, and the comment lines that the baseline still allows.
