#!/usr/bin/env python3
"""Check a filled research report before it is published.

Warnings (exit 0): the visible layer runs over 1,000 words, or the <h1>
runs over 15 words. The visible layer is the text in <main> outside every
<details>.

Errors (exit 1): a leftover {{ placeholder, an em dash, a finding section
without a <details> block, a #src-N reference without a matching source,
or a notes.html#<x> link whose note <topic-folder>/research/<x>.md does
not exist.

Prints one line per problem and nothing when the report passes.
Standard library only.

Usage: check_report.py <report.html> [<topic-folder>]
The topic folder defaults to the folder the report is in.
"""

import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote

MAX_VISIBLE_WORDS = 1000
MAX_H1_WORDS = 15

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
# Tags that do not break a word: text on either side of them runs together.
INLINE = {"a", "abbr", "b", "cite", "code", "em", "i", "kbd", "mark", "q", "s", "small", "span", "strong", "sub", "sup", "time", "u", "var"}
SKIP_TEXT = {"script", "style", "template"}

EM_DASH = re.compile("\u2014|&mdash;|&#8212;|&#x2014;", re.IGNORECASE)
SRC_REF = re.compile(r"^#(src-\d+)$")
NOTE_LINK = re.compile(r"^notes\.html#(.*)$")


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag = tag
        self.attrs = dict(attrs)
        self.parent = parent
        self.children = []

    @property
    def classes(self):
        return (self.attrs.get("class") or "").split()

    def walk(self):
        for child in self.children:
            if isinstance(child, Node):
                yield child
                yield from child.walk()

    def find_all(self, tag):
        return [n for n in self.walk() if n.tag == tag]

    def text(self, skip_details=False):
        """Text of this node, with a space wherever a block tag starts or ends."""
        parts = []
        for child in self.children:
            if not isinstance(child, Node):
                parts.append(child)
            elif child.tag in SKIP_TEXT or (skip_details and child.tag == "details"):
                parts.append(" ")
            elif child.tag in INLINE:
                parts.append(child.text(skip_details))
            else:
                parts.append(" " + child.text(skip_details) + " ")
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


def parse(html):
    builder = TreeBuilder()
    builder.feed(html)
    builder.close()
    return builder.root


def word_count(text):
    return len(text.split())


def check(html, topic_folder):
    """Return (warnings, errors), each a list of messages."""
    warnings, errors = [], []
    root = parse(html)
    main = next(iter(root.find_all("main")), None)

    # Warnings: length targets.
    if main is not None:
        visible = word_count(main.text(skip_details=True))
        if visible > MAX_VISIBLE_WORDS:
            warnings.append(f"visible layer is {visible} words (target at most {MAX_VISIBLE_WORDS})")
    h1 = next(iter((main or root).find_all("h1")), None)
    if h1 is not None:
        words = word_count(h1.text())
        if words > MAX_H1_WORDS:
            warnings.append(f"<h1> is {words} words (target at most {MAX_H1_WORDS})")

    # Errors: placeholders and em dashes, by line.
    for number, line in enumerate(html.splitlines(), 1):
        if "{{" in line:
            errors.append(f"line {number}: leftover placeholder: {line.strip()[:80]}")
        if EM_DASH.search(line):
            errors.append(f"line {number}: em dash: {line.strip()[:80]}")

    # Errors: findings without evidence.
    for section in root.find_all("section"):
        if "finding" in section.classes and not section.find_all("details"):
            name = section.attrs.get("id") or "(no id)"
            errors.append(f"finding #{name} has no <details> block")

    # Errors: citations and note links that point nowhere.
    ids = {n.attrs["id"] for n in root.walk() if n.attrs.get("id")}
    research = Path(topic_folder) / "research"
    missing_srcs, missing_notes = [], []
    for a in root.find_all("a"):
        href = (a.attrs.get("href") or "").strip()
        src = SRC_REF.match(href)
        if src and src.group(1) not in ids and src.group(1) not in missing_srcs:
            missing_srcs.append(src.group(1))
        note = NOTE_LINK.match(href)
        if note:
            name = unquote(note.group(1))
            if not (name and (research / f"{name}.md").is_file()) and name not in missing_notes:
                missing_notes.append(name)
    for src in missing_srcs:
        errors.append(f"#{src} is cited but no source has id=\"{src}\"")
    for name in missing_notes:
        errors.append(f"notes.html#{name} links to a missing note: {research / (name + '.md')}")

    return warnings, errors


def main(argv):
    if len(argv) not in (2, 3):
        print("usage: check_report.py <report.html> [<topic-folder>]", file=sys.stderr)
        return 2
    report = Path(argv[1])
    topic_folder = Path(argv[2]) if len(argv) == 3 else report.parent
    try:
        html = report.read_text(encoding="utf-8")
    except OSError as e:
        print(f"ERROR: cannot read {report}: {e.strerror}")
        return 1
    warnings, errors = check(html, topic_folder)
    for message in warnings:
        print(f"WARNING: {message}")
    for message in errors:
        print(f"ERROR: {message}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
