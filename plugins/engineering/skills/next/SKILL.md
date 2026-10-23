---
name: next
description: Show where each open issue stands and suggest one next command. Lists the open issues in status groups, with their blockers, their umbrella and a suggested command each, from status.sh, repairs each status label that the facts contradict, and removes the finished worktrees after one confirm.
disable-model-invocation: true
allowed-tools:
  - Bash(cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md")
  - Bash(bash "${CLAUDE_SKILL_DIR}/status.sh")
  - Bash(gh api -X POST repos/{owner}/{repo}/issues/*/labels -f 'labels[]=status:in-progress')
  - Bash(gh api -X POST repos/{owner}/{repo}/issues/*/labels -f 'labels[]=status:needs-review')
  - Bash(gh api -X DELETE repos/{owner}/{repo}/issues/*/labels/status:ready)
  - Bash(gh api -X DELETE repos/{owner}/{repo}/issues/*/labels/status:in-progress)
  - Bash(gh api -X DELETE repos/{owner}/{repo}/issues/*/labels/status:needs-review)
  - Bash(gh api 'repos/{owner}/{repo}/issues/*/labels?per_page=100' --jq '[.[].name] | sort | tojson')
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: bash "${CLAUDE_PLUGIN_ROOT}/skills/next/label-guard.sh"
---

# next

## Rules
!`cat "${CLAUDE_PLUGIN_ROOT}/references/rules.md"`
- The Facts section below is the output of `status.sh`, which read GitHub and git when this skill loaded. Do not fetch the facts again, other than the label read-back in step 2, and do not change them.
- Run none of the suggested commands. The user picks what to run. The `gh api` calls under `## Repairs` are not suggestions: step 2 runs them. The `git` calls under `### Finished worktrees` run only in step 5, after the user's yes.
- The `gh api` calls under `## Repairs` and the read-back in step 2 are pre-approved only exactly as written. `label-guard.sh` makes Claude Code ask for any other spelling of them. The `git` calls are not pre-approved, so Claude Code may ask before each one.
- Delete no remote branch. `### Merged remote branches` is a list for the user to read.
- A repair follows the label rule above. `status.sh` read the labels, which stands for its step 1, and it removes only labels that it read.

## Steps
1. **Check.** If the Facts section starts with `status.sh error:`, show that line and stop.
2. **Repair.** If the `## Repairs` part of the Facts is `- none`, go to step 3. Otherwise, take the entries one at a time, in the order printed. Each entry starts with a line `- #<n> · <change> · <fact>`. Do not ask, and show no text unless a read-back differs. Finish one entry, its read-back included, before you start the next, and never put calls of two entries, or two calls, in one message. For each entry:
   1. Run each indented `gh api` line under it as its own Bash call, exactly as printed, one at a time, in order. Add nothing to a call: no `>/dev/null`, no `&&` or `;` chain, no pipe and no `--jq`.
   2. Read the labels back, as its own Bash call, with `gh api 'repos/{owner}/{repo}/issues/<n>/labels?per_page=100' --jq '[.[].name] | sort | tojson'`. Its output must be exactly the JSON array on the entry's `labels after:` line, which holds the labels sorted the same way.
   3. If it is not, run no further call. Show the issue number, the expected array and the array you read, and stop. Ask no question, do not retry, and skip steps 3 to 5.
3. **Report.** Your reply is these parts, in this order, and nothing else:
   1. The `## Report` part of the Facts exactly as printed: the `## Report` heading, each `### <group>` with its lines, then the `Next:` line.
   2. Only if step 2 ran a repair: a `## Repairs` heading, then the `- #<n> · …` line of each entry, as printed, one per line, without its calls and its `labels after:` line.
   3. Only if the `## Cleanup` part of the Facts lists a worktree or a branch, so that not both of its lists are `- none`: the `## Cleanup` part as printed, with its two `###` headings and their `- ` lines, without the indented `git` lines under each worktree.
   4. Only if `### Finished worktrees` lists a worktree: one last line, exactly `Remove these finished worktrees and their local branches? git worktree remove also deletes their ignored files. (yes/no)`
   Add no text before, between or after them: no summary, no read-back result and no comment. The reply's first line is the `## Report` heading. If the reply has no question, the skill ends here, and nothing is removed.
4. **Confirm.** The user's next message answers the question. If it says yes, such as `yes` or `y`, go to step 5. Otherwise run nothing, reply exactly `No worktree removed.`, and end.
5. **Clean up.** Take the worktrees under `### Finished worktrees` one at a time, in the order printed. Finish one worktree before you start the next, and never put two calls in one message. For each worktree:
   1. Run its two indented lines, `git worktree remove '<path>'` and then `git branch -D '<branch>'`, each as its own Bash call, exactly as printed, one at a time. Add nothing to a call: no `--force`, no `-C`, no `cd`, no `>/dev/null`, no `&&` or `;` chain and no pipe. Run no other git command.
   2. If a call fails, run no further call, and stop. Your reply is then these parts, in this order, and nothing else: a `## Removed` heading, then the `- ` line of each worktree whose two calls succeeded, as printed, one per line, or `- none`; a `## Stopped` heading, then the failed worktree's `- ` line as printed, the failed call as printed, and the error output it gave, each on its own line. Ask no question, do not retry, do not add `--force`, and add no comment on the worktrees that are left.
   When every call has succeeded, your reply is a `## Removed` heading, then the `- ` line of each worktree, as printed, one per line, and nothing else.

## Facts
!`bash "${CLAUDE_SKILL_DIR}/status.sh"`
