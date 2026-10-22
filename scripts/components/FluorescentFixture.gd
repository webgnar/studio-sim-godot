extends Node3D
## Fluorescent fixture: the tubes glow and a soft bounce light comes on while
## the fixture's SpotLight3D is visible. Light switches only toggle the
## lights' visibility (LightSwitchInteraction), so this follows that.
##
## The fixture's lights are left out of the lightmap bake (they switch), so
## BounceFill stands in for the light they'd bounce around the room.

const TUBE_ON := preload("res://materials/fluorescent_tube_on.tres")
const TUBE_OFF := preload("res://materials/fluorescent_tube_off.tres")

@onready var _main_light: Light3D = $SpotLight3D
@onready var _bounce: Light3D = $BounceFill
@onready var _tubes: Array[MeshInstance3D] = [$bulb/fluor_bulb, $bulb2/fluor_bulb, $bulb3/fluor_bulb]

func _ready() -> void:
	_main_light.visibility_changed.connect(_sync)
	_sync()

func _sync() -> void:
	var on := _main_light.visible
	_bounce.visible = on
	for tube in _tubes:
		tube.material_override = TUBE_ON if on else TUBE_OFF
