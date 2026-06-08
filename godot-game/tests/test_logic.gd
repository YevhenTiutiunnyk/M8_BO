extends SceneTree

## Headless test runner for the pure-logic scripts.
## Run with:  Godot --headless --path godot-game --script res://tests/test_logic.gd
## Exits with code 0 on success, 1 on any failure.

const ProtocolS := preload("res://scripts/protocol.gd")
const MatchStateS := preload("res://scripts/match_state.gd")
const DialMapS := preload("res://scripts/dial_map.gd")

var _failures := 0
var _checks := 0

func _initialize() -> void:
	_test_protocol()
	_test_match_state()
	_test_dial_map()
	print("\n%d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("ALL TESTS PASSED")
	quit(1 if _failures > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)

# --- Protocol ---------------------------------------------------------------
func _test_protocol() -> void:
	print("[protocol]")
	var dial := ProtocolS.parse('{"type":"dial","player":1,"value":0.5}')
	_check(dial["ok"] and dial["type"] == "dial" and dial["player"] == 1 and is_equal_approx(dial["value"], 0.5), "valid dial")

	var clamped := ProtocolS.parse('{"type":"dial","player":2,"value":1.7}')
	_check(clamped["ok"] and is_equal_approx(clamped["value"], 1.0), "dial value clamped to 1.0")

	var blow := ProtocolS.parse('{"type":"blow","intensity":0.8}')
	_check(blow["ok"] and blow["type"] == "blow" and is_equal_approx(blow["intensity"], 0.8), "valid blow")

	_check(not ProtocolS.parse('not json').ok, "rejects non-json")
	_check(not ProtocolS.parse('{"type":"dial","player":3,"value":0.5}').ok, "rejects bad player")
	_check(not ProtocolS.parse('{"type":"wat"}').ok, "rejects unknown type")
	_check(not ProtocolS.parse('{"type":"dial","player":1}').ok, "rejects missing value")

# --- MatchState -------------------------------------------------------------
func _test_match_state() -> void:
	print("[match_state]")
	var m := MatchStateS.new()

	# P1 wins half 1.
	m.score_goal(1); m.score_goal(1)
	var r := m.score_goal(1)
	_check(r["half_over"] and not r["match_over"] and r["half_winner"] == 1, "p1 wins half 1 at 3 goals")
	_check(m.current_half == 2 and m.halves_won[0] == 1, "advanced to half 2")
	_check(m.is_cruijff_half(), "half 2 is cruijff half")
	_check(m.half_goals == [0, 0], "half goals reset for half 2")

	# Blows only count in half 2.
	_check(m.try_blow(1), "blow consumed in half 2")
	_check(m.blows_left[0] == 1, "blow counter decremented")
	_check(m.try_blow(1), "second blow consumed")
	_check(not m.try_blow(1), "third blow rejected (none left)")

	# P2 wins half 2 -> 1-1 halves, tiebreak by total goals (p1 has 3, p2 has 3 -> draw).
	m.score_goal(2); m.score_goal(2); var r2 := m.score_goal(2)
	_check(r2["match_over"] and m.finished, "match over after second half")
	_check(m.winner == 0, "1-1 halves, equal goals -> draw")

	# Tiebreak by goals: rebuild so p2 wins half2 by more total goals.
	var m2 := MatchStateS.new()
	m2.score_goal(1); m2.score_goal(1); m2.score_goal(1)   # half1 p1 (3-0)
	m2.score_goal(1); m2.score_goal(1)                       # half2 p1 at 2
	m2.score_goal(2); m2.score_goal(2); m2.score_goal(2)   # half2 p2 wins 3-2
	_check(m2.finished and m2.winner == 1, "1-1 halves, p1 more total goals -> p1 wins")

	var blow_h1 := MatchStateS.new()
	_check(not blow_h1.try_blow(1), "blow rejected in half 1")

# --- DialMap ----------------------------------------------------------------
func _test_dial_map() -> void:
	print("[dial_map]")
	_check(is_equal_approx(DialMapS.integrate_key(0.5, true, false, 1.0, 0.2), 0.3), "up key decreases value")
	_check(is_equal_approx(DialMapS.integrate_key(0.5, false, true, 1.0, 0.2), 0.7), "down key increases value")
	_check(is_equal_approx(DialMapS.integrate_key(0.0, true, false, 1.0, 0.2), 0.0), "clamped at top")
	_check(is_equal_approx(DialMapS.integrate_key(1.0, false, true, 1.0, 0.2), 1.0), "clamped at bottom")
	_check(is_equal_approx(DialMapS.integrate_key(0.5, true, true, 1.0, 0.2), 0.5), "both keys cancel")
	_check(is_equal_approx(DialMapS.dial_to_y(0.0, 100.0, 600.0), 100.0), "value 0 -> top y")
	_check(is_equal_approx(DialMapS.dial_to_y(1.0, 100.0, 600.0), 600.0), "value 1 -> bottom y")
	_check(is_equal_approx(DialMapS.dial_to_y(0.5, 100.0, 600.0), 350.0), "value 0.5 -> middle y")
	_check(DialMapS.has_activity(0.5, 0.6, 0.05), "detects activity above deadband")
	_check(not DialMapS.has_activity(0.5, 0.51, 0.05), "ignores movement under deadband")
