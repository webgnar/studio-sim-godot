extends Node

## Singleton for exporting paintings to the player's Downloads folder
## Handles both PNG (2D image) and GLB (3D model) export formats

signal export_started(painting: CarryablePainting)
signal export_completed(png_path: String, glb_path: String)
signal export_failed(error_message: String)

# Preload stretcher model for GLB export
var stretcher_scene = preload("res://models/paintings/stretcher.glb")

func get_downloads_folder() -> String:
	"""Returns the path to the user's Downloads folder, cross-platform"""
	var os_name = OS.get_name()

	match os_name:
		"Windows":
			var userprofile = OS.get_environment("USERPROFILE")
			if userprofile != "":
				return userprofile + "\\Downloads"
			return OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		"macOS", "OSX":
			var home = OS.get_environment("HOME")
			if home != "":
				return home + "/Downloads"
			return OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		"Linux", "FreeBSD":
			var xdg = OS.get_environment("XDG_DOWNLOAD_DIR")
			if xdg != "":
				return xdg
			var home = OS.get_environment("HOME")
			if home != "":
				return home + "/Downloads"
			return OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		_:
			return OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)

func _generate_filename_base() -> String:
	"""Generate a unique filename base using timestamp"""
	var datetime = Time.get_datetime_dict_from_system()
	return "painting_%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

func export_painting(painting: CarryablePainting) -> Dictionary:
	"""Export painting as both PNG and GLB. Returns dict with paths or empty on failure."""
	export_started.emit(painting)

	var downloads = get_downloads_folder()

	# Use painting name for filename if available, otherwise fall back to timestamp
	var filename_base: String
	if painting.painting_name != "":
		filename_base = _sanitize_filename(painting.painting_name)
	else:
		filename_base = _generate_filename_base()

	# Export PNG
	var png_path = export_painting_png(painting, downloads, filename_base)
	if png_path.is_empty():
		export_failed.emit("Failed to export PNG")
		return {}

	# Export GLB
	var glb_path = export_painting_glb(painting, downloads, filename_base)
	if glb_path.is_empty():
		export_failed.emit("Failed to export GLB")
		return {}

	export_completed.emit(png_path, glb_path)

	return {
		"png": png_path,
		"glb": glb_path
	}

func _sanitize_filename(name: String) -> String:
	"""Remove/replace characters that are invalid in filenames"""
	var sanitized = name.strip_edges()
	var invalid_chars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|']
	for c in invalid_chars:
		sanitized = sanitized.replace(c, "_")
	if sanitized.length() > 100:
		sanitized = sanitized.substr(0, 100)
	if sanitized.is_empty():
		return _generate_filename_base()
	return sanitized

func export_painting_png(painting: CarryablePainting, downloads_path: String, filename_base: String) -> String:
	"""Export painting texture as PNG file"""
	var full_path = downloads_path.path_join(filename_base + ".png")

	# Get texture from painting's MeshInstance3D material
	var mesh_instance = painting.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		push_error("PaintingExporter: No MeshInstance3D found on painting")
		return ""

	var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if not material:
		push_error("PaintingExporter: No material found on painting mesh")
		return ""

	var texture = material.albedo_texture
	if not texture:
		push_error("PaintingExporter: No albedo texture found on painting material")
		return ""

	var image: Image
	if texture is ImageTexture:
		image = texture.get_image()
	elif texture is ViewportTexture:
		image = texture.get_image()
	else:
		push_error("PaintingExporter: Unsupported texture type: " + texture.get_class())
		return ""

	if not image:
		push_error("PaintingExporter: Failed to get image from texture")
		return ""

	# Fix rotation: in-game texture is rotated 90° left, so rotate right to correct
	image.rotate_90(CLOCKWISE)

	var error = image.save_png(full_path)
	if error != OK:
		push_error("PaintingExporter: Failed to save PNG: " + str(error))
		return ""

	print("PaintingExporter: Saved PNG to ", full_path)

	return full_path

