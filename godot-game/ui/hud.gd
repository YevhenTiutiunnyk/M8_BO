extends CanvasLayer

## All on-screen text plus the scoreboard graphic. The scoreboard uses
## assets/scoreboard.png (red panels left/right, blue centre box):
##   left red  -> SPELER 1     blue centre -> score     right red -> SPELER 2
## The half / Cruijff Turn info sits on a line beneath. Built in code so it has
## no external scene dependencies; the Game Artist can restyle behind the same
## method calls.

signal story_typed  # emitted once the current story sentence finishes typing

const WHITE := Color(0.97, 0.97, 0.97)
const STORY_CPS := 50.0  # typewriter speed (characters per second)

# Scoreboard size/placement (logical 1280x720). Texture is 1514x223 (aspect ~6.79).
const BOARD_W := 430.0
const BOARD_H := 63.0   # 430 / 6.789
const BOARD_TOP := 10.0
# Horizontal regions within the board, as fractions of its width.
const LEFT_RED := [0.04, 0.33]
const CENTER_BLUE := [0.345, 0.655]
const RIGHT_RED := [0.67, 0.96]

var _root: Control
var _board: TextureRect
var _p1_name: Label
var _p2_name: Label
var _score: Label
var _half: Label
var _cruijff: Label
var _attract: Label
var _banner: Label
var _result: Label
var _banner_timer := 0.0
var _story_dim: ColorRect
var _story_label: Label
var _story_typing := false
var _story_chars := 0.0

func _ready() -> void:
	# Full-screen container so all child anchors resolve against the viewport.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_scoreboard()

	_half = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_half.anchor_left = 0.0; _half.anchor_right = 1.0
	_half.offset_top = BOARD_TOP + BOARD_H + 10; _half.offset_bottom = BOARD_TOP + BOARD_H + 42

	_cruijff = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_cruijff.anchor_left = 0.0; _cruijff.anchor_right = 1.0
	_cruijff.offset_top = BOARD_TOP + BOARD_H + 42; _cruijff.offset_bottom = BOARD_TOP + BOARD_H + 74

	_attract = _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_attract.anchor_left = 0.0; _attract.anchor_right = 1.0
	_attract.offset_top = 300; _attract.offset_bottom = 420
	_attract.text = "Draai aan de knoppen om te spelen"

	_banner = _make_label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0; _banner.anchor_right = 1.0
	_banner.offset_top = 290; _banner.offset_bottom = 410
	_banner.visible = false

	_result = _make_label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_result.anchor_left = 0.0; _result.anchor_right = 1.0
	_result.offset_top = 280; _result.offset_bottom = 440
	_result.visible = false

	_build_story()

func _build_story() -> void:
	# Full-screen dim behind the story text so the pitch recedes.
	_story_dim = ColorRect.new()
	_story_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_dim.color = Color(0.04, 0.05, 0.04, 0.78)
	_story_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_dim.visible = false
	_root.add_child(_story_dim)

	_story_label = _make_label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.anchor_left = 0.0; _story_label.anchor_right = 1.0
	_story_label.offset_left = 130; _story_label.offset_right = -130
	_story_label.offset_top = 170; _story_label.offset_bottom = 550
	_story_label.visible = false

func _build_scoreboard() -> void:
	const VIEW_W := 1280.0
	_board = TextureRect.new()
	_board.texture = load("res://assets/scoreboard.png")
	_board.stretch_mode = TextureRect.STRETCH_SCALE
	# Ignore the texture's native 1514px size; the rect we set below is the size.
	_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_board.set_anchors_preset(Control.PRESET_TOP_LEFT)  # explicit offsets only
	_board.offset_left = (VIEW_W - BOARD_W) * 0.5
	_board.offset_right = _board.offset_left + BOARD_W
	_board.offset_top = BOARD_TOP
	_board.offset_bottom = BOARD_TOP + BOARD_H
	_root.add_child(_board)

	_p1_name = _make_region_label(19, LEFT_RED)
	_p1_name.text = "SPELER 1"
	_p2_name = _make_region_label(19, RIGHT_RED)
	_p2_name.text = "SPELER 2"
	_score = _make_region_label(28, CENTER_BLUE)
	_score.text = "0 - 0"

## A label parented to the scoreboard, spanning a horizontal region (fractions of
## the board width), centered within it. Uses explicit offsets relative to the
## board's top-left so placement doesn't depend on layout timing.
func _make_region_label(size: int, region) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.offset_left = region[0] * BOARD_W
	l.offset_right = region[1] * BOARD_W
	l.offset_top = 0.0
	l.offset_bottom = BOARD_H
	_board.add_child(l)
	return l

func _make_label(size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	_root.add_child(l)
	return l

func _set_board_visible(v: bool) -> void:
	_board.visible = v  # children inherit visibility

func show_attract() -> void:
	_attract.visible = true
	_set_board_visible(false)
	_half.visible = false
	_cruijff.visible = false
	_result.visible = false
	_banner.visible = false
	hide_story()

func show_match() -> void:
	_attract.visible = false
	_set_board_visible(true)
	_half.visible = true
	_result.visible = false

func set_score(p1: int, p2: int, half: int, cruijff_half: bool) -> void:
	_score.text = "%d - %d" % [p1, p2]
	_half.text = ("2e helft — Cruijff Turn" if cruijff_half else "1e helft") + "   (helft %d)" % half

func set_cruijff(uses1: int, uses2: int, visible: bool) -> void:
	_cruijff.visible = visible
	if visible:
		_cruijff.text = "Cruijff Turns —  Speler 1: %d    Speler 2: %d" % [uses1, uses2]

func flash(text: String, duration := 1.4) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_timer = duration

func show_result(winner: int) -> void:
	_set_board_visible(false)
	_half.visible = false
	_cruijff.visible = false
	_banner.visible = false
	hide_story()
	_result.visible = true
	if winner == 0:
		_result.text = "Gelijkspel!"
	else:
		_result.text = "Speler %d wint!" % winner

## Show one story sentence and type it out character by character.
func start_story(text: String) -> void:
	_story_label.text = text
	_story_label.visible_characters = 0
	_story_chars = 0.0
	_story_typing = true
	_story_dim.visible = true
	_story_label.visible = true

func hide_story() -> void:
	_story_typing = false
	_story_dim.visible = false
	_story_label.visible = false

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner.visible = false

	if _story_typing:
		_story_chars += delta * STORY_CPS
		var total := _story_label.text.length()
		var n := int(_story_chars)
		if n >= total:
			n = total
			_story_typing = false
			story_typed.emit()
		_story_label.visible_characters = n
