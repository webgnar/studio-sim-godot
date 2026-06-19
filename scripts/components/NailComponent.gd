extends Node3D
class_name NailComponent

## Component for wall-mounted nails that serve as painting attachment points
## Physics-based passive detection - paintings rest on nail via collision

# --- SIGNALS ---
signal painting_detected_resting(painting: CarryablePainting)
signal painting_left(painting: CarryablePainting)

# --- PRIVATE VARIABLES ---
var paintings_in_contact: Array[CarryablePainting] = []
var nail_id: String = ""
var _dither_shader: Shader = preload("res://shaders/dither_fade.gdshader")

# --- GODOT METHODS ---

func _ready() -> void:
	# Generate unique ID for save system
	nail_id = "nail_" + str(get_instance_id())

	# Add to nails group for discovery
	add_to_group("nails")

	# Register with WorldStateManager for save/load
	WorldStateManager.register_nail(self, nail_id)

	# Connect to detection area signals for tracking
	var peg = get_node_or_null("../NailPeg")
	if peg:
		var detection_area = peg.get_node_or_null("DetectionArea")
		if detection_area and detection_area is Area3D:
			detection_area.area_entered.connect(_on_peg_area_entered)
			detection_area.area_exited.connect(_on_peg_area_exited)
			print("✓ Nail detection area connected")

func _exit_tree() -> void:
	# Unregister when removed from scene
	WorldStateManager.unregister_nail(self)

# --- CONTACT DETECTION ---

func _on_peg_area_entered(area: Area3D) -> void:
	"""Called when a stretcher bar Area3D enters nail detection area"""
	# Check if this area belongs to a painting
	var painting = _find_painting_from_area(area)
	if painting and painting not in paintings_in_contact:
		paintings_in_contact.append(painting)
		painting_detected_resting.emit(painting)
		print("✓ Nail detected painting: ", painting.name)

func _on_peg_area_exited(area: Area3D) -> void:
	"""Called when a stretcher bar Area3D leaves nail detection area"""
	var painting = _find_painting_from_area(area)
	if painting and painting in paintings_in_contact:
		paintings_in_contact.erase(painting)
		painting_left.emit(painting)
		print("✗ Nail lost painting: ", painting.name)

func _find_painting_from_area(area: Area3D) -> CarryablePainting:
	"""Find the CarryablePainting that owns this stretcher bar Area3D"""
	# Area3D -> StretcherBarsPhysics -> CarryablePainting
	if area.get_parent() and area.get_parent().get_parent():
		var potential_painting = area.get_parent().get_parent()
		if potential_painting is CarryablePainting:
			return potential_painting
	return null

func start_dither_fade(delay: float = 2.0, duration: float = 1.0) -> void:
	var parent := get_parent()
	if not parent:
		return

	var mesh := _find_mesh_in(parent)
	if not mesh:
		return

	await get_tree().create_timer(delay).timeout

	var overlay_mat := ShaderMaterial.new()
	overlay_mat.shader = _dither_shader
	overlay_mat.set_shader_parameter("progress", 0.0)
	overlay_mat.set_shader_parameter("dither_scale", 4.0)
	mesh.material_overlay = overlay_mat

	var tween := create_tween()
	tween.tween_property(overlay_mat, "shader_parameter/progress", 1.0, duration)
	tween.finished.connect(func(): parent.queue_free())

func _find_mesh_in(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result := _find_mesh_in(child)
		if result:
			return result
	return null
