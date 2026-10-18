---
name: run
description: Research a question in depth and produce a sourced HTML report. Splits the question into sub-topics, runs parallel researcher agents that each write a cross-checked note, then has a synthesizer agent compile the notes into one report, publishes it as an artifact, and merges the research into the default branch with a pull request. Also continues or updates earlier research in an existing topic folder.
when_to_use: When the user asks to research, investigate or compare something and wants a sourced write-up or report, or asks to continue, extend or update earlier research.
argument-hint: <research question> [--deep]
---

# Research

You orchestrate the research. You plan the work, delegate it to the plugin's agents, check what comes back, publish the report, merge the research into the default branch and report to the user. You do not research or write the report yourself.

- **`researcher`** (`research:researcher`): researches one sub-topic and writes one note to `<topic-folder>/research/`.
- **`synthesizer`** (`research:synthesizer`): compiles the notes into the report.

Templates the agents need, passed to them by absolute path:

- Note template: `${CLAUDE_SKILL_DIR}/templates/research-note.md`
- Report template: `${CLAUDE_SKILL_DIR}/templates/report.html`

Request: $ARGUMENTS

## 1. Frame the research

1. Work out the research question from the request. If there is none, ask the user for it.
2. Pick the depth: `Deep dive` if the user passed `--deep` or asked for depth, otherwise `Overview`.
3. Pick the topic folder: a short kebab-case slug of the subject in the working folder, e.g. `azure-landing-zones/`. If a folder for the subject already exists, use it.
4. Set the report path to `<topic-folder>/<folder-name>.html`, e.g. `azure-landing-zones/azure-landing-zones.html`. If the folder already has a report under another name, keep that name.
5. If the topic folder already has notes in `research/` or a report, read them first. This is a continuation: plan only what is missing or outdated, and amend existing notes rather than duplicating them.

## 2. Plan the sub-topics

Split the question into sub-topics that can be researched independently and together answer it.

- `Overview`: 2 to 4 sub-topics. `Deep dive`: 4 to 7.
- Each sub-topic is one clear task with its own scope. Avoid overlap; two researchers covering the same ground waste effort and produce conflicting source lists.
- Give each sub-topic its note file: `YYYY-MM-DD-<slug>.md` with today's date (run `date +%F` if you do not know it) and a short kebab-case slug, unique within `research/`. When amending, use the existing note's file.
- Note any context the user gave (constraints, links, files, their situation). Each researcher gets the parts that matter for its task.

Show the user the plan: research question, topic folder, depth and the sub-topics, one line each. Say whether the research will be merged into the default branch at the end (step 7). Ask them to confirm or adjust before delegating. Skip the confirmation if the user already said to go ahead without one.

## 3. Delegate the research

Start one `researcher` per sub-topic, all in parallel. Give each one:

- **Task:** the sub-topic, written so it stands alone. The researcher has not seen this conversation.
- **Complementary information:** the overall research question, the relevant user context, and what the other researchers cover, so it stays in its lane.
- **Topic folder:** the folder from step 1.
- **Note file:** the file name from step 2.
- **Note template:** the absolute path above.
- **Existing note:** when amending, the path to the note to update.

Never give two researchers the same note in one round. Each would overwrite the other's changes.

## 4. Review the notes

When the researchers report back:

1. Check each `status` and `confidence`, and skim the notes.
2. If a sub-topic the answer depends on is `blocked` or `partial`, or a key claim rests on a single source, run one follow-up round: amend the existing note with a researcher focused on the gap. Combine several gaps in one note into one task, so each note gets at most one researcher. Run one round at most unless the user asks for more.
3. Leave other follow-ups for the report's open questions.

## 5. Delegate the report

Start one `synthesizer` with:

- **Topic folder** and **research question**.
- **Report path:** from step 1.
- **Report template:** the absolute path above.
- **Depth.**
- **Existing report:** say so if the report path already exists, so it is rebuilt in place.

## 6. Publish the report

The report template is built to be published as a Claude Artifact. If you have a tool that publishes an HTML file as an artifact, publish the report with it. If you have none, skip this step; the report file still works when opened in a browser.

1. Read the whole report at the report path first. Publishing shares it, so check that it is the report you expect and has no leftover `{{` placeholders.
2. Look for `<topic-folder>/artifact-url.txt`. If it exists, the report was published before: update that artifact by its URL so the link stays the same. Otherwise publish a new artifact.
3. Publish with the report's `<title>` as its name, the sentence from its `description` meta tag as the description, and a generic icon such as `report`.
4. For a new artifact, write its URL to `<topic-folder>/artifact-url.txt`, one line, nothing else.

If publishing fails, keep going and tell the user why in your reply.

## 7. Merge the research into the default branch

Add the research to the repository with a pull request and merge it, so the default branch always holds the latest research. Do this only when the working folder is a git repository with a GitHub remote and you can push and create pull requests (with `gh` or a GitHub tool). Otherwise skip this step and say so in your reply.

Follow the repository's own conventions for branch names, commit messages and merging if it documents any. Otherwise:

1. Note the current branch so you can return to it.
2. Fetch the default branch and create a new branch from it: `research/<folder-name>-<YYYY-MM-DD>`.
3. Stage only the topic folder (`git add <topic-folder>`). Never stage other changes in the working folder; they are not part of this research.
4. Commit with a message that names the research question, e.g. `Add research: <research question>` or `Update research: <research question>`.
5. Push the branch and open a pull request against the default branch. In the description, give the answer in two or three sentences, the confidence, the notes added or amended, and the artifact link if there is one.
6. Merge the pull request with the repository's default merge method, then delete the branch.
7. Switch back to the branch from step 1. If that is the default branch, pull so it includes the merge.

If any step fails (a conflict, a rejected push, a merge that needs approval), stop there. Leave the branch and pull request as they are and tell the user what failed and what is left to do.

## 8. Report to the user

Reply briefly with:

- The link to the published report, if you published it.
- The link to the merged pull request, or why the research was not merged.
- The path to the report and the research notes.
- The answer to the research question in two or three sentences.
- Overall confidence and the main caveats.
- Open questions worth another round, from the synthesizer's gaps. Offer to run it.

## Rules

- Only the agents write research notes and reports. The only file you write is `artifact-url.txt`.
- Commit only the topic folder. Never commit, stash or discard anything else in the working folder.
- Never invent findings to fill a gap. Gaps go to the user as open questions.
- If an agent reports a missing template or topic folder, fix the input and run it again. Do not work around it.
