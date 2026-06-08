extends Node2D

## Placeholder ball (drawn circle — no art asset yet). Kinematic Pong physics:
## bounces off top/bottom walls and the two paddles, deflecting by where it hits
## the paddle. Emits goal_scored when it crosses a goal line. In demo mode
## (attract screen) it bounces off the left/right walls instead of scoring.

signal goal_scored(player: int)  # the player who scored

const RADIUS := 16.0
const BASE_SPEED := 430.0
const MAX_SPEED := 820.0
const SPEEDUP := 1.05
const MAX_DEFLECT_DEG := 50.0

var velocity := Vector2.ZERO
var active := false
var demo := false

var bounds_top := 0.0
var bounds_bottom := 0.0
var goal_left_x := 0.0
var goal_right_x := 0.0
var center := Vector2.ZERO
var paddles: Array = []  # [P1 (left), P2 (right)]

var _speed := BASE_SPEED

func configure(top: float, bottom: float, left_x: float, right_x: float, c: Vector2, paddle_nodes: Array) -> void:
	bounds_top = top
	bounds_bottom = bottom
	goal_left_x = left_x
	goal_right_x = right_x
	center = c
	paddles = paddle_nodes

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
	draw_circle(Vector2.ZERO, RADIUS * 0.55, Color(0.85, 0.2, 0.15))  # tiny accent

## Place the ball at center and serve toward `direction` (-1 left, +1 right).
func serve(direction: int) -> void:
	position = center
	_speed = BASE_SPEED
	var spread := randf_range(-0.35, 0.35)
	velocity = Vector2(direction, spread).normalized() * _speed
	active = true

func _physics_process(delta: float) -> void:
	if not active:
		return
	position += velocity * delta

	# Top / bottom walls.
	if position.y < bounds_top:
		position.y = bounds_top
		velocity.y = absf(velocity.y)
	elif position.y > bounds_bottom:
		position.y = bounds_bottom
		velocity.y = -absf(velocity.y)

	_check_paddles()

	# Left / right boundary: goal (match) or wall bounce (demo).
	if position.x < goal_left_x:
		if demo:
			position.x = goal_left_x
			velocity.x = absf(velocity.x)
		else:
			goal_scored.emit(2)
	elif position.x > goal_right_x:
		if demo:
			position.x = goal_right_x
			velocity.x = -absf(velocity.x)
		else:
			goal_scored.emit(1)

func _check_paddles() -> void:
	for i in paddles.size():
		var p = paddles[i]
		var is_left := (i == 0)
		# Only collide when moving toward this paddle.
		if is_left and velocity.x >= 0:
			continue
		if not is_left and velocity.x <= 0:
			continue
		if absf(position.x - p.position.x) > (RADIUS + p.half_width):
			continue
		if absf(position.y - p.position.y) > (RADIUS + p.half_height):
			continue
		_bounce_off(p, is_left)
		return

func _bounce_off(p, is_left: bool) -> void:
	var offset := clampf((position.y - p.position.y) / p.half_height, -1.0, 1.0)
	var dir_x := 1.0 if is_left else -1.0
	_speed = minf(_speed * SPEEDUP, MAX_SPEED)
	var angle := deg_to_rad(MAX_DEFLECT_DEG) * offset
	velocity = Vector2(dir_x * cos(angle), sin(angle)).normalized() * _speed
	# Nudge the ball clear of the paddle so it can't re-trigger next frame.
	position.x = p.position.x + dir_x * (p.half_width + RADIUS + 1.0)
