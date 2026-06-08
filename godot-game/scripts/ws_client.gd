extends Node

## WebSocket client for the game-input service (server -> game only).
## Connects to ws://127.0.0.1:8765, auto-retries when the service is absent,
## and forwards parsed dial/blow messages. The game never sends anything back.
## When the Python service isn't running (e.g. laptop dev) this stays quietly
## disconnected and the keyboard feeder in InputHub takes over.

signal dial_received(player: int, value: float)
signal blow_received(intensity: float)
signal connection_changed(connected: bool)

const Protocol := preload("res://scripts/protocol.gd")
const URL := "ws://127.0.0.1:8765"
const RETRY_INTERVAL := 2.0

var _peer := WebSocketPeer.new()
var _connected := false
var _retry_timer := 0.0

func _ready() -> void:
	_peer.connect_to_url(URL)

func _process(delta: float) -> void:
	_peer.poll()
	var state := _peer.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				connection_changed.emit(true)
			while _peer.get_available_packet_count() > 0:
				_handle(_peer.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				connection_changed.emit(false)
			_retry_timer += delta
			if _retry_timer >= RETRY_INTERVAL:
				_retry_timer = 0.0
				_peer = WebSocketPeer.new()
				_peer.connect_to_url(URL)
		_:
			pass  # CONNECTING / CLOSING: keep polling

func is_connected_to_service() -> bool:
	return _connected

func _handle(text: String) -> void:
	var msg := Protocol.parse(text)
	if not msg["ok"]:
		push_warning("ws_client: dropped message (%s)" % msg["error"])
		return
	match msg["type"]:
		"dial":
			dial_received.emit(msg["player"], msg["value"])
		"blow":
			blow_received.emit(msg["intensity"])
