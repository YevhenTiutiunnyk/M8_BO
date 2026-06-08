extends Node

## Autoload singleton. Single source of input for all game logic, merging two
## feeders so the game is source-agnostic:
##   - ws_client: real dials/blow over WebSocket (the Pi / game-input service)
##   - keyboard:  laptop dev fallback (P1 W/S, P2 Up/Down, blow Space/Enter)
##
## Game code only ever calls get_dial() / listens to blow_requested. It never
## knows or cares where the value came from.
##
## Dial convention: 0.0 = top of pitch, 1.0 = bottom.

signal blow_requested(player: int, intensity: float)  # player 0 = shared sensor (game decides)

const DialMap := preload("res://scripts/dial_map.gd")
const WSClientScript := preload("res://scripts/ws_client.gd")

## Seconds of held key to traverse the full dial range.
const KEY_DIAL_SPEED := 1.25
const KEYBOARD_BLOW_INTENSITY := 1.0

var _dials := {1: 0.5, 2: 0.5}
var _prev_dials := {1: 0.5, 2: 0.5}
var _ws: Node
var _ws_connected := false

func _ready() -> void:
	_ws = WSClientScript.new()
	_ws.name = "WSClient"
	add_child(_ws)
	_ws.dial_received.connect(_on_ws_dial)
	_ws.blow_received.connect(_on_ws_blow)
	_ws.connection_changed.connect(func(c: bool): _ws_connected = c)

func _process(delta: float) -> void:
	# Keyboard drives the dials only while the real service is absent.
	if not _ws_connected:
		_dials[1] = DialMap.integrate_key(_dials[1],
			Input.is_action_pressed("p1_up"), Input.is_action_pressed("p1_down"),
			delta, KEY_DIAL_SPEED)
		_dials[2] = DialMap.integrate_key(_dials[2],
			Input.is_action_pressed("p2_up"), Input.is_action_pressed("p2_down"),
			delta, KEY_DIAL_SPEED)

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard blow is always attributable to a player (useful for testing the
	# Cruijff Turn); the real shared sensor arrives via _on_ws_blow as player 0.
	if event.is_action_pressed("p1_blow"):
		blow_requested.emit(1, KEYBOARD_BLOW_INTENSITY)
	elif event.is_action_pressed("p2_blow"):
		blow_requested.emit(2, KEYBOARD_BLOW_INTENSITY)

func get_dial(player: int) -> float:
	return _dials[player]

func is_using_real_dials() -> bool:
	return _ws_connected

## Returns true if either dial moved more than the deadband since the last call,
## and latches the new positions. Used for attract/abandon transitions.
func consume_activity(deadband: float) -> bool:
	var active := false
	for p in [1, 2]:
		if DialMap.has_activity(_prev_dials[p], _dials[p], deadband):
			active = true
		_prev_dials[p] = _dials[p]
	return active

func _on_ws_dial(player: int, value: float) -> void:
	_dials[player] = value

func _on_ws_blow(intensity: float) -> void:
	blow_requested.emit(0, intensity)  # 0 = shared physical sensor; game resolves owner
