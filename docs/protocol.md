# WebSocket protocol — `game-input` → Godot game

Single source of truth for the only network surface in the game loop. The
`game-input` Python service binds `127.0.0.1:8765` and the Godot game is its
**only** client. **One direction only: server → game.** The game never sends.

All messages are JSON, one object per WebSocket text frame.

## Server → game

### `dial`
Absolute paddle position for one player.

```json
{"type": "dial", "player": 1, "value": 0.5}
```

| Field | Type | Notes |
|---|---|---|
| `player` | int | `1` or `2`. Anything else is rejected. |
| `value` | float | `0.0` = top of pitch, `1.0` = bottom. Clamped to `[0,1]` by the game. |

Sent at ~30 Hz, only when changed beyond a small dead-band (the service is
responsible for that filtering; the game also has its own activity dead-band).

### `blow`
A puff detected by the (single, shared) sound sensor — triggers a Cruijff Turn.

```json
{"type": "blow", "intensity": 0.8}
```

| Field | Type | Notes |
|---|---|---|
| `intensity` | float | `0.0`–`1.0`, clamped. The game ignores it below its blow threshold (0.5). |

**No `player` field** — there is one physical sensor, so a blow is not
attributable to a player at the protocol level. The game resolves the owner:
the Cruijff Turn is granted to the player who is **behind in the current half
and still has a use left** (tie → player 1). This only has any effect during
the second half. (Mirrors the open question in `plan.md` about shared-sensor
attribution; if the team later adds a second sensor, add a `player` field here
and the game can honour it directly.)

## Notes
- Unknown `type`, malformed JSON, or missing fields are dropped with a warning;
  they never crash the game.
- When the service is absent (e.g. laptop development), the game stays
  connected-retrying in the background and falls back to keyboard input. See the
  Godot project README.