func export_painting_glb(painting: CarryablePainting, downloads_path: String, filename_base: String) -> String:
	"""Export painting as GLB with stretcher frame and textured canvas"""
	var full_path = downloads_path.path_join(filename_base + ".glb")

	# Create a temporary scene for export
	var export_root = Node3D.new()
	export_root.name = "ExportedPainting"

	# Clone stretcher bar model
	var stretcher = stretcher_scene.instantiate()
	stretcher.name = "StretcherFrame"
	# Apply same transform as in CarryablePainting.tscn
	stretcher.transform = Transform3D(
		Vector3(0.045, 0, 0),
		Vector3(0, -1.9670126e-09, 0.045),
		Vector3(0, -0.045, -1.9670126e-09),
		Vector3(0, -0.07518089, 0)
	)
	export_root.add_child(stretcher)
	stretcher.owner = export_root
	_set_owner_recursive(stretcher, export_root)

	# Create canvas plane with baked texture
	var canvas_mesh = MeshInstance3D.new()
	canvas_mesh.name = "Canvas"
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(3, 3)  # Match CarryablePainting canvas size
	canvas_mesh.mesh = plane_mesh

	# Get painting texture
	var mesh_instance = painting.get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		push_error("PaintingExporter: No MeshInstance3D found on painting for GLB export")
		export_root.queue_free()
		return ""

	var src_material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if not src_material or not src_material.albedo_texture:
		push_error("PaintingExporter: No texture found for GLB export")
		export_root.queue_free()
		return ""

	# Create new material for export with the painting texture
	var export_material = StandardMaterial3D.new()

	# Get the image and create a new ImageTexture for export
	var src_texture = src_material.albedo_texture
	var image: Image
	if src_texture is ImageTexture:
		image = src_texture.get_image()
	elif src_texture is ViewportTexture:
		image = src_texture.get_image()
	else:
		image = src_texture.get_image()

	if image:
		# Fix rotation: in-game texture is rotated 90° left, so rotate right to correct
		image.rotate_90(CLOCKWISE)
		var export_texture = ImageTexture.create_from_image(image)
		export_material.albedo_texture = export_texture

	export_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	export_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canvas_mesh.set_surface_override_material(0, export_material)

	export_root.add_child(canvas_mesh)
	canvas_mesh.owner = export_root

	# Add signature back-face plane if present
	var sig_system = painting.get_node_or_null("PaintingSignatureSystem") as PaintingSignatureSystem
	if sig_system and sig_system.has_signature():
		var back_mesh = MeshInstance3D.new()
		back_mesh.name = "SignatureCanvas"
		var back_plane = PlaneMesh.new()
		back_plane.size = Vector2(3, 3)
		back_mesh.mesh = back_plane
		# Flip to face opposite direction from front canvas, offset behind it
		back_mesh.transform = Transform3D(
			Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, -0.15, 0)
		)

		# Use raw signature image — transparent background, opaque black strokes only
		var sig_image = sig_system.get_signature_image().duplicate()

		var sig_material = StandardMaterial3D.new()
		sig_material.albedo_texture = ImageTexture.create_from_image(sig_image)
		sig_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sig_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		back_mesh.set_surface_override_material(0, sig_material)

		export_root.add_child(back_mesh)
		back_mesh.owner = export_root
	# Use GLTFDocument to export
	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()

	var error = gltf_document.append_from_scene(export_root, gltf_state)
	if error != OK:
		push_error("PaintingExporter: Failed to create GLTF from scene: " + str(error))
		export_root.queue_free()
		return ""

	error = gltf_document.write_to_filesystem(gltf_state, full_path)
	if error != OK:
		push_error("PaintingExporter: Failed to write GLB: " + str(error))
		export_root.queue_free()
		return ""

	export_root.queue_free()

	print("PaintingExporter: Saved GLB to ", full_path)
	return full_path

func _set_owner_recursive(node: Node, owner: Node) -> void:
	"""Recursively set owner for all children (required for GLTF export)"""
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
