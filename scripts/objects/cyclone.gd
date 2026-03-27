extends Node3D
class_name Cyclone

@export var light_parent: Node3D
@export var result_label_1: Label3D
@export var result_label_2: Label3D
@export var result_label_3: Label3D

var lights: Array[MeshInstance3D]
var mat_light_off: Material
var mat_light_on: StandardMaterial3D
var current_light: int = 0
var stopped: bool = false

# Win position indices, found by name in _ready()
# button 1 = cyclonelights_024, button 2 = cyclonelights_048, button 3 = cyclonelights
var win_index: Array[int] = [-1, -1, -1]


func _ready() -> void:
	for i in light_parent.get_children().size():
		var child = light_parent.get_child(i)
		if child is MeshInstance3D:
			lights.append(child)
			match child.name:
				"cyclonelights_024": win_index[0] = lights.size() - 1
				"cyclonelights_048": win_index[1] = lights.size() - 1
				"cyclonelights":     win_index[2] = lights.size() - 1

	if lights.size() > 0:
		mat_light_off = lights[0].get_active_material(0)

	mat_light_on = StandardMaterial3D.new()
	mat_light_on.emission_enabled = true
	mat_light_on.emission = Color(0.0, 1.0, 1.0)
	mat_light_on.emission_energy_multiplier = 3.0

	print("Cyclone win indices — btn1:%d  btn2:%d  btn3:%d" % [win_index[0], win_index[1], win_index[2]])


func _physics_process(_delta: float) -> void:
	if not stopped:
		next_light()


func next_light() -> void:
	lights[current_light].set_surface_override_material(0, mat_light_off)
	current_light += 1
	if current_light >= lights.size():
		current_light = 0
	lights[current_light].set_surface_override_material(0, mat_light_on)


func is_winner(button_number: int) -> bool:
	var idx := win_index[button_number - 1]
	return idx != -1 and current_light == idx


func get_result_label(button_number: int) -> Label3D:
	match button_number:
		1: return result_label_1
		2: return result_label_2
		3: return result_label_3
	return null


func clear_all_labels() -> void:
	for lbl in [result_label_1, result_label_2, result_label_3]:
		if lbl:
			lbl.text = ""
