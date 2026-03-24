extends Node3D

@export_multiline var credits_text: String = "CREDITS\n\nYour text here..."
@export var scroll_speed: float = 30.0

@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _screen: MeshInstance3D = $Screen
@onready var _label: RichTextLabel = $SubViewport/CreditsLabel

var _label_height: float = 0.0
var _viewport_height: float = 640.0

func _ready() -> void:
	var mat: ShaderMaterial = preload("res://materials/tv.tres").duplicate()
	mat.set_shader_parameter("tv_tex", _sub_viewport.get_texture())
	_screen.material_override = mat

	_label.text = credits_text
	_viewport_height = float(_sub_viewport.size.y)

	await get_tree().process_frame
	_label_height = float(_label.get_content_height())
	_label.position.y = _viewport_height

func _process(delta: float) -> void:
	_label.position.y -= scroll_speed * delta
	if _label.position.y + _label_height < 0:
		_label.position.y = _viewport_height
