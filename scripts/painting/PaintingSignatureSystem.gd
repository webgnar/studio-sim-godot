extends Node3D
class_name PaintingSignatureSystem

## Component for drawing signatures on the back of a CarryablePainting.
## Manages a 512x512 Image painted via raycast UV conversion.

const TEXTURE_SIZE: int = 512
const BRUSH_RADIUS: int = 4
const BRUSH_COLOR: Color = Color(0.1, 0.1, 0.1, 1.0)
const CANVAS_BG_COLOR: Color = Color(0.95, 0.93, 0.88, 1.0)
const PLANE_SIZE: float = 3.0

var signature_image: Image
var signature_texture: ImageTexture
var back_face_mesh: MeshInstance3D
var has_any_strokes: bool = false
var last_pixel_pos: Vector2i = Vector2i(-1, -1)

func _ready():
	back_face_mesh = get_parent().get_node_or_null("BackFaceMesh")
	if not back_face_mesh:
		push_warning("PaintingSignatureSystem: No BackFaceMesh sibling found")
		return

	_create_blank_canvas()

func _create_blank_canvas():
	signature_image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	signature_image.fill(Color(0, 0, 0, 0))
	signature_texture = ImageTexture.create_from_image(signature_image)

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CANVAS_BG_COLOR
	material.albedo_texture = signature_texture
	back_face_mesh.set_surface_override_material(0, material)

func initialize_from_image(img: Image):
	"""Restore a previously saved signature image."""
	if not back_face_mesh:
		return

	signature_image = img
	has_any_strokes = true
	signature_texture = ImageTexture.create_from_image(signature_image)

	var material = back_face_mesh.get_surface_override_material(0) as StandardMaterial3D
	if material:
		material.albedo_texture = signature_texture
	else:
		_create_blank_canvas()
		material = back_face_mesh.get_surface_override_material(0) as StandardMaterial3D
		material.albedo_texture = signature_texture

func get_signature_image() -> Image:
	return signature_image

func has_signature() -> bool:
	return has_any_strokes

func draw_at_world_position(world_pos: Vector3):
	"""Convert world hit position to pixel coords and draw."""
	if not back_face_mesh or not signature_image:
		return

	var local_pos = back_face_mesh.to_local(world_pos)
	var uv = Vector2(
		(local_pos.x / PLANE_SIZE) + 0.5,
		(local_pos.z / PLANE_SIZE) + 0.5
	)
	var pixel = Vector2i(
		clampi(int(uv.x * TEXTURE_SIZE), 0, TEXTURE_SIZE - 1),
		clampi(int(uv.y * TEXTURE_SIZE), 0, TEXTURE_SIZE - 1)
	)

	# Interpolate between last and current position to avoid gaps
	if last_pixel_pos != Vector2i(-1, -1):
		_draw_line(last_pixel_pos, pixel)
	else:
		_draw_circle(pixel, BRUSH_RADIUS)

	last_pixel_pos = pixel
	has_any_strokes = true
	signature_texture.update(signature_image)

func finish_stroke():
	"""Called when the player releases the draw button."""
	last_pixel_pos = Vector2i(-1, -1)

func _draw_line(from: Vector2i, to: Vector2i):
	"""Draw a line of circles from one pixel to another (Bresenham-style stepping)."""
	var diff = to - from
	var steps = maxi(absi(diff.x), absi(diff.y))
	if steps == 0:
		_draw_circle(to, BRUSH_RADIUS)
		return

	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var px = Vector2i(
			int(lerpf(from.x, to.x, t)),
			int(lerpf(from.y, to.y, t))
		)
		_draw_circle(px, BRUSH_RADIUS)

func _draw_circle(center: Vector2i, radius: int):
	"""Fill a circle of pixels at the given center."""
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var px = center.x + dx
				var py = center.y + dy
				if px >= 0 and px < TEXTURE_SIZE and py >= 0 and py < TEXTURE_SIZE:
					signature_image.set_pixel(px, py, BRUSH_COLOR)
