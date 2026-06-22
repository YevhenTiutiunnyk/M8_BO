extends Node2D

## Root controller: builds the playfield in code, runs the always-on state
## machine (ATTRACT -> MATCH -> RESULT -> ATTRACT), maps dials to paddles, and
## applies scoring + the Cruijff Turn. Reads all input through the InputHub
## autoload, so it behaves identically with real dials or the keyboard.

const MatchStateScript := preload("res://scripts/match_state.gd")
const DialMap := preload("res://scripts/dial_map.gd")
const BumperScript := preload("res://scripts/bumper.gd")
const BallScript := preload("res://scripts/ball.gd")
const HudScript := preload("res://ui/hud.gd")

# --- Layout (logical 1280x720) ---
const VIEW := Vector2(1280, 720)
const FIELD_TOP := 70.0
const FIELD_BOTTOM := 650.0
const GOAL_LEFT_X := 70.0
const GOAL_RIGHT_X := 1210.0
const P1_X := 120.0
const P2_X := 1160.0
const PADDLE_W := 46.0
const PADDLE_H := 150.0

# --- Tuning ---
const ACTIVITY_DEADBAND := 0.02
const ABANDON_TIMEOUT := 20.0
const RESULT_DURATION := 8.0
const BLOW_THRESHOLD := 0.5
const CRUIJFF_FACTOR := 1.7
const CRUIJFF_DURATION := 3.0

enum State { ATTRACT, MATCH, RESULT, STORY }

# Read hold after a sentence finishes typing: a base plus time per character,
# so longer sentences stay on screen longer.
const STORY_HOLD_BASE := 3.0
const STORY_HOLD_PER_CHAR := 0.05

# The Tibo / Cruijff ball story, one sentence revealed per goal (then it loops).
const STORY := [
	"Tibo — voetbal achtergelaten bij het ouderlijk huis van Johan Cruijff in Betondorp, na het overlijden op 24 maart 2016.",
	"\"Voor Johan Cruijff van Tibo, ik had je graag willen ontmoeten.\"",
	"Deze lieve woorden van een duidelijk zeer jonge fan van Cruijff staan op deze bal, die achtergelaten werd bij het huis in Betondorp waar Cruijff opgroeide, nadat de voetballer in 2016 was overleden.",
	"Op twee van de vlakken van de bal tekende Tibo nog een Ajaxshirt met nummer 14, en een Barcelonashirt met nummer 9.",
]

var _state: int = State.ATTRACT
var _match
var _paddles: Array = []  # [P1 (left), P2 (right)]
var _ball
var _hud
var _travel_top := 0.0
var _travel_bottom := 0.0
var _time_since_activity := 0.0
var _result_timer := 0.0
var _story_index := -1
var _story_hold := 0.0
var _story_typed_done := false
var _last_scorer := 1

func _ready() -> void:
	_match = MatchStateScript.new()
	_build_field()
	_build_paddles()
	_build_ball()
	_build_hud()
	InputHub.blow_requested.connect(_on_blow)
	_ball.goal_scored.connect(_on_goal)
	_hud.story_typed.connect(_on_story_typed)
	_enter_attract()

# --- Construction -----------------------------------------------------------
func _build_field() -> void:
	var tex: Texture2D = load("res://assets/field.png")
	var bg := Sprite2D.new()
	bg.texture = tex
	bg.centered = true
	bg.position = VIEW * 0.5
	var ts := tex.get_size()
	bg.scale = Vector2(VIEW.x / ts.x, VIEW.y / ts.y)
	add_child(bg)

func _build_paddles() -> void:
	var johan: Texture2D = load("res://assets/johan.png")
	var half_h := PADDLE_H * 0.5
	_travel_top = FIELD_TOP + half_h
	_travel_bottom = FIELD_BOTTOM - half_h
	var xs := [P1_X, P2_X]
	for i in xs.size():
		var b = BumperScript.new()
		add_child(b)
		b.setup(johan, PADDLE_W, PADDLE_H, i == 1)  # right player faces the other way
		b.position = Vector2(xs[i], VIEW.y * 0.5)
		_paddles.append(b)

func _build_ball() -> void:
	_ball = BallScript.new()
	add_child(_ball)
	_ball.configure(FIELD_TOP, FIELD_BOTTOM, GOAL_LEFT_X, GOAL_RIGHT_X, VIEW * 0.5, _paddles)

