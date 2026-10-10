class_name LouGnarGameOverScreen
extends CanvasLayer
## GAME OVER card: score, submit status, top-50 board and a START OVER prompt.
## The board shows 10 rows at a time: it holds still on the top 10, then after
## SCROLL_DELAY seconds rolls slowly up through the rest, pauses on the last rows
## and jumps back to the top.

const BOARD_ORIGIN := Vector2(450, 260)
const BOARD_RIGHT := 320.0
const ROW_HEIGHT := 28.0
const LIST_TOP := 35.0 # rows start below the board title
const VISIBLE_ROWS := 10
const SCROLL_DELAY := 3.0 # seconds the top 10 stay still before the list starts rolling
const SCROLL_SPEED := 22.0 # px/s, a little under a row per second
const END_HOLD := 3.0 # seconds on the last rows before jumping back to the top

var _score_label: Label
var _name_label: Label
var _status_label: Label
var _start_box: Panel
var _start_text: Label
var _board: Control
var _board_title: Label
var _list: Control
var _row_count: int = 0
var _scroll: float = 0.0
var _scroll_wait: float = 0.0
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
	_board_title = LouGnarUI.make_label("", 24, LouGnarUI.LIME)
	_board.add_child(_board_title)
	_set_board_title("TOP %d LEADERBOARD" % LouGnarLeaderboard.MAX_ENTRIES, LouGnarUI.LIME)

	# 10-row window onto the full list; _list slides up inside it.
	var window := Control.new()
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.clip_contents = true
	window.position = Vector2(0, LIST_TOP)
	window.size = Vector2(BOARD_RIGHT, VISIBLE_ROWS * ROW_HEIGHT)
	_board.add_child(window)
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(_list)
	_draw_board([])


func show_results(final_score: int, player_name: String) -> void:
	LouGnarUI.set_text_centered(_score_label, "Score: %d" % final_score, Vector2(400, 200))
	LouGnarUI.set_text_centered(_name_label, _fit_name(player_name), Vector2(200, 280))
	set_status("SUBMITTING...")
	_set_board_title("TOP %d LEADERBOARD" % LouGnarLeaderboard.MAX_ENTRIES, LouGnarUI.LIME)
	_draw_board([])
	_reset_scroll()
	_pulse = 0.0
	_lit = false
	LouGnarUI.style_box(_start_box, false)
	_start_text.add_theme_color_override("font_color", LouGnarUI.LIME)


func set_status(text: String) -> void:
	LouGnarUI.set_text_centered(_status_label, text, Vector2(200, 350))


## `offline`: the entries are this device's saved runs, not the Steam board.
func set_entries(entries: Array, offline: bool = false) -> void:
	if offline:
		_set_board_title("OFFLINE TOP %d" % LouGnarLeaderboard.MAX_ENTRIES, Color.ORANGE)
	else:
		_set_board_title("GLOBAL TOP %d" % LouGnarLeaderboard.MAX_ENTRIES, LouGnarUI.LIME)
	_draw_board(entries)


func _set_board_title(text: String, color: Color) -> void:
	_board_title.text = text
	_board_title.add_theme_color_override("font_color", color)


func update(dt: float) -> void:
	_pulse += dt
	var lit := int(_pulse / 0.5) % 2 == 1
	if lit != _lit:
		_lit = lit
		LouGnarUI.style_box(_start_box, lit)
		_start_text.add_theme_color_override("font_color", Color.BLACK if lit else LouGnarUI.LIME)
	_update_scroll(dt)


## Redraws keep the current scroll position: Steam re-sends the list as player
## names resolve, and that shouldn't yank the board back to the top.
func _draw_board(entries: Array) -> void:
	for child in _list.get_children():
		child.queue_free()

	for i in entries.size():
		var entry: Dictionary = entries[i]
		var color := Color.YELLOW if entry.get("is_player", false) else Color.WHITE
		var y := i * ROW_HEIGHT
		var name_label := LouGnarUI.make_label("%d. %s" % [entry["rank"], _fit_name(str(entry["name"]), 16)], 22, color)
		name_label.position = Vector2(0, y)
		_list.add_child(name_label)
		var score_label := LouGnarUI.make_label(str(entry["score"]), 22, color)
		_list.add_child(score_label)
		LouGnarUI.set_text_right(score_label, str(entry["score"]), Vector2(BOARD_RIGHT, y))

	_row_count = entries.size()
	_scroll = minf(_scroll, _max_scroll())
	_apply_scroll()


func _reset_scroll() -> void:
	_scroll = 0.0
	_scroll_wait = 0.0
	_apply_scroll()


func _update_scroll(dt: float) -> void:
	var max_scroll := _max_scroll()
	if max_scroll <= 0.0:
		return
	_scroll_wait += dt
	if _scroll >= max_scroll:
		if _scroll_wait >= END_HOLD:
			_reset_scroll()
		return
	if _scroll_wait >= SCROLL_DELAY:
		_scroll = minf(_scroll + SCROLL_SPEED * dt, max_scroll)
		if _scroll >= max_scroll:
			_scroll_wait = 0.0 # start the END_HOLD pause
		_apply_scroll()


func _max_scroll() -> float:
	return maxf(0.0, (_row_count - VISIBLE_ROWS) * ROW_HEIGHT)


func _apply_scroll() -> void:
	_list.position.y = -roundf(_scroll) # whole pixels keep the pixel font crisp


static func _fit_name(player_name: String, max_chars: int = 18) -> String:
	return player_name if player_name.length() <= max_chars else player_name.substr(0, max_chars - 1) + "…"
