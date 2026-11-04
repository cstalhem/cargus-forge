---
name: next
description: Show where each open issue stands and suggest one next command. Lists the open issues in status groups, with their blockers, their umbrella and a suggested command each, from status.sh, which works out each status from the issue's body, links, branches and PRs. Removes the finished worktrees after one confirm.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh")
  - Bash(bash "${CLAUDE_SKILL_DIR}/labels.sh")
---

# next

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The Facts section below is the output of `status.sh`, which read GitHub and git when this skill loaded. Do not fetch the facts again, and do not change them.
- Run none of the suggested commands. The user picks what to run. The `git` calls under `### Finished worktrees` run only in step 5, after the user's yes.
- The `git` calls are not pre-approved, so Claude Code may ask before each one.
- Delete no remote branch. `### Merged remote branches` is a list for the user to read.

## Steps
1. **Check.** If the Facts section starts with `status.sh error:`, show that line and stop.
2. **Labels.** Run `bash "${CLAUDE_SKILL_DIR}/labels.sh"` as its own Bash call. It keeps the request label `engineering:needs-discussion` on GitHub, and prints one line for each issue it changed, `- none`, or one `labels.sh error:` line. It exits 0. Change no label yourself, and read none.
3. **Report.** Your reply is these parts, in this order, and nothing else:
   1. The `## Report` part of the Facts exactly as printed: the `## Report` heading, each `### <group>` with its issues, their code blocks and their `- blocked by` lines, then the `**Next:**` line with its code block, if it has one. Keep each code fence as printed, so that each command stays copyable.
   2. The `## Labels` heading, then the lines that `labels.sh` printed, as printed.
   3. Only if the `## Cleanup` part of the Facts lists a worktree or a branch, so that not both of its lists are `- none`: the `## Cleanup` part as printed, with its two `###` headings and their `- ` lines, without the indented `git` lines under each worktree.
   4. Only if `### Finished worktrees` lists a worktree: one last line, exactly `Remove these finished worktrees and their local branches? git worktree remove also deletes their ignored files. (yes/no)`
   Add no text before, between or after them: no summary and no comment. The reply's first line is the `## Report` heading. If the reply has no question, the skill ends here, and nothing is removed.
4. **Confirm.** The user's next message answers the question. If it says yes, such as `yes` or `y`, go to step 5. Otherwise run nothing, reply exactly `No worktree removed.`, and end.
5. **Clean up.** Take the worktrees under `### Finished worktrees` one at a time, in the order printed. Finish one worktree before you start the next, and never put two calls in one message. For each worktree:
   1. Run its two indented lines, `git worktree remove '<path>'` and then `git branch -D '<branch>'`, each as its own Bash call, exactly as printed, one at a time. Add nothing to a call: no `--force`, no `-C`, no `cd`, no `>/dev/null`, no `&&` or `;` chain and no pipe. Run no other git command.
   2. If a call fails, run no further call, and stop. Your reply is then these parts, in this order, and nothing else: a `## Removed` heading, then the `- ` line of each worktree whose two calls succeeded, as printed, one per line, or `- none`; a `## Stopped` heading, then the failed worktree's `- ` line as printed, the failed call as printed, and the error output it gave, each on its own line. Ask no question, do not retry, do not add `--force`, and add no comment on the worktrees that are left.
   When every call has succeeded, your reply is a `## Removed` heading, then the `- ` line of each worktree, as printed, one per line, and nothing else.

## Facts
!`bash "${CLAUDE_SKILL_DIR}/status.sh"`
