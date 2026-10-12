---
adr: 003
title: Plans are disposable HTML pages made with html-plan
status: active
---

# ADR-003: Plans are disposable HTML pages made with html-plan

- **Decision:** The plan of an umbrella issue is one html-plan page, published as a private artifact. The page is not committed to git. It is deleted when the umbrella issue closes, after you confirm. The plugin depends on html-plan and does not copy it.
- **Builds on:** [ADR-001](ADR-001-github-is-the-work-state-store.md)

## Details
- **Dependency:**
  - `plugin.json` declares `"dependencies": ["html-plan@claude-community"]`.
  - The root `marketplace.json` declares `"allowCrossMarketplaceDependenciesOn": ["claude-community"]`. Without it, the install skips html-plan and the plugin fails to load.
  - No version range is set, because html-plan has no release tags.
- **Answers from the page** go into the umbrella issue's Decisions section. Lasting decisions become ADRs. Deleting the page therefore loses nothing.
- **Revisions:** each umbrella has one page, and each revision republishes it at the same link. The umbrella issue holds that link.
- **Writing:** plan pages, issues and ADRs follow ASD-STE100 rules as defaults. Sentence lengths are targets, not gates. Chat stays in normal prose.
- **Until the plan stage is built,** a `## Design` section in the umbrella issue holds the plan.

## Rejected alternatives
- **Markdown plan files in the repo:** HTML diffs and markdown plans grow long, go stale and add files to keep correct.
- **Copy and adapt html-plan** (MIT): the plugin would then own a runtime of about 209 KB.
- **A lighter page of our own:** we would rebuild the lint and the answer round-trip.
- **Keep pages as a record:** this leaves orphaned artifacts.
- **Delete the page right after slice:** the mockups are useful during Build.

## Consequences
- Plans need Artifacts, and therefore a claude.ai login. Remote Control sessions can publish from Claude Code v2.1.281.
- Each artifact delete needs your confirmation.
