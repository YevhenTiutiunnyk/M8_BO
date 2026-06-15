# ambient-service — Loop 1 (ball → door / lights / sound)

The autonomous "wake the house up" loop of the Betondorp installation. A visitor
drops a football into the slot; the front door opens, the NeoPixels go from
"evening" to "match", and a kickoff whistle plays. Pulling the ball out reverses
it (no sound). **It has no network and no knowledge of the game** — see
`../plan.md`. The game and this service share the Pi but never talk.

```
ball inserted (idle -> present): open door, LEDs evening -> match, kickoff sound
ball removed  (present -> idle): close door, LEDs match -> evening, no sound
```

A change only counts once the sensor is stable for `debounce_stable` (150 ms),
so visitor fidgeting doesn't flap the door/lights.

## Run

Laptop (no hardware — fakes log what would happen, ball auto-toggles):
```sh
python3 service.py --fake            # toggles every 4 s
python3 service.py --fake --period 2 # faster
```

Raspberry Pi:
```sh
pip install -r requirements.txt      # gpiozero, neopixel, blinka (+ alsa-utils)
python3 service.py
```

## Tests
```sh
python3 -m unittest discover -s tests -v
```
Covers the pure debounce logic (the only non-hardware logic worth testing).

## Layout
- `service.py` — asyncio entry point + state machine (`idle ↔ ball_present`).
- `config.py` — pins, scene colours, timings; all overridable via env vars.
- `debounce.py` — pure, hardware-free debounce (unit-tested).
- `hardware/ball_sensor.py` `door_servo.py` `leds.py` `sound_player.py` — real
  drivers; RPi libraries are imported lazily so the files load on a laptop.
- `hardware/fake.py` — fakes for `--fake` mode.
- `assets/kickoff.wav` — **placeholder** whistle (replace with the real one).

## Wiring (defaults — override via env, see `config.py`)
| Device | Pin | Env var |
|---|---|---|
| TCRT5000 ball sensor OUT | GPIO17 | `BALL_SENSOR_PIN`, `BALL_ACTIVE_LOW` |
| SG90 door servo signal | GPIO18 | `SERVO_PIN`, `DOOR_OPEN_DEG`, `DOOR_CLOSED_DEG` |
| WS2812B data | GPIO21 | `LED_PIN`, `LED_COUNT`, `LED_BRIGHTNESS` |
| Kickoff sound | headset jack | `KICKOFF_WAV` |

The servo needs an external 5 V supply with a common ground; the NeoPixel data
line typically needs a level shifter (or careful 3.3 V drive). See
`../docs/wiring.md` (to be written during week-6 integration).