func _build_hud() -> void:
	_hud = HudScript.new()
	add_child(_hud)

# --- Main loop --------------------------------------------------------------
func _process(delta: float) -> void:
	_update_paddles()
	var active := InputHub.consume_activity(ACTIVITY_DEADBAND)
	match _state:
		State.ATTRACT:
			if active:
				_start_match()
		State.MATCH:
			if active:
				_time_since_activity = 0.0
			else:
				_time_since_activity += delta
				if _time_since_activity >= ABANDON_TIMEOUT:
					_enter_attract()
		State.RESULT:
			_result_timer -= delta
			if _result_timer <= 0.0:
				_enter_attract()
		State.STORY:
			# Paused for storytelling; resume after the sentence finishes + a hold.
			if _story_typed_done:
				_story_hold -= delta
				if _story_hold <= 0.0:
					_resume_after_story()

func _update_paddles() -> void:
	for i in _paddles.size():
		var y := DialMap.dial_to_y(InputHub.get_dial(i + 1), _travel_top, _travel_bottom)
		_paddles[i].set_center_y(y)

# --- State transitions ------------------------------------------------------
func _enter_attract() -> void:
	_state = State.ATTRACT
	_match.reset()
	_ball.demo = true
	_ball.serve(1 if randf() > 0.5 else -1)
	_hud.show_attract()

func _start_match() -> void:
	_state = State.MATCH
	_match.reset()
	_story_index = -1
	_ball.demo = false
	_time_since_activity = 0.0
	_hud.show_match()
	_update_score_hud()
	_hud.flash("Aftrap!")
	_ball.serve(1 if randf() > 0.5 else -1)

func _enter_result() -> void:
	_state = State.RESULT
	_ball.active = false
	_result_timer = RESULT_DURATION
	_hud.show_result(_match.winner)

# --- Events -----------------------------------------------------------------
func _on_goal(player: int) -> void:
	if _state != State.MATCH:
		return
	var r: Dictionary = _match.score_goal(player)
	_update_score_hud()
	_last_scorer = player
	if r["match_over"]:
		_enter_result()
	elif _story_index < STORY.size() - 1:
		# Pause and tell the next sentence — until the whole story has been told.
		_enter_story()
	else:
		# Story already fully told this match: just play on.
		_serve_after_goal(player)

func _enter_story() -> void:
	_state = State.STORY
	_ball.active = false
	_story_typed_done = false
	_story_hold = 0.0
	_story_index += 1
	_hud.start_story(STORY[_story_index])

func _on_story_typed() -> void:
	_story_typed_done = true
	_story_hold = STORY_HOLD_BASE + STORY[_story_index].length() * STORY_HOLD_PER_CHAR

func _resume_after_story() -> void:
	_hud.hide_story()
	_state = State.MATCH
	_time_since_activity = 0.0
	_serve_after_goal(_last_scorer)

func _serve_after_goal(scorer: int) -> void:
	# Serve toward the player who just conceded.
	_ball.serve(1 if scorer == 1 else -1)

func _on_blow(player: int, intensity: float) -> void:
	if _state != State.MATCH or not _match.is_cruijff_half():
		return
	if intensity < BLOW_THRESHOLD:
		return
	var who := player
	if who == 0:
		who = _resolve_shared_blow()
	if who == 0:
		return
	if _match.try_blow(who):
		_paddles[who - 1].cruijff_turn(CRUIJFF_FACTOR, CRUIJFF_DURATION)
		_hud.flash("Cruijff Turn! Speler %d" % who)
		_update_score_hud()

## Resolve a blow from the single shared sound sensor (player 0): give it to the
## player who is behind in the half and still has a use; tie -> player 1.
func _resolve_shared_blow() -> int:
	var p1_has: bool = _match.blows_left[0] > 0
	var p2_has: bool = _match.blows_left[1] > 0
	if p1_has and not p2_has:
		return 1
	if p2_has and not p1_has:
		return 2
	if not p1_has and not p2_has:
		return 0
	if _match.half_goals[0] <= _match.half_goals[1]:
		return 1
	return 2

func _update_score_hud() -> void:
	_hud.set_score(_match.half_goals[0], _match.half_goals[1], _match.current_half, _match.is_cruijff_half())
	_hud.set_cruijff(_match.blows_left[0], _match.blows_left[1], _match.is_cruijff_half())
