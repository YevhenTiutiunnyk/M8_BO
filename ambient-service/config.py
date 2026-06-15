"""Configuration for the ambient theater service.

All hardware pins, colours, and timings live here so the wiring/calibration can
change without touching logic. Values can be overridden with environment
variables (handy on the Pi without editing code). See docs/wiring.md for pinout.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field


def _env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, default))


def _env_float(name: str, default: float) -> float:
    return float(os.environ.get(name, default))


def _env_str(name: str, default: str) -> str:
    return os.environ.get(name, default)


# RGB colours (0-255 per channel).
EVENING = (60, 28, 10)     # warm, dim — house at rest
MATCH = (255, 70, 50)      # bright, Ajax-tinted — ball is in, "kickoff"


@dataclass
class Config:
    # --- Ball sensor (TCRT5000 IR reflective, digital out) ---
    ball_sensor_pin: int = field(default_factory=lambda: _env_int("BALL_SENSOR_PIN", 17))
    # The TCRT5000 module pulls its OUT low when it detects the ball. Set False
    # if your module/wiring is active-high.
    ball_active_low: bool = field(default_factory=lambda: _env_str("BALL_ACTIVE_LOW", "1") == "1")

    # --- Door servo (SG90) ---
    servo_pin: int = field(default_factory=lambda: _env_int("SERVO_PIN", 18))
    door_closed_deg: float = field(default_factory=lambda: _env_float("DOOR_CLOSED_DEG", 0.0))
    door_open_deg: float = field(default_factory=lambda: _env_float("DOOR_OPEN_DEG", 90.0))

    # --- NeoPixel strip (WS2812B) ---
    led_pin: int = field(default_factory=lambda: _env_int("LED_PIN", 21))  # data pin (GPIO)
    led_count: int = field(default_factory=lambda: _env_int("LED_COUNT", 30))
    led_brightness: float = field(default_factory=lambda: _env_float("LED_BRIGHTNESS", 0.6))

    # --- Sound ---
    kickoff_wav: str = field(default_factory=lambda: _env_str(
        "KICKOFF_WAV", os.path.join(os.path.dirname(__file__), "assets", "kickoff.wav")))

    # --- Timings (seconds) ---
    debounce_stable: float = field(default_factory=lambda: _env_float("DEBOUNCE_STABLE", 0.15))
    poll_interval: float = field(default_factory=lambda: _env_float("POLL_INTERVAL", 0.02))
    door_move_time: float = field(default_factory=lambda: _env_float("DOOR_MOVE_TIME", 1.0))
    led_fade_time: float = field(default_factory=lambda: _env_float("LED_FADE_TIME", 0.5))
