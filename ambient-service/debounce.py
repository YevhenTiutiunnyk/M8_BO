"""Pure debounce logic — no hardware, no I/O, fully unit-testable.

A noisy boolean (the ball sensor) only counts as a real transition after it has
held the new value for `stable_time` seconds. Visitors fidget with the ball, so
without this we'd flap the door and LEDs.
"""
from __future__ import annotations

from typing import Optional


class Debouncer:
    def __init__(self, stable_time: float, initial: bool = False):
        self.stable_time = stable_time
        self.state = initial            # last committed (debounced) value
        self._candidate = initial       # value currently being timed
        self._since: Optional[float] = None

    def update(self, raw: bool, now: float) -> Optional[bool]:
        """Feed a raw reading at time `now` (monotonic seconds).

        Returns the new committed state if it just changed this call, else None.
        """
        if raw == self.state:
            # Back to the committed value — cancel any pending change.
            self._candidate = raw
            self._since = None
            return None

        if raw != self._candidate or self._since is None:
            # A new differing reading starts the stability clock.
            self._candidate = raw
            self._since = now
            return None

        if now - self._since >= self.stable_time:
            self.state = raw
            self._since = None
            return self.state

        return None
