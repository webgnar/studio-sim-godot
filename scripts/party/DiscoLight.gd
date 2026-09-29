extends SpotLight3D
class_name DiscoLight
## Sweeping, color-cycling spotlight for the DJ dance party. Hang it near the ceiling pointing
## roughly down (its -Z is the beam direction); it wobbles around that rest aim and steps
## through `colors`. Adds a soft visible beam cone unless `show_beam` is off.
## Only animates while its DanceParty rig is processing (the party disables the rig otherwise).

@export var colors: Array[Color] = [
	Color(1.0, 0.1, 0.6), Color(0.2, 0.4, 1.0), Color(0.1, 1.0, 0.6),
	Color(1.0, 0.8, 0.1), Color(0.7, 0.2, 1.0), Color(1.0, 0.3, 0.1),
]
@export var color_step_time: float = 0.47 ## seconds per color (~128 bpm)
@export var sweep_yaw_degrees: float = 40.0
@export var sweep_pitch_degrees: float = 22.0
@export var sweep_speed: float = 0.6
@export var phase: float = 0.0 ## offset so a row of lights doesn't move in lockstep
@export var show_beam: bool = true
@export var beam_intensity: float = 0.18

const _BEAM_SHADER := preload("res://shaders/party_beam.gdshader")

var _rest_basis: Basis
var _t: float = 0.0
var _color_index: int = 0
var _color_timer: float = 0.0
var _beam_mat: ShaderMaterial


func _ready() -> void:
	_rest_basis = transform.basis
	shadow_enabled = false
	_t = phase
	_color_index = int(abs(phase) * 7.0) % max(colors.size(), 1)
	if show_beam:
		_build_beam()
	_apply_color(1.0)


func _process(delta: float) -> void:
	_t += delta * sweep_speed
	var yaw := deg_to_rad(sweep_yaw_degrees) * sin(_t)
	var pitch := deg_to_rad(sweep_pitch_degrees) * sin(_t * 1.7 + 1.3)
	transform.basis = _rest_basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)

	_color_timer += delta
	if _color_timer >= color_step_time:
		_color_timer = 0.0
		_color_index = (_color_index + 1) % max(colors.size(), 1)
	# Quick flash-in at each step, then settle, so the color changes read as beats.
	_apply_color(1.0 + 0.8 * (1.0 - clampf(_color_timer / (color_step_time * 0.35), 0.0, 1.0)))


func _apply_color(flash: float) -> void:
	if colors.is_empty():
		return
	var c: Color = colors[_color_index]
	light_color = c
	if _beam_mat:
		_beam_mat.set_shader_parameter("beam_color", c)
		_beam_mat.set_shader_parameter("intensity", beam_intensity * flash)


func _build_beam() -> void:
	var length: float = spot_range * 0.8
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = tan(deg_to_rad(spot_angle)) * length
	cone.height = length
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = _BEAM_SHADER
	_beam_mat.set_shader_parameter("narrow_end_at_top", true)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cone
	beam.material_override = _beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cylinder axis is +Y (top = narrow end). Rotating +90 degrees about X turns +Y into +Z, so
	# with the mesh centred at -length/2 the narrow end sits at the lamp and it opens along -Z.
	beam.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -length / 2.0))
	add_child(beam)
