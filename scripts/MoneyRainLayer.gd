extends CanvasLayer

const BILLS_PER_DOLLAR = 0.2  # 1 bill per $5 earned
const SPAWN_SPREAD = 1.5  # seconds over which bills stagger in

var _frames: SpriteFrames
var _sfx: AudioStreamPlayer

func _ready():
	layer = 102
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_frames()
	_build_sfx()
	if has_node("/root/EconomyManager"):
		EconomyManager.painting_sold.connect(_on_painting_sold)

func _build_frames():
	var sheet: Texture2D = load("res://sprites/dollarsheet.png")
	_frames = SpriteFrames.new()
	_frames.add_animation("flap")
	_frames.set_animation_loop("flap", true)
	_frames.set_animation_speed("flap", 8.0)
	for i in 10:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * 48, 0, 48, 48)
		_frames.add_frame("flap", atlas)

func _build_sfx():
	_sfx = AudioStreamPlayer.new()
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx.bus = "SFX"
	var stream = load("res://sounds/picotron/get money.ogg")
	if stream:
		_sfx.stream = stream
	add_child(_sfx)

func _on_painting_sold(amount: int, _source: String):
	if _sfx.stream:
		_sfx.play()
	var count := int(amount * BILLS_PER_DOLLAR)
	for i in count:
		_spawn_bill_delayed()

func _spawn_bill_delayed():
	await get_tree().create_timer(randf_range(0.0, SPAWN_SPREAD), true).timeout
	var vp := get_viewport().get_visible_rect().size
	var bill := AnimatedSprite2D.new()
	bill.sprite_frames = _frames
	bill.animation = "flap"
	bill.process_mode = Node.PROCESS_MODE_ALWAYS
	bill.play()
	bill.position = Vector2(randf_range(0.0, vp.x), -60.0)
	bill.scale = Vector2.ONE * randf_range(0.8, 1.5)
	bill.rotation = randf_range(-0.4, 0.4)
	add_child(bill)
	var duration := randf_range(3.0, 6.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(bill, "position:y", vp.y + 80.0, duration)
	tween.tween_property(bill, "rotation", bill.rotation + randf_range(-PI * 0.5, PI * 0.5), duration)
	tween.chain().tween_callback(bill.queue_free)
