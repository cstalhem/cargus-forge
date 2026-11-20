---
adr: 012
title: Code carries no comments, and a ratchet holds the count
status: active
---

# ADR-012: Code carries no comments, and a ratchet holds the count

- **Decision:** Code in this repo carries no comments. A reason that the code cannot show lives in an ADR, or in the issue that decided it, and what the code does lives in its names and its tests. `scripts/check-comments.sh` fails a PR that adds a comment line to any file, against a baseline of the comments that are left, and the baseline only goes down.
- **Builds on:** [ADR-009](ADR-009-conventions-are-claude-code-rules.md)

## Details
- **Four kinds of comment, and none stays.** A tautology repeats the code. A stale comment names code that has changed. An excuse explains why a fragile implementation may stay, and the next session copies the pattern. A decision record gives a real reason, in the one place that no reader of the ADRs sees.
- **Agents write the code here**, and an agent treats a comment as an instruction: it keeps a workaround because a comment excuses it, and it adds a paragraph of comment to each function because the file already has them. The engineering plugin's scripts were 14% comment lines (344 of 2,414 lines of shell and YAML) when this was decided.
- **Where a reason goes:** an ADR when it passes the litmus test of the plugin's `references/adr.md`, edited in place when an ADR already answers the question; else the issue that made the decision; else a test whose name states the behaviour. A rule in `.claude/rules/` holds a convention ([ADR-009](ADR-009-conventions-are-claude-code-rules.md)).
- **The lint** counts the lines that start with a comment marker in each tracked `.sh`, `.yml`, `.yaml` and `.py` file (`# `) and each `.js`, `.mjs`, `.cjs` and `.ts` file (`//`, `/*`, `*`). A shebang is no comment. `scripts/comments-baseline.txt` holds one `<count> <path>` line for each file that still has comments, and a file with no line may have none.
- **The ratchet:** a count above its baseline fails, and so does a count below it, until `scripts/check-comments.sh --update` lowers the baseline. `--update` never raises a count, so the only way to add a comment is an edit of the baseline file that a reviewer sees in the PR.
- **`/engineering:delete-comment [path]`** repeats the cleanup: it sorts each comment, deletes it or moves its reason, files a request for each excuse, and lowers the baseline. `plugins/engineering` is at zero.
- A line of a test fixture that starts with `# `, such as a Markdown title in a heredoc, counts as a comment. The baseline carries it.

## Rejected alternatives
- **Keep comments that explain why:** every comment claims to explain why, so the rule needs a judgement on each line, and no lint can make it. The reasons that matter are few enough for the ADRs.
- **Ban comments with no baseline:** the PR that adds the lint must then delete every comment in the repo, including those in plugins that are due for retirement.
- **One total for the repo:** a new comment in one file hides behind a deletion in another.
- **A ShellCheck or ESLint rule:** ShellCheck has no rule that bans comments, the repo has no JavaScript linter, and one rule would not cover shell, YAML and Python.
- **A rule in `.claude/rules/` only:** a rule asks, and a check that one command can run is a check, not a rule.

## Consequences
- A script's output format has no description beside the code. The tests that compare the whole output are its description.
- A reader who wants a reason searches `docs/adr/` and the issues, not the file.
- A fixture line that looks like a comment needs a baseline line, which a reviewer must tell from a real comment.
- A repo that runs a copy of `templates/close-sub-issue.yml` from before this decision reads as `differs` in setup until it copies the template again.
