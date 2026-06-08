extends CanvasLayer

## All on-screen text: score, current half, Cruijff Turn uses, the attract
## prompt, transient banners (goal / half / "Cruijff Turn!"), and the result
## screen. Built in code so it has no external scene dependencies; the Game
## Artist can later replace these with themed scenes behind the same methods.

const RED := Color(0.85, 0.18, 0.13)
const WHITE := Color(0.96, 0.96, 0.96)

var _score: Label
var _half: Label
var _cruijff: Label
var _attract: Label
var _banner: Label
var _result: Label
var _banner_timer := 0.0

func _ready() -> void:
	_score = _make_label(48, HORIZONTAL_ALIGNMENT_CENTER)
	_score.anchor_left = 0.0; _score.anchor_right = 1.0
	_score.offset_top = 20; _score.offset_bottom = 90

	_half = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_half.anchor_left = 0.0; _half.anchor_right = 1.0
	_half.offset_top = 90; _half.offset_bottom = 130

	_cruijff = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_cruijff.anchor_left = 0.0; _cruijff.anchor_right = 1.0
	_cruijff.offset_top = 130; _cruijff.offset_bottom = 170

	_attract = _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_attract.anchor_left = 0.0; _attract.anchor_right = 1.0
	_attract.offset_top = 300; _attract.offset_bottom = 420
	_attract.text = "Draai aan de knoppen om te spelen"

	_banner = _make_label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0; _banner.anchor_right = 1.0
	_banner.offset_top = 280; _banner.offset_bottom = 400
	_banner.visible = false

	_result = _make_label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_result.anchor_left = 0.0; _result.anchor_right = 1.0
	_result.offset_top = 280; _result.offset_bottom = 440
	_result.visible = false

func _make_label(size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	add_child(l)
	return l

func show_attract() -> void:
	_attract.visible = true
	_score.visible = false
	_half.visible = false
	_cruijff.visible = false
	_result.visible = false
	_banner.visible = false

func show_match() -> void:
	_attract.visible = false
	_score.visible = true
	_half.visible = true
	_result.visible = false

func set_score(p1: int, p2: int, half: int, cruijff_half: bool) -> void:
	_score.text = "%d   -   %d" % [p1, p2]
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
	_score.visible = false
	_half.visible = false
	_cruijff.visible = false
	_banner.visible = false
	_result.visible = true
	if winner == 0:
		_result.text = "Gelijkspel!"
	else:
		_result.text = "Speler %d wint!" % winner

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner.visible = false
