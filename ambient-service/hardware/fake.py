"""Fake hardware for laptop development (`service.py --fake`).

The fake sensor toggles the ball in/out on a fixed schedule; the fake actuators
just log what the real door/LEDs/sound would do. This lets the whole state
machine, debounce, and timing be exercised without a Raspberry Pi.
"""
from __future__ import annotations

import asyncio
import logging
import time

log = logging.getLogger("ambient.fake")

Color = tuple[int, int, int]


class FakeBallSensor:
    """Pretends a visitor inserts/removes the ball every `period` seconds."""

    def __init__(self, period: float = 4.0, clock=time.monotonic):
        self._period = period
        self._clock = clock
        self._start = clock()

    def read(self) -> bool:
        elapsed = self._clock() - self._start
        return int(elapsed // self._period) % 2 == 1

    def close(self) -> None:
        pass


class FakeDoorServo:
    async def open(self, duration: float) -> None:
        log.info("[door] opening over %.1fs", duration)
        await asyncio.sleep(duration)
        log.info("[door] OPEN")

    async def close(self, duration: float) -> None:
        log.info("[door] closing over %.1fs", duration)
        await asyncio.sleep(duration)
        log.info("[door] CLOSED")

    def close_device(self) -> None:
        pass


class FakeLeds:
    def __init__(self, start: Color = (0, 0, 0)):
        self._current = start

    def set(self, color: Color) -> None:
        self._current = color

    async def crossfade(self, target: Color, duration: float) -> None:
        log.info("[leds] crossfade %s -> %s over %.1fs", self._current, target, duration)
        await asyncio.sleep(duration)
        self._current = target


class FakeSoundPlayer:
    def play(self) -> None:
        log.info("[sound] playing kickoff whistle")
