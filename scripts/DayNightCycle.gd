extends Node

@export var degrees_per_second: float = 6.0  # 360/6 = 60s full day. Tweak in Inspector.

@onready var _dir_light: DirectionalLight3D = get_node_or_null("sun root/SunSphere/DirectionalLight3D2")
@onready var _fill_light: DirectionalLight3D = get_parent().get_node_or_null("DirectionalLight3D")
@onready var _world_env: WorldEnvironment = get_parent().get_node("WorldEnvironment")
@onready var _sun_mesh: Node3D = get_node_or_null("sun root")
var _sky_mat: ShaderMaterial
var _phase: String = ""
var _sun_deg: float = 0.0  # current rotation in degrees, 0=Dawn

# Color keyframes mapped to the 0-360 arc:
# 0=Dawn/midnight-wrap, 90=Noon, 180=Dusk/midnight, repeat
const SKY_TOPS = [
	Color(0.01, 0.01, 0.06),  # 0   dawn
	Color(0.60, 0.30, 0.10),  # 45  mid-morning
	Color(0.19, 0.61, 1.00),  # 90  noon
	Color(0.55, 0.20, 0.08),  # 135 mid-afternoon
	Color(0.01, 0.01, 0.06),  # 180 dusk → night
	Color(0.01, 0.01, 0.06),  # 360 wrap
]
const SKY_HORIZONS = [
	Color(0.95, 0.50, 0.15),
	Color(0.88, 0.80, 0.75),
	Color(0.88, 0.80, 0.75),
	Color(0.90, 0.40, 0.10),
	Color(0.02, 0.02, 0.12),
	Color(0.95, 0.50, 0.15),
]
const SUN_COLORS = [
	Color(1.0,  0.55, 0.20),
	Color(1.0,  0.90, 0.70),
	Color(1.0,  0.98, 0.90),
	Color(1.0,  0.70, 0.30),
	Color(0.0,  0.0,  0.0 ),
	Color(1.0,  0.55, 0.20),
]

func _ready() -> void:
	_sky_mat = _world_env.environment.sky.sky_material as ShaderMaterial
	if not _sun_mesh:
		print("[DayNight] WARNING: 'sun root' not found. Children: ",
			get_children().map(func(c): return c.name))
	if not _dir_light:
		print("[DayNight] WARNING: DirectionalLight3D2 not found at sun root/SunSphere/DirectionalLight3D2")

func _process(delta: float) -> void:
	if not _sun_mesh or not _dir_light:
		return

	_sun_deg = fmod(_sun_deg + degrees_per_second * delta, 360.0)
	_sun_mesh.rotation_degrees = Vector3(_sun_deg, 0.0, 0.0)

	var sky_rot := _world_env.environment.sky_rotation
	sky_rot.y += 0.05 * delta
	_world_env.environment.sky_rotation = sky_rot

	_update_phase()
	_update_lighting()

func _update_phase() -> void:
	var new_phase: String
	if _sun_deg < 1.0 or _sun_deg >= 359.0:
		new_phase = "dawn"
	elif _sun_deg < 90.0:
		new_phase = "morning"
	elif _sun_deg < 91.0:
		new_phase = "noon"
	elif _sun_deg < 180.0:
		new_phase = "afternoon"
	elif _sun_deg < 181.0:
		new_phase = "dusk"
	else:
		new_phase = "night"
	if new_phase != _phase:
		_phase = new_phase
		print("[DayNight] ", _phase.to_upper(), "  (%.1f°)" % _sun_deg)

func _update_lighting() -> void:
	var rad := deg_to_rad(_sun_deg)
	var elevation := sin(rad)  # 0 at dawn/dusk, 1 at noon, -1 at midnight

	_dir_light.light_energy = clamp(elevation, 0.0, 1.0) * 1.2
	_dir_light.light_color = _sample_deg(SUN_COLORS, _sun_deg)
	_sky_mat.set_shader_parameter("sky_top_color",     _sample_deg(SKY_TOPS,     _sun_deg))
	_sky_mat.set_shader_parameter("sky_horizon_color", _sample_deg(SKY_HORIZONS, _sun_deg))

func _sample_deg(frames: Array, deg: float) -> Color:
	# Evenly space keyframes across 0-360
	var n := frames.size() - 1
	var ft := (deg / 360.0) * n
	var i := int(ft) % n
	var frac := ft - int(ft)
	return frames[i].lerp(frames[i + 1], frac)
