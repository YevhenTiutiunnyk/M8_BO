# Betondorp Pong-football — Godot Game Design

**Date:** 2026-06-08
**Scope:** Loop 2 (the Godot game) only. The Python hardware services
(`ambient-service`, `game-input`) are out of scope for this build.
**Engine:** Godot 4.6.3 stable (installed at `/Applications/Godot.app`).

## Goal

A self-contained Godot 4 project implementing the always-on, 2-player
Pong-style football game described in `plan.md` — playable today on a laptop
with the keyboard, and droppable onto the Raspberry Pi unchanged once the
`game-input` WebSocket service exists.

## Assets

From `img/` (copied into the project):

- `FootballField.png` — top-down horizontal pitch (~16:9), goals at the left
  and right ends. Used as the playfield background.
- `Johan kruiyfffsdjaflkfd.png` — top-down Cruijff figure in the orange kit,
  vertically oriented. Used as the bumper/paddle sprite (one per side).
- **Ball** — no asset provided; rendered as a placeholder circle.

## Layout

Horizontal pitch as background. Player 1 (left) and Player 2 (right) each
control a Johan-sprite paddle that moves only vertically. The ball ricochets
off the top/bottom walls and the paddles; a goal is scored when the ball
crosses the far left (P2 scores) or right (P1 scores) goal line.

Base resolution 1280×720, fullscreen, stretch mode `canvas_items` with
`keep` aspect so it fills the embedded HDMI screen without distortion.

## Input abstraction (key design decision)

All game code reads input from a single `InputHub` autoload singleton:

- `get_dial(player: int) -> float` returns 0.0–1.0 (absolute paddle position,
  0 = top, 1 = bottom).
- `blow(player, intensity)` signal for the Cruijff Turn.
- `any_dial_activity()` / movement delta tracking for state transitions.

Game logic never knows the input source. Two feeders write into the hub:

1. **`ws_client.gd`** — connects to `ws://127.0.0.1:8765`, auto-retries every
   ~2 s when not connected, parses the plan's protocol messages (server→game
   only, never sends). Absence of the service never blocks or errors the game.
2. **Keyboard** — P1 `W`/`S`, P2 `↑`/`↓` (held to drive the virtual dial
   toward 0/1), blow = `Space` (P1) and `Enter` (P2). Because real dials are
   absolute, a held key integrates the virtual dial value, clamped 0–1.

## WebSocket protocol (server → game only)

JSON messages, matching `plan.md`:

- `{"type": "dial", "player": 1|2, "value": 0.0-1.0}`
- `{"type": "blow", "intensity": 0.0-1.0}` (applies to whichever player has a
  turn available; see Cruijff Turn)

The game is a pure client: it connects, reads, and never sends. Documented in
`docs/protocol.md`.

## State machine (`game_manager.gd`)

`ATTRACT → MATCH → RESULT → ATTRACT`

- **ATTRACT** — prompt "Draai aan de knoppen om te spelen", a demo ball bounces,
  score hidden. Any dial movement beyond a deadband on either player → MATCH.
- **MATCH**
  - **Half 1 — normal Pong-football.** First to 3 goals wins the half. Standard
    physics, normal paddle size.
  - **Half 2 — Cruijff Turn round.** First to 3 goals wins the half. Each player
    has 2 blows; a blow (intensity > threshold, uses remaining) widens that
    player's paddle for 3 s. HUD shows remaining uses.
  - Overall winner = more halves won; tiebreak (1–1) by total goals.
  - **Abandoned match** — no dial input for 20 s → return to ATTRACT.
- **RESULT** — ~8 s winner celebration, then ATTRACT.

## Ball physics

Kinematic ball with a velocity vector. Bounces off top/bottom walls. Paddle
bounce deflects based on hit offset from paddle center (classic Pong feel).
Slight speed-up per paddle hit, capped. On a goal: increment score, brief goal
feedback (on-screen + audio hook), reset ball to center, serve toward the
conceding side.

## Project structure

```
godot-game/
├── project.godot
├── scenes/
│   ├── main.tscn          # root: GameManager, Pitch, HUD, UI overlays
│   ├── pitch.tscn         # field background, walls, goals, paddles, ball
│   ├── bumper.tscn        # Johan-sprite paddle
│   └── ball.tscn          # placeholder ball
├── scripts/
│   ├── game_manager.gd    # state machine, halves, scoring orchestration
│   ├── input_hub.gd       # autoload: merges WS + keyboard → dial/blow
│   ├── ws_client.gd       # WebSocket client → input_hub
│   ├── protocol.gd        # pure: parse/validate protocol messages
│   ├── match_state.gd     # pure: scoring, half logic, winner calc
│   ├── dial_map.gd        # pure: dial value → paddle Y; keyboard integration
│   ├── bumper.gd
│   └── ball.gd
├── ui/
│   ├── attract.tscn/.gd
│   ├── hud.tscn/.gd
│   └── result.tscn/.gd
├── assets/
│   ├── field.png
│   └── johan.png
└── tests/
    └── test_logic.gd      # headless tests for pure scripts
```

## Testability

Pure logic (`protocol.gd`, `match_state.gd`, `dial_map.gd`) is node-free so it
runs under `Godot --headless` via a small test runner (`tests/test_logic.gd`).
These are verified to pass as part of this build. The visual run (scenes,
input feel) requires the editor window and is confirmed by the user.

## Out of scope

- Python services (`ambient-service`, `game-input`), GPIO, MCP3008, systemd,
  Pi kiosk setup.
- Final art/animation polish (Game Artist supplies real sprites later; this
  build uses the provided field + Johan images and a placeholder ball).
- Real audio assets (sound playback is wired with hooks/placeholders).
