extends Node2D

## A player paddle, rendered with the Johan sprite (already a tall top-down
## figure). Moves only vertically. Exposes a simple rect (center + half extents)
## that ball.gd uses for manual Pong-style collision. The Cruijff Turn widens
## the paddle vertically for a few seconds.

var half_width := 22.0
var half_height := 70.0
var _normal_half_height := 70.0
var _sprite: Sprite2D
var _widen_timer := 0.0

## Build the visual from a texture, sized to the desired paddle footprint.
## `rotate180` faces the figure the other way (used for the right-side player).
func setup(texture: Texture2D, paddle_w: float, paddle_h: float, rotate180 := false) -> void:
	half_width = paddle_w * 0.5
	half_height = paddle_h * 0.5
	_normal_half_height = half_height
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	if rotate180:
		_sprite.rotation_degrees = 180.0
	add_child(_sprite)
	_apply_sprite_scale(paddle_w, paddle_h)

func _apply_sprite_scale(paddle_w: float, paddle_h: float) -> void:
	var tex_size := _sprite.texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		_sprite.scale = Vector2(paddle_w / tex_size.x, paddle_h / tex_size.y)

func set_center_y(y: float) -> void:
	position.y = y

func top() -> float:
	return position.y - half_height

func bottom() -> float:
	return position.y + half_height

## Begin a Cruijff Turn: grow vertically by `factor` for `duration` seconds.
func cruijff_turn(factor: float, duration: float) -> void:
	half_height = _normal_half_height * factor
	if _sprite:
		_apply_sprite_scale(half_width * 2.0, half_height * 2.0)
	_widen_timer = duration

func _process(delta: float) -> void:
	if _widen_timer > 0.0:
		_widen_timer -= delta
		if _widen_timer <= 0.0:
			half_height = _normal_half_height
			if _sprite:
				_apply_sprite_scale(half_width * 2.0, half_height * 2.0)
