extends Node

## Global manager for painting system input routing
## Handles automatic routing between 3D (Sprite3D) and 2D (SubViewport) painting systems
## based on raycast detection of canvas plane

# References to painting systems (set by world scene)
var painting_system_3d: PaintingSystem3D = null
var painting_system_2d: PaintingSystem2D = null
var painting_root_3d: Node3D = null
var painting_root_2d: Node3D = null
var extra_2d_systems: Array[PaintingSystem2D] = []

# Camera reference
var camera: Camera3D = null

# Raycast settings
@export var raycast_distance: float = 10.0

# Placement cooldown (prevents trigger spamming)
@export var placement_cooldown: float = 0.15  ## Cooldown in seconds between sticker placements
var last_placement_time: float = 0.0

# Signing state
var _is_signing: bool = false
var _active_signature: PaintingSignatureSystem = null

# Undo consumed flag — prevents analog left trigger from undoing multiple times per press in 2D
var _secondary_consumed: bool = false

# Audio
var tick_sound: AudioStreamPlayer
var tick_sound_layer2: AudioStreamPlayer
var tick_sound_layer3: AudioStreamPlayer

func _ready():
	# Setup tick sound for sticker cycling
	tick_sound = AudioStreamPlayer.new()
	tick_sound.stream = load("res://sounds/picotron/sine.ogg")
	tick_sound.volume_db = -5.0
	tick_sound.bus = "SFX"
	add_child(tick_sound)

	# Second layer for chord effect
	tick_sound_layer2 = AudioStreamPlayer.new()
	tick_sound_layer2.stream = load("res://sounds/picotron/sine.ogg")
	tick_sound_layer2.volume_db = -5.0
	tick_sound_layer2.bus = "SFX"
	add_child(tick_sound_layer2)

	# Third layer for lower octave
	tick_sound_layer3 = AudioStreamPlayer.new()
	tick_sound_layer3.stream = load("res://sounds/picotron/sine.ogg")
	tick_sound_layer3.volume_db = -5.0
	tick_sound_layer3.bus = "SFX"
	add_child(tick_sound_layer3)

func _process(_delta):
	# Handle continuous signing while button held
	if _is_signing:
		if Input.is_action_pressed("action_primary"):
			_continue_signing()
		else:
			_finish_signing()
		return

	# Handle sticker cycling (unified for both systems)
	if Input.is_action_just_pressed("cycle_sticker_prev"):
		cycle_sticker(-1)
	if Input.is_action_just_pressed("cycle_sticker_next"):
		cycle_sticker(1)

func cycle_sticker(direction: int):
	"""Cycle through stickers and sync both systems"""
	if StickerLibrary.sticker_library.is_empty():
		return

	# Use whichever system is available to get current index
	var system: Node = (painting_system_2d as Node) if painting_system_2d else (painting_system_3d as Node)
	if not system:
		return

	# Calculate new index
	var current_index = system.selected_sticker_index
	var new_index = (current_index + direction) % StickerLibrary.sticker_library.size()
	if new_index < 0:
		new_index = StickerLibrary.sticker_library.size() - 1

	# Sync to both systems
	sync_sticker_selection(new_index)

	# Play tick sound with chord effect
	if tick_sound:
		var base_pitch = 1.0
		tick_sound.pitch_scale = base_pitch
		tick_sound.play()

		# Play second layer with a perfect fifth interval (1.5x) for chord effect
		if tick_sound_layer2:
			tick_sound_layer2.pitch_scale = base_pitch * 1.5
			tick_sound_layer2.play()

		# 1/3 of the time: play third layer one octave higher (2x)
		# 2/3 of the time: play third layer one octave lower (0.5x)
		if tick_sound_layer3:
			var use_high_variant = randf() < 0.33
			if use_high_variant:
				tick_sound_layer3.pitch_scale = base_pitch * 2.0
			else:
				tick_sound_layer3.pitch_scale = base_pitch * 0.5
			tick_sound_layer3.play()

	# Emit signal from one system to update UI (avoid duplicate emissions)
	if system:
		system.layer_equipped.emit(new_index)

