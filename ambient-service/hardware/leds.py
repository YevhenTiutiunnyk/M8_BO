"""Real house/street lighting: WS2812B NeoPixel strip.

Uses Adafruit's neopixel + blinka stack. Imported lazily so this module loads
on a laptop. Crossfades between scene colours over a short duration.
"""
from __future__ import annotations

import asyncio
import logging

log = logging.getLogger("ambient.leds")

Color = tuple[int, int, int]
_STEPS = 20


def _lerp(a: Color, b: Color, t: float) -> Color:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))  # type: ignore[return-value]


class Leds:
    def __init__(self, pin: int, count: int, brightness: float, start: Color = (0, 0, 0)):
        import board
        import neopixel

        self._np = neopixel.NeoPixel(
            getattr(board, f"D{pin}"), count, brightness=brightness, auto_write=False
        )
        self._current: Color = start
        self.set(start)
        log.info("neopixels on GPIO%d (%d px, brightness=%.2f)", pin, count, brightness)

    def set(self, color: Color) -> None:
        self._np.fill(color)
        self._np.show()
        self._current = color

    async def crossfade(self, target: Color, duration: float) -> None:
        start = self._current
        for i in range(1, _STEPS + 1):
            self.set(_lerp(start, target, i / _STEPS))
            await asyncio.sleep(duration / _STEPS)
        log.info("leds -> %s", target)
