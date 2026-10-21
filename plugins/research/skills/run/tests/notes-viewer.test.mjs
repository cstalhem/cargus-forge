// Tests for templates/notes.html, the notes viewer published with the report.
//
// Runs cleanNote from the page's <script id="clean-note"> block without a
// browser, on the fixture notes and the note template, and checks the page
// shell the artifact needs. Fetching and rendering a note run in the
// published artifact and are not covered here.
//
// Run: node --test plugins/research/skills/run/tests/notes-viewer.test.mjs

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const here = (p) => fileURLToPath(new URL(p, import.meta.url));
const PAGE = readFileSync(here("../templates/notes.html"), "utf8");
const FIXTURE = readFileSync(here("fixtures/topic/research/running-costs.md"), "utf8");
const NOTE_TEMPLATE = readFileSync(here("../templates/research-note.md"), "utf8");

function loadCleanNote() {
  const block = /<script id="clean-note">([\s\S]*?)<\/script>/.exec(PAGE);
  assert.ok(block, 'notes.html has a <script id="clean-note"> block');
  const context = {};
  vm.runInNewContext(block[1], context);
  assert.equal(typeof context.cleanNote, "function", "the block defines cleanNote");
  return context.cleanNote;
}

const cleanNote = loadCleanNote();
const headings = (md) => md.split("\n").filter((l) => /^#{1,6} /.test(l));

test("drops the frontmatter, Assignment and Change log from the fixture note", () => {
  const out = cleanNote(FIXTURE);
  assert.ok(out.startsWith("# Running costs of air-source heat pumps"), out);
  assert.doesNotMatch(out, /^---$/m);
  assert.doesNotMatch(out, /^slug:/m);
  assert.doesNotMatch(out, /## Assignment|Task as delegated/);
  assert.doesNotMatch(out, /## Change log|Fixture created/);
  assert.deepEqual(headings(out), [
    "# Running costs of air-source heat pumps",
    "## Summary",
    "## Findings",
    "### Electricity use",
    "### Running cost",
    "## Conflicting or uncertain information",
    "## Sources",
    "## Comments",
    "## Decisions made",
    "## Recommended follow-up research",
  ]);
});

test("keeps every other section of a note built from the template", () => {
  assert.deepEqual(headings(cleanNote(NOTE_TEMPLATE)), [
    "# <Descriptive title of the research>",
    "## Summary",
    "## Findings",
    "### <Theme or sub-question 1>",
    "### <Theme or sub-question 2>",
    "## Conflicting or uncertain information",
    "## Sources",
    "## Comments",
    "## Decisions made",
    "## Recommended follow-up research",
  ]);
});

test("drops subsections of a removed section, up to the next section", () => {
  const md = "# T\n\n## Assignment\n\nTask\n\n### Detail\n\nMore\n\n## Summary\n\nKept\n";
  assert.equal(cleanNote(md), "# T\n\n## Summary\n\nKept\n");
});

test("ignores headings inside fenced code blocks", () => {
  const md = "# T\n\n## Findings\n\n```md\n## Change log\n```\n\nKept\n\n## Change log\n\nGone\n";
  assert.equal(cleanNote(md), "# T\n\n## Findings\n\n```md\n## Change log\n```\n\nKept\n");
});

test("leaves a note without frontmatter or removed sections unchanged", () => {
  const md = "# T\n\nIntro\n\n---\n\n## Summary\n\n- A\n";
  assert.equal(cleanNote(md), md);
});

test("handles CRLF line endings and a byte order mark", () => {
  const out = cleanNote("﻿" + FIXTURE.replace(/\n/g, "\r\n"));
  assert.ok(out.startsWith("# Running costs of air-source heat pumps"), out);
  assert.doesNotMatch(out, /Assignment|Change log|\r/);
});

test("the page is a full document with charset and viewport", () => {
  assert.match(PAGE, /^<!doctype html>/i);
  assert.match(PAGE, /<meta charset="utf-8"/i);
  assert.match(PAGE, /<meta name="viewport" content="width=device-width, initial-scale=1"/);
});

test("loads its libraries from cdnjs at exact versions", () => {
  const srcs = [...PAGE.matchAll(/<script src="([^"]+)"/g)].map((m) => m[1]);
  assert.ok(srcs.length > 0, "the page loads a markdown library");
  for (const src of srcs) {
    assert.match(src, /^https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/[\w.-]+\/\d+\.\d+\.\d+\//, src);
  }
});

test("fetches notes from notes/<note-file>.md and links back to the report", () => {
  assert.match(PAGE, /`notes\/\$\{encodeURIComponent\(name\)\}\.md`/);
  assert.match(PAGE, /<a class="back" href="index\.html">/);
});
