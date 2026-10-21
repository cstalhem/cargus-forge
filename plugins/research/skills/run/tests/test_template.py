"""Structure tests for templates/report.html.

Parses the template with the standard library and checks the blocks the
synthesizer fills: the summary panel, the finding sections with their
collapsible evidence, and the blocks that start collapsed. The Expand all
toggle and the citation jumps run in a browser and are not covered here.

Run: python3 plugins/research/skills/run/tests/test_template.py
"""

import re
import unittest
from html.parser import HTMLParser
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parent.parent / "templates" / "report.html"

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
NOTE_LINK = re.compile(r"^notes\.html#\S+$")


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag = tag
        self.attrs = dict(attrs)
        self.parent = parent
        self.children = []
        self.text = []

    @property
    def classes(self):
        return (self.attrs.get("class") or "").split()

    def elements(self):
        return [c for c in self.children if isinstance(c, Node)]

    def walk(self):
        for child in self.elements():
            yield child
            yield from child.walk()

    def find_all(self, tag=None, cls=None, id=None):
        return [
            n
            for n in self.walk()
            if (tag is None or n.tag == tag)
            and (cls is None or cls in n.classes)
            and (id is None or n.attrs.get("id") == id)
        ]

    def find(self, **kw):
        found = self.find_all(**kw)
        return found[0] if found else None

    def text_content(self):
        parts = []
        for child in self.children:
            parts.append(child.text_content() if isinstance(child, Node) else child)
        return "".join(parts)


class TreeBuilder(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("#root", [], None)
        self.current = self.root

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.current)
        self.current.children.append(node)
        if tag not in VOID:
            self.current = node

    def handle_startendtag(self, tag, attrs):
        self.current.children.append(Node(tag, attrs, self.current))

    def handle_endtag(self, tag):
        node = self.current
        while node is not self.root and node.tag != tag:
            node = node.parent
        if node is not self.root:
            self.current = node.parent

    def handle_data(self, data):
        self.current.children.append(data)


def parse():
    builder = TreeBuilder()
    builder.feed(TEMPLATE.read_text(encoding="utf-8"))
    builder.close()
    return builder.root


class SummaryAndFindings(unittest.TestCase):
    """Scenario 1: summary panel and finding sections."""

    @classmethod
    def setUpClass(cls):
        cls.root = parse()
        cls.main = cls.root.find(tag="main", id="report")

    def test_main_exists(self):
        self.assertIsNotNone(self.main, "no <main id=\"report\">")

    def test_summary_panel_holds_question_lead_and_takeaways(self):
        panel = self.main.find(tag="section", id="summary")
        self.assertIsNotNone(panel, "no <section id=\"summary\">")
        self.assertIn("panel", panel.classes)
        self.assertIsNotNone(panel.find(tag="h1"), "summary panel has no <h1>")
        self.assertIsNotNone(panel.find(tag="p", cls="lead"), "summary panel has no p.lead")
        self.assertIsNotNone(panel.find(tag="ul", cls="takeaways"), "summary panel has no ul.takeaways")

    def test_finding_sections(self):
        findings = self.main.find_all(tag="section", cls="finding")
        self.assertTrue(findings, "no <section class=\"finding\">")
        for section in findings:
            sid = section.attrs.get("id")
            self.assertTrue(sid, "a finding section has no id")
            kids = section.elements()
            self.assertEqual([k.tag for k in kids].count("h2"), 1, f"#{sid}: needs one direct <h2>")
            self.assertEqual([k.tag for k in kids].count("p"), 1, f"#{sid}: needs one visible <p>")
            details = [k for k in kids if k.tag == "details"]
            self.assertEqual(len(details), 1, f"#{sid}: needs one direct <details>")
            evidence = details[0]
            self.assertNotIn("open", evidence.attrs, f"#{sid}: evidence <details> starts open")
            self.assertIsNotNone(evidence.find(tag="summary"), f"#{sid}: evidence has no <summary>")
            body = [k for k in evidence.elements() if k.tag != "summary"]
            self.assertGreater(len(body), 1, f"#{sid}: evidence holds no blocks besides the note link")
            notes = [a for a in evidence.find_all(tag="a") if a.text_content().strip() == "Full note"]
            self.assertEqual(len(notes), 1, f"#{sid}: evidence needs one \"Full note\" link")
            self.assertRegex(notes[0].attrs.get("href", ""), NOTE_LINK)

    def test_expand_all_button(self):
        button = self.root.find(tag="button", id="expand-all")
        self.assertIsNotNone(button, "no <button id=\"expand-all\">")
        self.assertEqual(button.text_content().strip(), "Expand all")


class CollapsedBlocks(unittest.TestCase):
    """Scenario 2: scope, key terms and sources start collapsed."""

    @classmethod
    def setUpClass(cls):
        cls.root = parse()
        cls.main = cls.root.find(tag="main", id="report")

    def collapsed(self, block_id, title):
        block = self.main.find(id=block_id)
        self.assertIsNotNone(block, f"no #{block_id}")
        self.assertEqual(block.tag, "details", f"#{block_id} is not a <details>")
        self.assertNotIn("open", block.attrs, f"#{block_id} starts open")
        summary = block.find(tag="summary")
        self.assertIsNotNone(summary, f"#{block_id} has no <summary>")
        self.assertIn(title, summary.text_content())
        return block

    def test_scope(self):
        scope = self.collapsed("scope", "Scope and method")
        self.assertIn("{{ORIGINAL_QUESTION}}", scope.text_content(), "scope has no original question slot")
        lists = [l for l in scope.find_all(tag="ul") if "notes-used" in l.classes]
        self.assertEqual(len(lists), 1, "scope needs one ul.notes-used")
        links = lists[0].find_all(tag="a")
        self.assertTrue(links, "ul.notes-used has no links")
        for a in links:
            self.assertRegex(a.attrs.get("href", ""), NOTE_LINK)

    def test_key_terms(self):
        self.collapsed("terms", "Key terms")

    def test_sources(self):
        sources = self.collapsed("sources", "Source index")
        self.assertTrue(sources.find_all(tag="li"), "source index has no entries")

    def test_no_details_starts_open(self):
        opened = [d.attrs.get("id") or d.parent.attrs.get("id") for d in self.root.find_all(tag="details") if "open" in d.attrs]
        self.assertEqual(opened, [], "these <details> start open")


if __name__ == "__main__":
    unittest.main()
