---
name: next
description: Recommend one next command and why, and the order of the open issues that relate. Compares the issues' bodies, from bodies.sh, with their statuses, blockers and umbrellas, from status.sh, for shared files, conflicting goals and dependencies. Removes the finished worktrees after one confirm.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh")
  - Bash(bash "${CLAUDE_SKILL_DIR}/bodies.sh")
  - Bash(bash "${CLAUDE_SKILL_DIR}/labels.sh")
---

# next

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The Facts section below is the output of `status.sh` and, under `## Bodies`, of `bodies.sh`, which read GitHub and git when this skill loaded. Do not fetch the facts again, and do not change them.
- Compare the bodies and the `status.sh` facts only, and read no code. Shared files come from the `## Files` sections and from the paths and skill names that a body mentions.
- The recommendation is advice only: write no "blocked by" link and no other change to GitHub.
- Run none of the recommended commands. The user picks what to run. The `git` calls under `### Finished worktrees` run only in step 6, after the user's yes.
- The `git` calls are not pre-approved, so Claude Code may ask before each one.
- Delete no remote branch. `### Merged remote branches` is a list for the user to read.

## Steps
1. **Check.** If a part of the Facts starts with `status.sh error:` or `bodies.sh error:`, show that line and stop.
2. **Labels.** Run `bash "${CLAUDE_SKILL_DIR}/labels.sh"` as its own Bash call. It keeps the request label `engineering:needs-discussion` on GitHub, and prints one line for each issue it changed, `- none`, or one `labels.sh error:` line. It exits 0. Change no label yourself, and read none.
3. **Recommend.** Pick the one issue to work next from the first group that has one, and in it the lowest number:
   1. Needs review, then in progress. These always come first.
   2. An umbrella whose sub-issues are all done, which has `/engineering:ship #<u>` in its code block.
   3. Ready to build.
   4. To shape.
   From groups 2 to 4 you may take another issue instead, only when working the first one first would redo or undo work, such as when both change the same file or one's goal replaces the other's. Say so in `Why:` or in `## Order`. Flag an issue whose goal conflicts with another's, and do not pick which goal wins.
4. **Reply.** Your reply is these parts, in this order, and nothing else:
   1. `## Next`, then one code block with the command from the issue's code block in the report, or `review and merge PR #<pr>` for a needs-review issue, then `Why:` and at most three sentences. If no open issue waits for a step, `## Next` holds the one line `Nothing: no open issue waits for a step.`
   2. `## Order`, with at most five lines, each `#<a> before #<b>: <reason>` or `#<a> and #<b> conflict: <reason>`. Leave the part out when no issues relate.
   3. `## Labels`, then the lines that `labels.sh` printed, as printed. Only if `labels.sh` changed a label or printed an error, so not for `- none`.
   4. Only if the `## Cleanup` part of the Facts lists a worktree or a branch, so that not both of its lists are `- none`: the `## Cleanup` part as printed, with its two `###` headings and their `- ` lines, without the indented `git` lines under each worktree.
   5. Only if `### Finished worktrees` lists a worktree: one last line, exactly `Remove these finished worktrees and their local branches? git worktree remove also deletes their ignored files. (yes/no)`
   Add no `## Report` part, and no text before, between or after the parts. The reply's first line is the `## Next` heading. If the reply has no question, the skill ends here, and nothing is removed.
5. **Confirm.** The user's next message answers the question. If it says yes, such as `yes` or `y`, go to step 6. Otherwise run nothing, reply exactly `No worktree removed.`, and end.
6. **Clean up.** Take the worktrees under `### Finished worktrees` one at a time, in the order printed. Finish one worktree before you start the next, and never put two calls in one message. For each worktree:
   1. Run its two indented lines, `git worktree remove '<path>'` and then `git branch -D '<branch>'`, each as its own Bash call, exactly as printed, one at a time. Add nothing to a call: no `--force`, no `-C`, no `cd`, no `>/dev/null`, no `&&` or `;` chain and no pipe. Run no other git command.
   2. If a call fails, run no further call, and stop. Your reply is then these parts, in this order, and nothing else: a `## Removed` heading, then the `- ` line of each worktree whose two calls succeeded, as printed, one per line, or `- none`; a `## Stopped` heading, then the failed worktree's `- ` line as printed, the failed call as printed, and the error output it gave, each on its own line. Ask no question, do not retry, do not add `--force`, and add no comment on the worktrees that are left.
   When every call has succeeded, your reply is a `## Removed` heading, then the `- ` line of each worktree, as printed, one per line, and nothing else.

## Facts
!`bash "${CLAUDE_SKILL_DIR}/status.sh"`

## Bodies
!`bash "${CLAUDE_SKILL_DIR}/bodies.sh"`
