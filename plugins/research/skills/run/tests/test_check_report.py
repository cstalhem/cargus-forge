"""Tests for scripts/check_report.py.

Runs the checker as a command on the fixtures. The warning cases and the
single-failure cases are built from the passing fixture, so each one
differs from a known-good report in one place.

Run: python3 -m unittest discover -s plugins/research/skills/run/tests -p "test_check_report.py"
"""

import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TESTS = Path(__file__).resolve().parent
SCRIPT = TESTS.parent / "scripts" / "check_report.py"
FIXTURES = TESTS / "fixtures"
PASS = FIXTURES / "pass.html"
FAIL = FIXTURES / "fail.html"
TOPIC = FIXTURES / "topic"

H1 = "Do air-source heat pumps work in Nordic winters?"
LEAD = "Yes. Cold-climate models keep heating efficiently well below freezing"
EVIDENCE = "Measured household data shows"


def run(report, *topic):
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(report), *map(str, topic)],
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout, result.stderr


def words(n):
    return " ".join(["word"] * n)


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)

    def variant(self, old, new):
        """The passing fixture with one change, written to a temp file."""
        html = PASS.read_text(encoding="utf-8")
        self.assertIn(old, html)
        path = self.tmp / "report.html"
        path.write_text(html.replace(old, new, 1), encoding="utf-8")
        return path


class Passing(Base):
    def test_pass_fixture_is_silent(self):
        code, out, err = run(PASS, TOPIC)
        self.assertEqual((code, out, err), (0, "", ""))

    def test_topic_folder_defaults_to_report_folder(self):
        shutil.copytree(TOPIC, self.tmp / "topic")
        shutil.copy(PASS, self.tmp / "topic" / "topic.html")
        self.assertEqual(run(self.tmp / "topic" / "topic.html"), (0, "", ""))

    def test_h1_at_the_limit_is_silent(self):
        report = self.variant(H1, words(15))
        self.assertEqual(run(report, TOPIC), (0, "", ""))

    def test_words_inside_details_do_not_count(self):
        report = self.variant(EVIDENCE, words(2000) + " " + EVIDENCE)
        self.assertEqual(run(report, TOPIC), (0, "", ""))


class Warnings(Base):
    """Scenario 1: over-length reports warn and exit 0."""

    def assertOnlyWarning(self, report, fragment):
        code, out, _ = run(report, TOPIC)
        self.assertEqual(code, 0, out)
        lines = out.splitlines()
        self.assertEqual(len(lines), 1, out)
        self.assertTrue(lines[0].startswith("WARNING:"), out)
        self.assertIn(fragment, lines[0])

    def test_visible_layer_over_1000_words(self):
        report = self.variant(LEAD, words(1000) + " " + LEAD)
        self.assertOnlyWarning(report, "visible layer")

    def test_h1_over_15_words(self):
        report = self.variant(H1, words(16))
        self.assertOnlyWarning(report, "<h1> is 16 words")


class Failures(Base):
    """Scenario 2: broken reports exit non-zero and name each failure."""

    def test_fail_fixture_names_each_failure(self):
        code, out, _ = run(FAIL, TOPIC)
        self.assertNotEqual(code, 0)
        errors = [l for l in out.splitlines() if l.startswith("ERROR:")]
        expected = {
            "placeholder": "leftover placeholder: <p class=\"lead\">{{LEAD_PARAGRAPH}}",
            "em dash": "em dash:",
            "finding": "finding #s2 has no <details> block",
            "source": "#src-9 is cited",
            "note": "notes.html#missing-note links to a missing note",
        }
        for name, fragment in expected.items():
            with self.subTest(name):
                self.assertEqual(sum(fragment in e for e in errors), 1, out)
        self.assertEqual(len(errors), len(expected), out)
        self.assertNotIn("src-1 ", out)
        self.assertNotIn("cold-climate-performance", out)

    def assertOnlyError(self, report, fragment):
        code, out, _ = run(report, TOPIC)
        self.assertEqual(code, 1, out)
        lines = out.splitlines()
        self.assertEqual(len(lines), 1, out)
        self.assertTrue(lines[0].startswith("ERROR:"), out)
        self.assertIn(fragment, lines[0])

    def test_placeholder(self):
        self.assertOnlyError(self.variant(LEAD, "{{LEAD_PARAGRAPH}}"), "leftover placeholder")

    def test_em_dash_entity(self):
        self.assertOnlyError(self.variant("Yes. Cold", "Yes &mdash; cold"), "em dash")

    def test_finding_without_details(self):
        html = re.sub(r'(<section class="finding" id="s2">.*?)<details.*?</details>', r"\1", PASS.read_text(encoding="utf-8"), count=1, flags=re.S)
        report = self.tmp / "report.html"
        report.write_text(html, encoding="utf-8")
        self.assertOnlyError(report, "finding #s2 has no <details> block")

    def test_source_reference_without_source(self):
        report = self.variant('<li id="src-2">', '<li id="src-3">')
        self.assertOnlyError(report, "#src-2 is cited")

    def test_note_link_to_missing_note(self):
        report = self.variant('notes.html#running-costs">Full note', 'notes.html#running-cost">Full note')
        self.assertOnlyError(report, "notes.html#running-cost links to a missing note")

    def test_missing_report(self):
        code, out, _ = run(self.tmp / "nope.html", TOPIC)
        self.assertEqual(code, 1)
        self.assertIn("cannot read", out)


if __name__ == "__main__":
    unittest.main()
