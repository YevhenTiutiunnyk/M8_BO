class_name Protocol
extends RefCounted

## Pure parsing/validation of the server -> game WebSocket protocol.
## See docs/protocol.md. The game is a read-only client; it never sends.
##
## Messages (JSON):
##   {"type": "dial", "player": 1|2, "value": 0.0-1.0}
##   {"type": "blow", "intensity": 0.0-1.0}

## Parse one raw JSON message into a normalized dictionary.
## Always returns a dict with "ok": bool. On success it carries the typed
## fields; on failure it carries "error" with a human-readable reason.
static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {"ok": false, "error": "invalid json: %s" % json.get_error_message()}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "expected object"}
	if not data.has("type"):
		return {"ok": false, "error": "missing 'type'"}
	match data["type"]:
		"dial":
			return _parse_dial(data)
		"blow":
			return _parse_blow(data)
		_:
			return {"ok": false, "error": "unknown type '%s'" % str(data["type"])}

static func _parse_dial(data: Dictionary) -> Dictionary:
	if not data.has("player") or not data.has("value"):
		return {"ok": false, "error": "dial missing player/value"}
	var player := int(data["player"])
	if player != 1 and player != 2:
		return {"ok": false, "error": "dial player must be 1 or 2"}
	var value := clampf(float(data["value"]), 0.0, 1.0)
	return {"ok": true, "type": "dial", "player": player, "value": value}

static func _parse_blow(data: Dictionary) -> Dictionary:
	if not data.has("intensity"):
		return {"ok": false, "error": "blow missing intensity"}
	var intensity := clampf(float(data["intensity"]), 0.0, 1.0)
	return {"ok": true, "type": "blow", "intensity": intensity}
