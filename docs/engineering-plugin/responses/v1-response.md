---
title: "Response to plan v1"
date: 2026-10-10
---

> Copied verbatim from the plan page's Respond sheet. Each comment is applied in plan v2; see synthesis.md section 7.

# Re: Engineering Workflow Plugin for Cargus Forge

## Decisions
1. [1] When does the research phase run?  _(kept as proposed)_
   → **Only on the long path, after the size check** `long`
2. [2] Where does the state between sessions live?  _(kept as proposed)_
   → **GitHub issues only, through one tracker profile** `github`
3. [3] How does the plugin make HTML plans?  _(kept as proposed)_
   → **Depend on the html-plan plugin** `depend`
4. [4] What happens to knowledge-system and adr-management?  _(kept as proposed)_
   → **Engineering takes over both; we deprecate them later** `replace`
5. [5] Where do we start?  _(not opened; default kept)_
   → **Contract first, then one thin path from end to end** `contract`

## Comments
- **1 The size of the work selects the… › diagram “The agent sizes the work…” › node “Request”**
  > How does this diagram map to 1.1 The Long path below? Is this for every issue we start on?
- **1.1 The long path has seven phases. Each…**
  > So, each of these steps are part of our workflow. Correct? As with the quesiton above, how do they relate to the "Size of the work" flow? Should not the step between "Plan" and "Issues" here already do the size check and break down the issues into proper sizes?
- **1.4 A separate agent grades the work against…**
  > Why is this grading work presented here? How does it relate to the size of the work? It's presented as the next step after "Each discussion ends with your known and unknown unknowns", but it feels like this belongs much later in the process than just after the discussion? I might be wrong here though so happy to be corrected and to get this explained better.
- **2.2 Each sub-issue fits one session and names…**
  > I want to come back to the evals of this project later as we need to discuss them properly.
- **2.3 The /next command tells you where you…**
  > How would this work? Where in the repo does this state live? Issues is fine, but what is the mechanism for selecting the next relevant issue? We could work on multiple features at the same time, so multiple sub-issues could in theory be "next" in that case. I don't want to have to write out a state text in an issue body, since this will be missed and get outdated, so we need some other way of tracking that.
- **2.3 The /next command tells you where you… › mockup**
  > What does this text illustrate? I don't understand what the output text is supposed to tell me. It looks like it's a pseudo-code illustration of what running the /next command looks like, but the rows after it are not really obvious to me. I assume they are statuses for sub-issues to the #41 umbrella issue?
- **2.4 Plans are disposable. ADRs, the glossary and… › tree › repo/docs/agents**
  > What goes in this folder? I need to understand based on a couple of examples.
- **2.4 Plans are disposable. ADRs, the glossary and… › tree › repo/tests**
  > Is this not the same folder that generally keeps track of code tests? If so, is that really prudent to use? In 1.4 we describe a grading outline for if work is done or not. I assume that it should not be committed since it will only be relevant for the implementation of that specific issue? If that is the case, it should live in a non-committed location, right?
- **3 You read and answer each plan on… › note “Setup marketplace.json must allow the claude-plugins-community…”**
  > Is this actually possible given how plugins and marketplaces work today?
- **3.1 Plans, issues and ADRs use STE at… › mockup**
  > Do we really need to enforce the 20-word limit?
- **3.3 Remote Control sessions on the Linux host…**
  > This is good, but we need to make sure that plans are removed when done so that we dont end up with a bunch of orphaned artifacts nobody needs.
