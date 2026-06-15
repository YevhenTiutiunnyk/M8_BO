"""Unit tests for the pure debounce logic. Run: python3 -m unittest -v
(from the ambient-service directory) — no third-party dependencies."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from debounce import Debouncer


class TestDebouncer(unittest.TestCase):
    def test_no_change_when_stable_at_initial(self):
        d = Debouncer(0.15, initial=False)
        self.assertIsNone(d.update(False, 0.0))
        self.assertIsNone(d.update(False, 1.0))
        self.assertFalse(d.state)

    def test_commits_after_stable_time(self):
        d = Debouncer(0.15, initial=False)
        self.assertIsNone(d.update(True, 0.00))   # candidate starts
        self.assertIsNone(d.update(True, 0.10))   # not stable long enough
        self.assertTrue(d.update(True, 0.16))     # >= 0.15 -> commit
        self.assertTrue(d.state)

    def test_glitch_shorter_than_stable_time_ignored(self):
        d = Debouncer(0.15, initial=False)
        self.assertIsNone(d.update(True, 0.00))
        self.assertIsNone(d.update(True, 0.05))
        self.assertIsNone(d.update(False, 0.06))  # bounced back before commit
        self.assertIsNone(d.update(False, 0.30))
        self.assertFalse(d.state)

    def test_only_one_change_event_per_transition(self):
        d = Debouncer(0.15, initial=False)
        d.update(True, 0.0)
        self.assertTrue(d.update(True, 0.2))      # commits once
        self.assertIsNone(d.update(True, 0.4))    # no repeat event
        self.assertIsNone(d.update(True, 5.0))

    def test_round_trip(self):
        d = Debouncer(0.15, initial=False)
        d.update(True, 0.0)
        self.assertTrue(d.update(True, 0.2))      # -> present
        d.update(False, 0.3)
        self.assertFalse(d.update(False, 0.5))    # -> idle again
        self.assertFalse(d.state)


if __name__ == "__main__":
    unittest.main()
