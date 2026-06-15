"""Real front-door actuator: SG90 micro servo via gpiozero.

Moves gradually between closed and open angles so the door swings over ~1 s
rather than snapping. RPi library imported lazily.
"""
from __future__ import annotations

import asyncio
import logging

log = logging.getLogger("ambient.door")

_STEPS = 25  # interpolation steps for a smooth sweep


class DoorServo:
    def __init__(self, pin: int, closed_deg: float, open_deg: float):
        from gpiozero import AngularServo

        self._closed = closed_deg
        self._open = open_deg
        lo, hi = sorted((closed_deg, open_deg))
        self._servo = AngularServo(pin, min_angle=lo, max_angle=hi)
        self._servo.angle = closed_deg
        self._angle = closed_deg
        log.info("door servo on GPIO%d (closed=%.0f open=%.0f)", pin, closed_deg, open_deg)

    async def open(self, duration: float) -> None:
        await self._move_to(self._open, duration)

    async def close(self, duration: float) -> None:
        await self._move_to(self._closed, duration)

    async def _move_to(self, target: float, duration: float) -> None:
        start = self._angle
        for i in range(1, _STEPS + 1):
            self._angle = start + (target - start) * i / _STEPS
            self._servo.angle = self._angle
            await asyncio.sleep(duration / _STEPS)

    def close_device(self) -> None:
        self._servo.close()
