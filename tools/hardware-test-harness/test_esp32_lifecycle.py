"""
Unit tests for Hardware Test Harness runner.
"""

import unittest
from harness import HardwareTestHarness


class TestHardwareTestHarness(unittest.TestCase):
    def test_harness_detects_pending_when_no_hardware(self):
        harness = HardwareTestHarness()
        results = harness.run_all()

        self.assertEqual(len(results), 13)
        for name, status in results.items():
            self.assertIn(status, ["PENDING", "PASS"])


if __name__ == "__main__":
    unittest.main()
