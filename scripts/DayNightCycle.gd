extends Node

@export_group("Speed (degrees/sec)")
@export var speed_morning: float = 1.0
@export var speed_day: float     = 1.0
@export var speed_dusk: float    = 1.0
@export var speed_night: float   = 1.0

@onready var _dir_light: DirectionalLight3D = get_node_or_null("sun root/SunSphere/DirectionalLight3D2")
@onready var _fill_light: DirectionalLight3D = get_parent().get_node_or_null("DirectionalLight3D")
@onready var _world_env: WorldEnvironment = get_parent().get_node("WorldEnvironment")
@onready var _sun_mesh: Node3D = get_node_or_null("sun root")
var _sky_mat: ShaderMaterial
var _sun_mat: ShaderMaterial
var _phase: String = ""
var _sun_deg: float = 5.0   # start at sunrise
var _debug_timer: float = 0.0

# Sky top color at each phase boundary
const C_TOP_MORNING := Color(0.60, 0.30, 0.10)
const C_TOP_DAY     := Color(0.19, 0.61, 1.00)
const C_TOP_DUSK    := Color(0.55, 0.20, 0.08)
const C_TOP_NIGHT   := Color(0.01, 0.01, 0.06)

# Sky horizon color at each phase boundary
const C_HOR_MORNING := Color(0.95, 0.50, 0.15)
const C_HOR_DAY     := Color(0.88, 0.80, 0.75)
const C_HOR_DUSK    := Color(0.90, 0.40, 0.10)
const C_HOR_NIGHT   := Color(0.02, 0.02, 0.12)

# Directional light color at each phase boundary
const C_SUN_MORNING := Color(1.0, 0.55, 0.20)
const C_SUN_DAY     := Color(1.0, 0.98, 0.90)
const C_SUN_DUSK    := Color(1.0, 0.55, 0.20)
const C_SUN_NIGHT   := Color(0.0, 0.0,  0.0 )

# Fill/moon light color (root DirectionalLight3D acts as ambient during day, moon glow at night)
const C_FILL_DAY   := Color(0.80, 0.85, 1.00)
const C_FILL_NIGHT := Color(0.15, 0.20, 0.35)

func _ready() -> void:
	_sky_mat = _world_env.environment.sky.sky_material as ShaderMaterial
	var sun_sphere := get_node_or_null("sun root/SunSphere") as MeshInstance3D
	if sun_sphere:
		_sun_mat = sun_sphere.get_surface_override_material(0) as ShaderMaterial
	if not _sun_mesh:
		print("[DayNight] WARNING: 'sun root' not found. Children: ",
			get_children().map(func(c): return c.name))
	if not _dir_light:
		print("[DayNight] WARNING: DirectionalLight3D2 not found at sun root/SunSphere/DirectionalLight3D2")

func _process(delta: float) -> void:
	if not _sun_mesh or not _dir_light:
		return

	_update_phase()
	_sun_deg = fmod(_sun_deg + _current_speed() * delta, 360.0)
	_sun_mesh.rotation_degrees = Vector3(_sun_deg, 0.0, 0.0)

	var sky_rot := _world_env.environment.sky_rotation
	sky_rot.y += 0.05 * delta
	_world_env.environment.sky_rotation = sky_rot

	_update_lighting()

func _update_phase() -> void:
	var new_phase: String
	if _sun_deg < 30.0:
		new_phase = "morning"
	elif _sun_deg < 135.0:
		new_phase = "day"
	elif _sun_deg < 180.0:
		new_phase = "dusk"
	else:
		new_phase = "night"
	if new_phase != _phase:
		_phase = new_phase
		print("[DayNight] ", _phase.to_upper(), "  (%.1f°)" % _sun_deg)

func _update_lighting() -> void:
	var rad := deg_to_rad(_sun_deg)
	var elevation := sin(rad)

	_dir_light.light_energy = clamp(elevation, 0.0, 1.0) * 1.2
	_dir_light.light_color  = _phase_color(C_SUN_MORNING, C_SUN_DAY, C_SUN_DUSK, C_SUN_NIGHT)
	_sky_mat.set_shader_parameter("sky_top_color",     _phase_color(C_TOP_MORNING, C_TOP_DAY, C_TOP_DUSK, C_TOP_NIGHT))
	_sky_mat.set_shader_parameter("sky_horizon_color", _phase_color(C_HOR_MORNING, C_HOR_DAY, C_HOR_DUSK, C_HOR_NIGHT))

	var night_blend: float
	if _sun_deg < 30.0:
		night_blend = 1.0 - (_sun_deg / 30.0)       # dawn: stars fade out 1→0
	elif _sun_deg < 135.0:
		night_blend = 0.0                             # full day
	elif _sun_deg < 180.0:
		night_blend = (_sun_deg - 135.0) / 45.0      # dusk: 0→1 over 45° (matches dusk phase)
	else:
		night_blend = 1.0                             # full night from 180° onward
	_sky_mat.set_shader_parameter("night_blend", night_blend)

	if _fill_light:
		_fill_light.light_color  = C_FILL_DAY.lerp(C_FILL_NIGHT, night_blend)
		_fill_light.light_energy = lerpf(0.15, 0.4, night_blend)

	if _sun_mat:
		var sc := _phase_color(C_SUN_MORNING, C_SUN_DAY, C_SUN_DUSK, C_SUN_NIGHT)
		_sun_mat.set_shader_parameter("sun_color", sc)
		_sun_mat.set_shader_parameter("hot_color", sc.lerp(Color(1.0, 0.98, 0.90), 0.5))

func _current_speed() -> float:
	match _phase:
		"morning": return speed_morning
		"day":     return speed_day
		"dusk":    return speed_dusk
		_:         return speed_night

func _phase_color(morning: Color, day: Color, dusk: Color, night: Color) -> Color:
	if _sun_deg < 30.0:
		return night.lerp(morning, _sun_deg / 30.0)
	elif _sun_deg < 135.0:
		return morning.lerp(day, (_sun_deg - 30.0) / 105.0)
	elif _sun_deg < 180.0:
		return day.lerp(dusk, (_sun_deg - 135.0) / 45.0)
	else:
		return dusk.lerp(night, clamp((_sun_deg - 180.0) / 30.0, 0.0, 1.0))
