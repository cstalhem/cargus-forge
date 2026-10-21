# Research

Research a question with parallel researcher agents that write sourced, cross-checked notes, then compile them into one HTML report.

Works in Claude Code and Claude Cowork.

## Usage

```
/research:run <research question>
/research:run <research question> --deep
```

You can also just ask Claude to research something; the skill starts on its own.

1. Claude frames the question, picks a topic folder and splits the question into sub-topics: 2 to 3 for an overview, 4 to 5 with `--deep`.
2. It shows you the plan and waits for your OK. In an unattended run, such as a scheduled routine, it goes ahead and lists its choices in the reply.
3. One `researcher` agent per sub-topic searches the web in parallel and writes a cited note. Important claims are cross-checked against at least two sources, and a researcher stops on a claim once two independent sources agree. Each researcher uses at most 15 web searches and fetches combined.
4. If a key sub-topic comes back thin, Claude proposes one follow-up round on the gaps and runs it only after you approve. An unattended run never runs one; the gaps go to the report's open questions.
5. A `synthesizer` agent compiles the notes into one HTML report. It works only from the notes and cannot search the web. It checks the report with `check_report.py` and fixes every error before it finishes.
6. Claude publishes the report as a private Claude Artifact when a publishing tool is available.
7. If the working folder is a git repository with a GitHub remote, Claude commits the topic folder on a `research/<folder-name>-<date>` branch, opens a pull request against the default branch and merges it. Nothing outside the topic folder is committed.
8. Claude replies with the answer, confidence, caveats, open questions, and links to the report and the pull request.

Run it again on the same subject to extend or update the research. New sub-topics get new notes, gaps are amended in place, the report is rebuilt and republished to the same link, and the update is merged with a new pull request.

## What it writes

All files go in a topic folder in your working folder:

```
azure-landing-zones/
  azure-landing-zones.html          the report
  artifact-url.txt                  link to the published report
  research/
    2026-10-18-<sub-topic>.md       one note per sub-topic
```

## The report

The report is built to be read in about three minutes, with the detail one click away:

- The visible layer is a concise restatement of the question (at most 15 words), the answer (at most 60 words), 3 to 5 takeaways, and one block per finding: a heading that states the finding and 2 to 3 sentences. It aims for about 700 words.
- An overview has 3 to 5 findings, a deep dive up to 7. Depth adds findings; it does not lengthen the summary.
- Each finding expands to its evidence, tables, disagreements and caveats (about 300 words), with source markers.
- "Scope and method" (with the question as you asked it and the notes used), "Key terms" and the source index start collapsed. "Expand all" opens every block and closes them again.

`skills/run/scripts/check_report.py <report.html> [<topic-folder>]` checks a report. It warns when the visible layer runs over 1,000 words or the heading over 15, and fails on a leftover placeholder, an em dash, a finding without detail, a citation without a source, or a link to a missing note.

## Agents

| Agent | Model | Job |
|---|---|---|
| `researcher` | Sonnet | Researches one sub-topic and writes one note. |
| `synthesizer` | Opus | Merges sources, groups findings by theme and fills the report template. |

## Requirements and limits

- Web search and web fetch must be available to the researchers.
- The synthesizer runs `check_report.py` with `python3` (standard library only).
- Merging needs push access and `gh` or a GitHub tool. Without them, or outside a git repository, the research stays as local files. If your permission settings ask before merging, approve the merge when prompted.
- The report is built for Claude Artifacts. Opened as a local file, it renders in quirks mode (no doctype), and mermaid diagrams and fonts load from a CDN, so they need a network connection.
- Not yet verified in Cowork: that `model:` in plugin agents is honoured, that a publishing tool is available, and that `${CLAUDE_PLUGIN_ROOT}` expands in agent files. The skill passes template paths explicitly, so the last one only matters when an agent is used directly.