func _unhandled_input(event):
	"""Route painting input to appropriate system based on raycast target"""
	var should_place = false
	var should_undo = false

	# Reset undo consumed flag when left trigger is released
	if event.is_action_released("action_secondary"):
		_secondary_consumed = false

	# Detect painting actions
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			should_place = true
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingModeManager] Left click - should_place=true")
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			should_undo = true
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingModeManager] Right click - should_undo=true")
	elif event.is_action_pressed("action_primary"):
		should_place = true
	elif event.is_action_pressed("action_secondary"):
		should_undo = true

	# Check for signing on painting back face (before sticker logic)
	# Guard against re-triggering while already signing (analog trigger fires multiple events)
	if should_place and not _is_signing:
		var back_face_result = _check_back_face_raycast()
		if back_face_result:
			var sig_system = _find_signature_system(back_face_result.collider)
			if sig_system and not _is_painting_carried(back_face_result.collider):
				_active_signature = sig_system
				_is_signing = true
				sig_system.draw_at_world_position(back_face_result.position)
				get_viewport().set_input_as_handled()
				return

	# Handle placement action
	if should_place:
		# Cooldown check to prevent trigger spamming
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_placement_time < placement_cooldown:
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingModeManager] Cooldown active, ignoring click")
			return

		var raycast_result = _perform_unified_raycast()
		if not raycast_result:
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingModeManager] Raycast returned empty")
			return

		if DebugLogger and not OS.has_feature("editor"):
			var collider_name = raycast_result.collider.name if raycast_result.has("collider") else "null"
			DebugLogger.write_log("[PaintingModeManager] Raycast hit: %s" % collider_name)

		if _is_canvas_plane(raycast_result):
			# Route to whichever 2D system owns this canvas
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingModeManager] Canvas plane detected, routing to 2D system")
			var target_2d = _resolve_2d_system(raycast_result.collider)
			if target_2d:
				target_2d.handle_primary_action(raycast_result)
				last_placement_time = current_time
				get_viewport().set_input_as_handled()
		else:
			# Route to 3D system (with interactable check)
			var is_interactable = _is_raycast_hitting_interactable(raycast_result)
			if DebugLogger and not OS.has_feature("editor"):
				DebugLogger.write_log("[PaintingModeManager] Not canvas plane. Is interactable: %s" % is_interactable)
			if not is_interactable:
				if painting_system_3d:
					painting_system_3d.handle_primary_action(raycast_result)
					last_placement_time = current_time
					get_viewport().set_input_as_handled()

	# Handle undo action
	if should_undo:
		var raycast_result = _perform_unified_raycast()
		if _is_canvas_plane(raycast_result):
			# Undo from whichever 2D system owns this canvas
			var target_2d = _resolve_2d_system(raycast_result.collider)
			if target_2d and not _secondary_consumed:
				target_2d.handle_secondary_action()
				_secondary_consumed = true
				get_viewport().set_input_as_handled()
		else:
			# Undo from 3D system — no consumed guard (multi-fire while held is intentional)
			if painting_system_3d:
				painting_system_3d.handle_secondary_action(raycast_result)
				get_viewport().set_input_as_handled()

func _resolve_2d_system(collider: Node) -> PaintingSystem2D:
	"""Walk up from the hit collider to find the PaintingSystem2D for that specific canvas.
	Handles both PaintingRoot2D (mission canvas) and AssistantFinishedCanvas.
	Falls back to the registered painting_system_2d if none found."""
	var current = collider
	var depth := 0
	while current and depth < 8:
		if current is PaintingRoot2D:
			return current.painting_system
		# AssistantFinishedCanvas also exposes painting_system
		if current.get_script() != null and "painting_system" in current:
			var sys = current.get("painting_system")
			if sys is PaintingSystem2D:
				return sys
		current = current.get_parent()
		depth += 1
	return painting_system_2d  # fallback to registered mission canvas


func _perform_unified_raycast() -> Dictionary:
	"""Perform raycast from camera through mouse position"""
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return {}

	var viewport = camera.get_viewport()

	# Always use center-screen for controller-first gameplay
	var mouse_pos: Vector2 = viewport.get_visible_rect().size / 2.0

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * raycast_distance

	# Get world from camera (Node extends Node, doesn't have get_world_3d)
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	return space_state.intersect_ray(query)

