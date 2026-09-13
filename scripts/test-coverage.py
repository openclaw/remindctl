#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class CoverageReportTests(unittest.TestCase):
    def report(self, entries, minimum=90):
        files = [
            {"filename": name, "summary": {"lines": {"covered": covered, "count": count}}}
            for name, covered, count in entries
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "coverage.json"
            path.write_text(json.dumps({"data": [{"files": files}]}), encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(Path(__file__).with_name("report-coverage.py")),
                 str(path), "/Sources/RemindCore/", "EventKitStore\\.swift", str(minimum)],
                capture_output=True, text=True, check=False,
            )

    def test_passes_at_threshold_and_preserves_scope(self):
        result = self.report([
            ("/Sources/RemindCore/Models.swift", 90, 100),
            ("/Sources/RemindCore/EventKitStore.swift", 0, 1000),
            ("/Sources/remindctl/CommandRouter.swift", 0, 1000),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("90.0% (90/100)", result.stdout)

    def test_weights_lines_and_fails_below_threshold(self):
        result = self.report([
            ("/Sources/RemindCore/Small.swift", 1, 1),
            ("/Sources/RemindCore/Large.swift", 89, 100),
        ])
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("90/101", result.stdout)

    def test_rejects_empty_scope(self):
        result = self.report([("/Sources/remindctl/CommandRouter.swift", 100, 100)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("No files matched", result.stderr)


if __name__ == "__main__":
    unittest.main()
