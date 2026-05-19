extends Node

@export var cycle_duration: float = 300.0  # seconds per full day (5 real minutes)

var time_of_day: float = 0.45  # 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset

@onready var _dir_light: DirectionalLight3D = get_parent().get_node("DirectionalLight3D2")
@onready var _world_env: WorldEnvironment = get_parent().get_node("WorldEnvironment")
var _sky_mat: ShaderMaterial
var _sun_mesh: MeshInstance3D

const SUN_DISTANCE := 450.0
const SUN_RADIUS   := 18.0

# Color keyframes: [midnight, sunrise, noon, sunset, midnight(wrap)]
const SKY_TOPS = [
	Color(0.01, 0.01, 0.06),
	Color(0.60, 0.30, 0.10),
	Color(0.19, 0.61, 1.00),
	Color(0.55, 0.20, 0.08),
	Color(0.01, 0.01, 0.06),
]
const SKY_HORIZONS = [
	Color(0.02, 0.02, 0.12),
	Color(0.95, 0.50, 0.15),
	Color(0.88, 0.80, 0.75),
	Color(0.90, 0.40, 0.10),
	Color(0.02, 0.02, 0.12),
]
const SUN_COLORS = [
	Color(0.0,  0.0,  0.0 ),
	Color(1.0,  0.55, 0.20),
	Color(1.0,  0.98, 0.90),
	Color(1.0,  0.55, 0.20),
	Color(0.0,  0.0,  0.0 ),
]

func _ready() -> void:
	_sky_mat = _world_env.environment.sky.sky_material as ShaderMaterial
	_create_sun_mesh()
	WorldStateManager.world_state_loaded.connect(_on_state_loaded)

func _on_state_loaded() -> void:
	time_of_day = float(WorldStateManager.get_data("time_of_day", 0.45))

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / cycle_duration, 1.0)
	WorldStateManager.set_data("time_of_day", time_of_day)
	_world_env.environment.sky_rotation.y += 0.05 * delta
	_update_sun()
	_update_sky()

func _update_sun() -> void:
	var angle := (time_of_day - 0.25) * TAU
	# Negative so positive angle tilts toward ground (noon = -PI/2 = pointing down)
	_dir_light.rotation.x = -angle
	var elevation := sin(angle)  # 1 at noon, 0 at horizon, negative at night
	_dir_light.light_energy = clamp(elevation, 0.0, 1.0) * 1.2
	var sun_color := _sample_keyframes(SUN_COLORS, time_of_day)
	_dir_light.light_color = sun_color

	# Sun sphere: sits in the direction the light comes FROM (local +Z of the light)
	var sun_dir := _dir_light.global_transform.basis.z
	_sun_mesh.global_position = sun_dir * SUN_DISTANCE
	_sun_mesh.visible = elevation > -0.05
	var mat := _sun_mesh.get_surface_override_material(0) as StandardMaterial3D
	mat.albedo_color = sun_color
	mat.emission = sun_color

func _update_sky() -> void:
	_sky_mat.set_shader_parameter("sky_top_color",     _sample_keyframes(SKY_TOPS,     time_of_day))
	_sky_mat.set_shader_parameter("sky_horizon_color", _sample_keyframes(SKY_HORIZONS, time_of_day))

func _create_sun_mesh() -> void:
	_sun_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = SUN_RADIUS
	sphere.height = SUN_RADIUS * 2.0
	_sun_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.7)
	mat.emission_energy_multiplier = 3.0
	_sun_mesh.set_surface_override_material(0, mat)
	_sun_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_sun_mesh)

func _sample_keyframes(frames: Array, t: float) -> Color:
	var n := frames.size() - 1
	var ft := t * n
	var i := int(ft) % n
	var frac := ft - int(ft)
	return frames[i].lerp(frames[i + 1], frac)
