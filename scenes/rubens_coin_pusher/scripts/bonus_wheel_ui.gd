extends Control

var segments = [
	{"label": "5 Coins", "color": Color(0.85, 0.2, 0.2), "type": "coins", "value": 5},
	{"label": "10 Coins", "color": Color(0.2, 0.45, 0.85), "type": "coins", "value": 10},
	{"label": "Extra Ball", "color": Color(0.9, 0.55, 0.1), "type": "balls", "value": 1},
	{"label": "20 Coins", "color": Color(0.2, 0.7, 0.3), "type": "coins", "value": 20},
	{"label": "5 Coins", "color": Color(0.65, 0.2, 0.65), "type": "coins", "value": 5},
	{"label": "10 Coins", "color": Color(0.2, 0.65, 0.65), "type": "coins", "value": 10},
	{"label": "2 Balls", "color": Color(0.85, 0.4, 0.1), "type": "balls", "value": 2},
	{"label": "50 Coins", "color": Color(0.9, 0.8, 0.15), "type": "coins", "value": 50},
]

var spin_angle: float = 0.0
var spin_speed: float = 10.0
var state: int = 0 # 0=spinning, 1=decelerating, 2=stopped

signal prize_won(type: String, value: int)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tree_exiting.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	match state:
		0:
			spin_angle += spin_speed * delta
			queue_redraw()
		1:
			spin_angle += spin_speed * delta
			spin_speed = max(0, spin_speed - 2.5 * delta)
			if spin_speed <= 0:
				state = 2
				var w = _get_winner()
				prize_won.emit(segments[w].type, segments[w].value)
			queue_redraw()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match state:
			0:
				spin_speed = randf_range(5, 12)
				state = 1
			2:
				queue_free()

func _draw():
	# Dark overlay
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))

	var center = size / 2
	var radius = min(size.x, size.y) * 0.28
	var seg_count = segments.size()
	var seg_angle = TAU / seg_count

	# Gold outer ring
	draw_circle(center, radius + 8, Color(0.8, 0.7, 0.2))

	# Draw segments
	for i in seg_count:
		var start = spin_angle + i * seg_angle - PI / 2
		var end_a = start + seg_angle
		var points = PackedVector2Array()
		points.append(center)
		for j in range(25):
			var a = start + (end_a - start) * j / 24.0
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(points, segments[i].color)

		# Divider line
		var edge = center + Vector2(cos(start), sin(start)) * radius
		draw_line(center, edge, Color(0.05, 0.05, 0.05, 0.6), 2.0)

	# Labels at segment centers
	var font = ThemeDB.fallback_font
	for i in seg_count:
		var mid = spin_angle + (i + 0.5) * seg_angle - PI / 2
		var lpos = center + Vector2(cos(mid), sin(mid)) * (radius * 0.6)
		var text = segments[i].label
		var tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var th = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).y
		draw_string(font, lpos - Vector2(tw / 2, th / 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# Pointer triangle at top
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x, center.y - radius - 5),
		Vector2(center.x - 14, center.y - radius - 28),
		Vector2(center.x + 14, center.y - radius - 28),
	]), Color.WHITE)

	# Center circle
	draw_circle(center, 18, Color(0.15, 0.15, 0.2))
	draw_circle(center, 15, Color(0.25, 0.25, 0.3))

	# Title
	var title = "BONUS WHEEL!"
	var title_w = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	draw_string(font, Vector2(center.x - title_w / 2, center.y - radius - 55), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 0.84, 0))

	# State text
	var msg = ""
	match state:
		0: msg = "CLICK TO STOP!"
		2:
			var w = _get_winner()
			msg = "YOU WON: " + segments[w].label + "!"
	if msg != "":
		var mw = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(font, Vector2(center.x - mw / 2, center.y + radius + 40), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.84, 0))
	if state == 2:
		var cont = "Click to continue"
		var cw = font.get_string_size(cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2(center.x - cw / 2, center.y + radius + 75), cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.8))

func _get_winner() -> int:
	var n = segments.size()
	var seg_angle = TAU / n
	var idx = fmod(-spin_angle, TAU)
	if idx < 0:
		idx += TAU
	return int(idx / seg_angle) % n
