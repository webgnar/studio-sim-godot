extends Node

## Custom skin library loader
## Loads user-dropped PNG skin textures from user://custom_skins/ at startup
## Custom skins are appended to the mirror's built-in skin list at runtime

signal library_changed

const CUSTOM_SKINS_FOLDER = "user://custom_skins/"

const FALLBACK_NORMAL_PATH = "res://sprites/normals/human figure_0_normal.png"
const AO_PATH = "res://sprites/normals/human figure_0_ambient.png"

var custom_skin_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_ensure_custom_folder_exists()
	_load_custom_skins()
	library_changed.emit()

func _load_custom_skins() -> void:
	custom_skin_materials.clear()

	var dir = DirAccess.open(CUSTOM_SKINS_FOLDER)
	if not dir:
		return

	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var lower = file_name.to_lower()
		# Only collect albedo PNGs — skip normal maps (_n.png) and the template
		if not dir.current_is_dir() and lower.ends_with(".png") and not lower.ends_with("_n.png") and lower != "uv_template.png":
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	file_names.sort()

	var absolute_folder = ProjectSettings.globalize_path(CUSTOM_SKINS_FOLDER)
	var ao_texture = load(AO_PATH) as Texture2D
	var fallback_normal = load(FALLBACK_NORMAL_PATH) as Texture2D

	for fname in file_names:
		var absolute_path = absolute_folder.path_join(fname)
		var albedo_image = Image.new()
		var err = albedo_image.load(absolute_path)
		if err != OK:
			push_warning("[SkinLibrary] Failed to load skin: %s (error %d)" % [fname, err])
			continue

		var albedo_tex = ImageTexture.create_from_image(albedo_image)

		# Check for optional paired normal map (e.g. myskin.png → myskin_n.png)
		var normal_tex: Texture2D = fallback_normal
		var normal_name = fname.get_basename() + "_n.png"
		var normal_abs = absolute_folder.path_join(normal_name)
		if FileAccess.file_exists(normal_abs):
			var normal_image = Image.new()
			if normal_image.load(normal_abs) == OK:
				normal_tex = ImageTexture.create_from_image(normal_image)
			else:
				push_warning("[SkinLibrary] Found normal map %s but failed to load it, using fallback." % normal_name)

		var mat = StandardMaterial3D.new()
		mat.albedo_texture = albedo_tex
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.ao_enabled = true
		mat.ao_texture = ao_texture

		custom_skin_materials.append(mat)

	if not OS.has_feature("editor"):
		print("[SkinLibrary] Loaded %d custom skin(s)" % custom_skin_materials.size())

const UV_TEMPLATE_SRC = "res://models/player/humanrig_Image_0.png"

func _ensure_custom_folder_exists() -> void:
	if not DirAccess.dir_exists_absolute(CUSTOM_SKINS_FOLDER):
		DirAccess.make_dir_recursive_absolute(CUSTOM_SKINS_FOLDER)

	var readme_path = CUSTOM_SKINS_FOLDER + "README.txt"
	if not FileAccess.file_exists(readme_path):
		var file = FileAccess.open(readme_path, FileAccess.WRITE)
		if file:
			file.store_string("""=== Custom Player Skins ===

Drop PNG files into this folder to add custom player skins.
They will appear after the built-in skins when cycling at the mirror.
Restart the game after adding new skins.

NAMING CONVENTION:
  myskin.png      -> Albedo / color UV texture (required -- creates a skin entry)
  myskin_n.png    -> Normal map for myskin (optional -- must share the same basename + _n)

Files ending with _n.png are treated as normal maps only, not as separate skin entries.

UV LAYOUT:
UV_TEMPLATE.png in this folder shows the UV layout of the player model.
Paint over it at 512x256 pixels to create your skin.
""")
			file.close()

	# Copy UV template from game resources if not already present
	var template_dest = CUSTOM_SKINS_FOLDER + "UV_TEMPLATE.png"
	if not FileAccess.file_exists(template_dest):
		var src_file = FileAccess.open(UV_TEMPLATE_SRC, FileAccess.READ)
		if src_file:
			var bytes = src_file.get_buffer(src_file.get_length())
			src_file.close()
			var dst_file = FileAccess.open(template_dest, FileAccess.WRITE)
			if dst_file:
				dst_file.store_buffer(bytes)
				dst_file.close()
		else:
			push_warning("[SkinLibrary] Could not open UV template source: %s" % UV_TEMPLATE_SRC)

func reload() -> void:
	_load_custom_skins()
	library_changed.emit()
