#!/usr/bin/env python3
"""Ambient theater service — Loop 1 of the Betondorp installation.

Owns the ball-in-slot sensor and the physical reactions only. It has NO network
surface and no knowledge of the game (see plan.md):

    ball inserted (idle -> present): open door, LEDs evening -> match, kickoff sound
    ball removed  (present -> idle): close door, LEDs match -> evening, no sound

Run on the Pi:        python3 service.py
Run on a laptop:      python3 service.py --fake
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config as cfg
from debounce import Debouncer

log = logging.getLogger("ambient")


def build_hardware(c: cfg.Config, fake: bool, fake_period: float):
    """Return (sensor, door, leds, sound). Real modules are imported only when
    not in fake mode, so a laptop without the RPi libraries can still run."""
    if fake:
        from hardware import fake as f

        return (
            f.FakeBallSensor(period=fake_period),
            f.FakeDoorServo(),
            f.FakeLeds(start=cfg.EVENING),
            f.FakeSoundPlayer(),
        )

    from hardware.ball_sensor import BallSensor
    from hardware.door_servo import DoorServo
    from hardware.leds import Leds
    from hardware.sound_player import SoundPlayer

    return (
        BallSensor(c.ball_sensor_pin, c.ball_active_low),
        DoorServo(c.servo_pin, c.door_closed_deg, c.door_open_deg),
        Leds(c.led_pin, c.led_count, c.led_brightness, start=cfg.EVENING),
        SoundPlayer(c.kickoff_wav),
    )


class AmbientController:
    def __init__(self, c: cfg.Config, sensor, door, leds, sound):
        self.c = c
        self.sensor = sensor
        self.door = door
        self.leds = leds
        self.sound = sound
        self._debounce = Debouncer(c.debounce_stable, initial=False)
        self._reaction: asyncio.Task | None = None

    async def _react(self, present: bool) -> None:
        """Apply the physical reaction for a (debounced) state change."""
        if present:
            log.info("ball INSERTED -> open door, lights to match, kickoff")
            self.sound.play()
            await asyncio.gather(
                self.door.open(self.c.door_move_time),
                self.leds.crossfade(cfg.MATCH, self.c.led_fade_time),
            )
        else:
            log.info("ball REMOVED -> close door, lights to evening")
            await asyncio.gather(
                self.door.close(self.c.door_move_time),
                self.leds.crossfade(cfg.EVENING, self.c.led_fade_time),
            )

    def _on_change(self, present: bool) -> None:
        # A fresh transition supersedes any in-flight reaction (visitor fidgeting).
        if self._reaction and not self._reaction.done():
            self._reaction.cancel()
        self._reaction = asyncio.create_task(self._react(present))

    async def run(self, stop: asyncio.Event) -> None:
        # Start from a known resting state.
        self.leds.set(cfg.EVENING)
        log.info("ambient service ready (idle: door closed, lights evening)")
        while not stop.is_set():
            changed = self._debounce.update(self.sensor.read(), time.monotonic())
            if changed is not None:
                self._on_change(changed)
            await asyncio.sleep(self.c.poll_interval)


async def _main_async(args) -> None:
    c = cfg.Config()
    sensor, door, leds, sound = build_hardware(c, args.fake, args.period)
    controller = AmbientController(c, sensor, door, leds, sound)

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in ("SIGINT", "SIGTERM"):
        try:
            import signal

            loop.add_signal_handler(getattr(signal, sig), stop.set)
        except (NotImplementedError, AttributeError):
            pass  # signal handlers unavailable (e.g. Windows) — Ctrl+C still raises

    try:
        await controller.run(stop)
    finally:
        if controller._reaction and not controller._reaction.done():
            controller._reaction.cancel()
        for dev in (door, sensor):
            closer = getattr(dev, "close_device", None) or getattr(dev, "close", None)
            if closer:
                closer()
        log.info("ambient service stopped")


def main() -> None:
    p = argparse.ArgumentParser(description="Betondorp ambient theater service")
    p.add_argument("--fake", action="store_true", help="run without GPIO (laptop dev)")
    p.add_argument("--period", type=float, default=4.0,
                   help="fake mode: seconds between simulated ball in/out")
    p.add_argument("-v", "--verbose", action="store_true", help="debug logging")
    args = p.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )
    try:
        asyncio.run(_main_async(args))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
