class_name LouGnarGameOverScreen
extends CanvasLayer
## GAME OVER card: score, submit status, top-10 board and a START OVER prompt.

const BOARD_ORIGIN := Vector2(450, 260)
const BOARD_RIGHT := 320.0
const ROW_HEIGHT := 28.0

var _score_label: Label
var _name_label: Label
var _status_label: Label
var _start_box: Panel
var _start_text: Label
var _board: Control
var _pulse: float = 0.0
var _lit: bool = false


func _ready() -> void:
	layer = 30
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(800, 600)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)

	var game_over := LouGnarUI.make_label("GAME OVER", 96, Color.RED)
	root.add_child(game_over)
	LouGnarUI.set_text_centered(game_over, "GAME OVER", Vector2(400, 120))

	_score_label = LouGnarUI.make_label("Score: 0", 48, Color.WHITE)
	root.add_child(_score_label)

	# Who the score is being submitted as (Steam name).
	root.add_child(LouGnarUI.make_box(Vector2(200, 280), Vector2(300, 50)))
	_name_label = LouGnarUI.make_label("", 24, LouGnarUI.LIME)
	root.add_child(_name_label)

	# Submit status (SUBMITTING... / SUBMITTED! / SUBMIT FAILED).
	root.add_child(LouGnarUI.make_box(Vector2(200, 350), Vector2(300, 60)))
	_status_label = LouGnarUI.make_label("", 28, LouGnarUI.LIME)
	root.add_child(_status_label)

	_start_box = LouGnarUI.make_box(Vector2(200, 420), Vector2(300, 60))
	root.add_child(_start_box)
	_start_text = LouGnarUI.make_label("START OVER", 28, LouGnarUI.LIME)
	root.add_child(_start_text)
	LouGnarUI.set_text_centered(_start_text, "START OVER", Vector2(200, 420))

	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.position = BOARD_ORIGIN
	root.add_child(_board)
	_draw_board([])


func show_results(final_score: int, player_name: String) -> void:
	LouGnarUI.set_text_centered(_score_label, "Score: %d" % final_score, Vector2(400, 200))
	LouGnarUI.set_text_centered(_name_label, _fit_name(player_name), Vector2(200, 280))
	set_status("SUBMITTING...")
	_draw_board([])
	_pulse = 0.0
	_lit = false
	LouGnarUI.style_box(_start_box, false)
	_start_text.add_theme_color_override("font_color", LouGnarUI.LIME)


func set_status(text: String) -> void:
	LouGnarUI.set_text_centered(_status_label, text, Vector2(200, 350))


func set_entries(entries: Array) -> void:
	_draw_board(entries)


func update(dt: float) -> void:
	_pulse += dt
	var lit := int(_pulse / 0.5) % 2 == 1
	if lit != _lit:
		_lit = lit
		LouGnarUI.style_box(_start_box, lit)
		_start_text.add_theme_color_override("font_color", Color.BLACK if lit else LouGnarUI.LIME)


func _draw_board(entries: Array) -> void:
	for child in _board.get_children():
		child.queue_free()

	var title := LouGnarUI.make_label("TOP 10 LEADERBOARD", 24, LouGnarUI.LIME)
	_board.add_child(title)

	for i in entries.size():
		var entry: Dictionary = entries[i]
		var color := Color.YELLOW if entry.get("is_player", false) else Color.WHITE
		var y := 35.0 + i * ROW_HEIGHT
		var name_label := LouGnarUI.make_label("%d. %s" % [entry["rank"], _fit_name(str(entry["name"]), 16)], 22, color)
		name_label.position = Vector2(0, y)
		_board.add_child(name_label)
		var score_label := LouGnarUI.make_label(str(entry["score"]), 22, color)
		_board.add_child(score_label)
		LouGnarUI.set_text_right(score_label, str(entry["score"]), Vector2(BOARD_RIGHT, y))


static func _fit_name(player_name: String, max_chars: int = 18) -> String:
	return player_name if player_name.length() <= max_chars else player_name.substr(0, max_chars - 1) + "…"
