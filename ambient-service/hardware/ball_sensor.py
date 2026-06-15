"""Real ball-in-slot sensor: TCRT5000 IR reflective module (digital OUT).

The RPi library is imported lazily so this module imports cleanly on a laptop;
only constructing BallSensor touches the GPIO.
"""
from __future__ import annotations

import logging

log = logging.getLogger("ambient.ball")


class BallSensor:
    def __init__(self, pin: int, active_low: bool):
        from gpiozero import DigitalInputDevice

        self._active_low = active_low
        self._dev = DigitalInputDevice(pin, pull_up=None, active_state=True)
        log.info("ball sensor on GPIO%d (active_%s)", pin, "low" if active_low else "high")

    def read(self) -> bool:
        """True when the ball is present in the slot."""
        high = bool(self._dev.value)
        return (not high) if self._active_low else high

    def close(self) -> None:
        self._dev.close()
