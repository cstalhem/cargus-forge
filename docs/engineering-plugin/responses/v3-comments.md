---
title: "Comments on plan v3"
date: 2026-10-12
---

> Copied verbatim from the chat. They were written about the v3 summary, not through the plan page. Each one is applied in plan v4; see synthesis.md section 9.

> Converge vs. verify. Your question showed they're the same skill. There is now one `verify` with two scopes:
> * Issue scope: on each PR, checked against that issue's scenarios.
> * Umbrella scope: once, when the last sub-issue merges, checked against the umbrella's scenarios on `main`.

This statement does not make sense. Do we really do one PR per sub-issue? Between which branches in that case? Regardless, I thought we wanted one PR per Umbrella that then merges to main?

---

On the script that runs in the /next skill, how is that invoked? Is it run by the model or can we "force" it to run deterministically so there is no chance the model forgets to do it or does it some other way?

---

I don't think we want labels that are already described some other way. GitHub could show blockers on the free plan, yes? If so, we don't really need a blocked label as well, right? However, if it's not too many instructions in the /next skill we might keep a few labels.
Agreed as well on that the different skills set them so that each skill only have one or at least very few options to choose from to simplify as much as possible. I don't think we will need a GitHub Action at all.

---

I like the names now: Shape -> Build with each of the skills underneath them.

---

Based on this, how does this change the plan?