func _is_canvas_plane(raycast_result: Dictionary) -> bool:
	"""Check if raycast hit the 2D painting canvas"""
	if not raycast_result or not raycast_result.has("collider"):
		return false

	var collider = raycast_result.collider

	# Primary: Check group membership
	if collider.is_in_group("2d_painting_canvas"):
		return true

	# Fallback: Check collision layer
	if collider.collision_layer & 4:  # Layer 4
		return true

	return false

func _is_raycast_hitting_interactable(raycast_result: Dictionary) -> bool:
	"""Check if raycast hit an interactable object (should block sticker placement)"""
	if not raycast_result or not raycast_result.has("collider"):
		return false

	var hit_object = raycast_result.collider

	# Walk up the node tree to find if this is part of an interactable
	var current = hit_object
	var max_depth = 10  # Prevent infinite loops
	var depth = 0

	while current and depth < max_depth:
		# Check if node is in "interactable" group
		if current.is_in_group("interactable"):
			return true

		# Check if node has CarryableComponent (pickupable objects)
		for child in current.get_children():
			if child is CarryableComponent:
				return true

		current = current.get_parent()
		depth += 1

	return false

func register_3d_system(system: PaintingSystem3D, root: Node3D):
	"""Register the 3D painting system"""
	painting_system_3d = system
	painting_root_3d = root

func register_2d_system(system: PaintingSystem2D, root: Node3D):
	"""Register the 2D painting system"""
	painting_system_2d = system
	painting_root_2d = root

func register_extra_2d_system(system: PaintingSystem2D) -> void:
	"""Register an additional 2D system (e.g. AssistantFinishedCanvas) for sticker sync."""
	if not extra_2d_systems.has(system):
		extra_2d_systems.append(system)

func sync_sticker_selection(index: int):
	"""Sync sticker selection across both systems"""
	if painting_system_3d:
		painting_system_3d.selected_sticker_index = index

	if painting_system_2d:
		painting_system_2d.selected_sticker_index = index
		# Update 2D preview to show the new sticker
		painting_system_2d._update_preview_texture()

	for sys in extra_2d_systems:
		if sys and is_instance_valid(sys):
			sys.selected_sticker_index = index
			sys._update_preview_texture()

# --- Signing Helpers ---

func _check_back_face_raycast() -> Dictionary:
	"""Raycast specifically for painting back face (layer 7 = bit 6 = mask 64)."""
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return {}

	var viewport = camera.get_viewport()
	var mouse_pos: Vector2 = viewport.get_visible_rect().size / 2.0
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * raycast_distance

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 64  # Layer 7 only
	query.collide_with_areas = false
	query.collide_with_bodies = true

	return space_state.intersect_ray(query)

func _find_signature_system(collider: Node) -> PaintingSignatureSystem:
	"""Walk up from the back face collider to find the PaintingSignatureSystem."""
	var current = collider
	var depth = 0
	while current and depth < 10:
		if current is CarryablePainting:
			return current.get_node_or_null("PaintingSignatureSystem") as PaintingSignatureSystem
		current = current.get_parent()
		depth += 1
	return null

func _is_painting_carried(collider: Node) -> bool:
	"""Check if the painting owning this collider is currently being carried."""
	var current = collider
	var depth = 0
	while current and depth < 10:
		if current is CarryablePainting:
			var hanging = current.get_node_or_null("PaintingHangingComponent")
			if hanging and "is_carried" in hanging:
				return hanging.is_carried
			return false
		current = current.get_parent()
		depth += 1
	return false

func _continue_signing():
	"""Called each frame while signing to draw at current raycast position."""
	if not _active_signature:
		_finish_signing()
		return

	var result = _check_back_face_raycast()
	if result:
		var sig_system = _find_signature_system(result.collider)
		if sig_system == _active_signature:
			_active_signature.draw_at_world_position(result.position)
			return

	# Raycast missed or hit different painting — end stroke but stay in signing mode
	_active_signature.finish_stroke()

func _finish_signing():
	"""End the current signing session."""
	if _active_signature:
		_active_signature.finish_stroke()
	_active_signature = null
	_is_signing = false
