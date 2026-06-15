"""Real kickoff sound: plays a WAV through ALSA's `aplay`, non-blocking.

ALSA's default dmix plugin mixes this with the Godot game audio on the shared
headset jack (see plan.md "Audio mixing"). Playing is fire-and-forget so it
never stalls the sensor loop.
"""
from __future__ import annotations

import logging
import os
import subprocess

log = logging.getLogger("ambient.sound")


class SoundPlayer:
    def __init__(self, wav_path: str):
        self._path = wav_path
        if not os.path.exists(wav_path):
            log.warning("kickoff WAV not found: %s", wav_path)

    def play(self) -> None:
        try:
            subprocess.Popen(
                ["aplay", "-q", self._path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            log.info("playing kickoff: %s", os.path.basename(self._path))
        except FileNotFoundError:
            log.error("`aplay` not available — cannot play kickoff sound")
