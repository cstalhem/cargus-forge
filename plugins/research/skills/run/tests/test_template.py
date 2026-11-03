"""Structure tests for templates/report.html.

Parses the template with the standard library and checks the blocks the
synthesizer fills: the summary panel, the finding sections with their
collapsible evidence, and the blocks that start collapsed. The Expand all
toggle and the citation jumps run in a browser and are not covered here.

Run: python3 plugins/research/skills/run/tests/test_template.py
"""

import re
import sys
import unittest
from pathlib import Path

RUN = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RUN / "scripts"))

import check_report  # noqa: E402

TEMPLATE = RUN / "templates" / "report.html"

NOTE_LINK = re.compile(r"^notes\.html#\S+$")


def find_all(node, tag=None, cls=None, id=None):
    return [
        n
        for n in node.walk()
        if (tag is None or n.tag == tag)
        and (cls is None or cls in n.classes)
        and (id is None or n.attrs.get("id") == id)
    ]


def find(node, **kw):
    found = find_all(node, **kw)
    return found[0] if found else None


def parse():
    return check_report.parse(TEMPLATE.read_text(encoding="utf-8"))


class SummaryAndFindings(unittest.TestCase):
    """Scenario 1: summary panel and finding sections."""

    @classmethod
    def setUpClass(cls):
        cls.root = parse()
        cls.main = find(cls.root, tag="main", id="report")

    def test_main_exists(self):
        self.assertIsNotNone(self.main, "no <main id=\"report\">")

    def test_summary_panel_holds_question_lead_and_takeaways(self):
        panel = find(self.main, tag="section", id="summary")
        self.assertIsNotNone(panel, "no <section id=\"summary\">")
        self.assertIn("panel", panel.classes)
        self.assertIsNotNone(find(panel, tag="h1"), "summary panel has no <h1>")
        self.assertIsNotNone(find(panel, tag="p", cls="lead"), "summary panel has no p.lead")
        self.assertIsNotNone(find(panel, tag="ul", cls="takeaways"), "summary panel has no ul.takeaways")

    def test_finding_sections(self):
        findings = find_all(self.main, tag="section", cls="finding")
        self.assertTrue(findings, "no <section class=\"finding\">")
        for section in findings:
            sid = section.attrs.get("id")
            self.assertTrue(sid, "a finding section has no id")
            kids = [c for c in section.children if isinstance(c, check_report.Node)]
            self.assertEqual([k.tag for k in kids].count("h2"), 1, f"#{sid}: needs one direct <h2>")
            self.assertEqual([k.tag for k in kids].count("p"), 1, f"#{sid}: needs one visible <p>")
            details = [k for k in kids if k.tag == "details"]
            self.assertEqual(len(details), 1, f"#{sid}: needs one direct <details>")
            evidence = details[0]
            self.assertNotIn("open", evidence.attrs, f"#{sid}: evidence <details> starts open")
            self.assertIsNotNone(find(evidence, tag="summary"), f"#{sid}: evidence has no <summary>")
            body = [k for k in evidence.children if isinstance(k, check_report.Node) and k.tag != "summary"]
            self.assertGreater(len(body), 1, f"#{sid}: evidence holds no blocks besides the note link")
            notes = [a for a in find_all(evidence, tag="a") if a.text().strip() == "Full note"]
            self.assertEqual(len(notes), 1, f"#{sid}: evidence needs one \"Full note\" link")
            self.assertRegex(notes[0].attrs.get("href", ""), NOTE_LINK)

    def test_expand_all_button(self):
        button = find(self.root, tag="button", id="expand-all")
        self.assertIsNotNone(button, "no <button id=\"expand-all\">")
        self.assertEqual(button.text().strip(), "Expand all")


class CollapsedBlocks(unittest.TestCase):
    """Scenario 2: scope, key terms and sources start collapsed."""

    @classmethod
    def setUpClass(cls):
        cls.root = parse()
        cls.main = find(cls.root, tag="main", id="report")

    def collapsed(self, block_id, title):
        block = find(self.main, id=block_id)
        self.assertIsNotNone(block, f"no #{block_id}")
        self.assertEqual(block.tag, "details", f"#{block_id} is not a <details>")
        self.assertNotIn("open", block.attrs, f"#{block_id} starts open")
        summary = find(block, tag="summary")
        self.assertIsNotNone(summary, f"#{block_id} has no <summary>")
        self.assertIn(title, summary.text())
        return block

    def test_scope(self):
        scope = self.collapsed("scope", "Scope and method")
        self.assertIn("{{ORIGINAL_QUESTION}}", scope.text(), "scope has no original question slot")
        lists = [l for l in find_all(scope, tag="ul") if "notes-used" in l.classes]
        self.assertEqual(len(lists), 1, "scope needs one ul.notes-used")
        links = find_all(lists[0], tag="a")
        self.assertTrue(links, "ul.notes-used has no links")
        for a in links:
            self.assertRegex(a.attrs.get("href", ""), NOTE_LINK)

    def test_key_terms(self):
        self.collapsed("terms", "Key terms")

    def test_sources(self):
        sources = self.collapsed("sources", "Source index")
        self.assertTrue(find_all(sources, tag="li"), "source index has no entries")

    def test_no_details_starts_open(self):
        opened = [d.attrs.get("id") or d.parent.attrs.get("id") for d in find_all(self.root, tag="details") if "open" in d.attrs]
        self.assertEqual(opened, [], "these <details> start open")


if __name__ == "__main__":
    unittest.main()
