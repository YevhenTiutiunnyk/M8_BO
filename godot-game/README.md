# Betondorp Pong-football — Godot game (Loop 2)

The on-screen game for the Amsterdam Museum Betondorp/Cruijff installation: an
always-on 2-player Pong-style football match. This folder is **only** the Godot
game (Loop 2). The Pi hardware services (`ambient-service`, `game-input`) are
not built yet — see `../plan.md`.

Engine: **Godot 4.6** (Compatibility renderer, for Raspberry Pi).

## Run it

Open `project.godot` in the Godot editor and press Play, or from a terminal:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/main.tscn
```

### Controls (keyboard fallback)
No Raspberry Pi or dial service needed to play:

| | Up | Down | Cruijff Turn (2nd half) |
|---|---|---|---|
| **Speler 1** | `W` | `S` | `Space` |
| **Speler 2** | `↑` | `↓` | `Enter` |

Move a paddle from the attract screen to start a match. On the real installation
the two rotary dials replace the keyboard automatically (see Input below).

## How it plays
- **Attract** → prompt + bouncing demo ball. Any input starts a match.
- **1st half**: normal Pong-football, first to 3 goals.
- **2nd half**: Cruijff Turn round — blow (or press the blow key) to widen your
  paddle for 3 s; 2 uses each.
- Overall winner: more halves won, tiebreak by total goals. Then result, then
  back to attract. Walking away mid-match for 20 s returns to attract.

## Input architecture
All game code reads input from the `InputHub` autoload (`scripts/input_hub.gd`),
never directly from a device. Two feeders write into it:
- `scripts/ws_client.gd` — connects to `ws://127.0.0.1:8765` and parses the
  `dial`/`blow` protocol (`../docs/protocol.md`). Auto-retries; absence is
  harmless. When connected, the real dials drive the paddles.
- keyboard — used whenever the WebSocket service is not connected.

So the same build runs unchanged on a laptop (keyboard) and on the Pi (dials).

## Layout
- `scenes/main.tscn` — single scene; its tree is built in code by
  `scripts/game_manager.gd` (state machine + scoring orchestration).
- `scripts/` — `ball.gd`, `bumper.gd`, plus pure node-free logic: `protocol.gd`,
  `match_state.gd`, `dial_map.gd`.
- `ui/hud.gd` — score / half / Cruijff uses / banners / result.
- `assets/` — `field.png`, `johan.png` (from `../img/`). The ball is a drawn
  placeholder. The Game Artist can swap sprites without touching logic.

## Tests
Pure logic runs headless:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/test_logic.gd
```

Exits non-zero on failure. Covers protocol parsing, scoring/half/winner logic,
and dial mapping.
