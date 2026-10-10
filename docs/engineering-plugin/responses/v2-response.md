---
title: "Response to plan v2"
date: 2026-10-10
---

> Copied verbatim from the plan page's Respond sheet. Each comment is applied in plan v3; see synthesis.md section 8.

# Re: Engineering Workflow Plugin for Cargus Forge

## Decisions
1. [2.3] How do you work on two features at the same time?  _(kept as proposed)_
   → **One worktree for each active issue** `worktree`
2. [3.2] How strict is the STE rule?  _(kept as proposed)_
   → **Rules as defaults; lengths as targets** `defaults`
3. [3.5] When does a plan page go away?  _(kept as proposed)_
   → **When the umbrella closes, after you confirm** `close`

## Comments
- **1.2.3 skills/to-issues · the slice result**
  > What happens before this stage? When /discuss is done, where does that output go? To a single issue on the issue tracker with all the relevant decisions? If not, where and what does it contain? What about the acceptance criteria? Where do they go? Are they not part of the discuss skill? Also, I do not understand what we need /to-issues for? Is it to keep /discussion short and specialized?
- **1.4 When the last sub-issue merges, converge compares…**
  > What do we need this skill for? What does it do that /verify does not? Why do we need both?
- **2 GitHub and git hold the state. Nobody… › diagram “No chat history goes from…” › node “Front end”**
  > What is this Front End that we talk about? I relate that to front-end development, but I. assume we mean something else here?
- **2 GitHub and git hold the state. Nobody…**
  > This also feels like the first diagram is disconnected from the earlier one, is it not? Why does the Repo and GitHub containers connect to the Loop with the subtext "to verify"? Should that not be /discuss or /execute instead? What am I missin here?
- **2.3.1 skills/next · what you see › mockup**
  > This looks like a full-blown CLI, but I will be working inside Claude Code so I don't understand how this relates to that UI?
- **2.3 /next reads each status from GitHub links,…**
  > I feel that we should use actual labels on GitHub in order to track which issue is in which state, that way we can see that clearly, even if we browse the issue list on GitHub directly.
