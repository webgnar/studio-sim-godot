extends Node3D

const SEGMENT_RATE = 12.0
const SEGMENT_LENGTH = 1.0
const PIPE_RADIUS = 0.15
const MAX_SEGMENTS = 200
const ELBOW_CHANCE = 0.12
const BOUND_RADIUS = 7.0  # force turn toward center when pipe drifts this far

var _dir := Vector3.RIGHT
var _pos := Vector3.ZERO
var _hue: float = 0.0
var _time_accum: float = 0.0
var _segments: Array = []

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	randomize()
	_hue = randf()
	_dir = _random_dir()
	_add_segment()

func _process(delta: float) -> void:
	# Camera orbits slowly, always looking at origin (where pipes are bounded)
	var t = Time.get_ticks_msec() * 0.0002
	_camera.position = Vector3(sin(t) * 3.0, 2.0 + sin(t * 0.5) * 1.0, -7.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	_time_accum += delta
	var step = 1.0 / SEGMENT_RATE
	while _time_accum >= step:
		_time_accum -= step
		_grow()

func _grow() -> void:
	while _segments.size() >= MAX_SEGMENTS:
		var old = _segments.pop_front()
		old.queue_free()

	# Force a turn toward center when too far out so pipes stay in camera view
	if _pos.length() > BOUND_RADIUS:
		_dir = _toward_center_dir()
	elif randf() < ELBOW_CHANCE:
		_dir = _random_dir()

	_pos += _dir * SEGMENT_LENGTH
	_add_segment()

func _add_segment() -> void:
	var mesh = CylinderMesh.new()
	mesh.height = SEGMENT_LENGTH
	mesh.top_radius = PIPE_RADIUS
	mesh.bottom_radius = PIPE_RADIUS

	var mi = MeshInstance3D.new()
	mi.mesh = mesh

	var mat = StandardMaterial3D.new()
	_hue = fmod(_hue + 0.03, 1.0)
	var col = Color.from_hsv(_hue, 0.7, 1.0)
	mat.albedo_color = col
	mat.metallic = 0.4
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat

	add_child(mi)
	# CylinderMesh is Y-axis aligned — build a basis that maps Y → _dir
	mi.transform.origin = _pos - _dir * SEGMENT_LENGTH * 0.5
	mi.transform.basis = _basis_from_dir(_dir)

	_segments.append(mi)

func _basis_from_dir(dir: Vector3) -> Basis:
	if dir == Vector3.UP:
		return Basis.IDENTITY
	if dir == Vector3.DOWN:
		return Basis(Vector3.RIGHT, PI)
	# Rotate Y-axis onto dir: axis = Y.cross(dir), angle = PI/2
	return Basis(Vector3.UP.cross(dir).normalized(), PI / 2.0)

func _toward_center_dir() -> Vector3:
	var toward = -_pos.normalized()
	var dirs = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	var best = dirs[0]
	var best_dot = dirs[0].dot(toward)
	for d in dirs:
		var dot = d.dot(toward)
		if dot > best_dot:
			best_dot = dot
			best = d
	return best

func _random_dir() -> Vector3:
	var dirs = [
		Vector3.RIGHT, Vector3.LEFT,
		Vector3.UP, Vector3.DOWN,
		Vector3.FORWARD, Vector3.BACK,
	]
	return dirs[randi() % dirs.size()]

func reset() -> void:
	for s in _segments:
		s.queue_free()
	_segments.clear()
	_pos = Vector3.ZERO
	_dir = _random_dir()
	_hue = randf()
	_time_accum = 0.0
	_add_segment()
