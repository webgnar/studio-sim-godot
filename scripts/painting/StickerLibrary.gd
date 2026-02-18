extends Node

## Centralized sticker library loader
## Loads built-in stickers from res:// and custom stickers from user://custom_stickers/
## Both PaintingSystem2D and PaintingSystem3D reference this singleton

signal library_changed

var sticker_library: Array[PaintingLayerDefinition] = []

const CUSTOM_STICKERS_FOLDER = "user://custom_stickers/"

func _ready():
	_ensure_custom_folder_exists()
	_load_all_stickers()

func _load_all_stickers():
	sticker_library.clear()
	_load_builtin_stickers()
	_load_custom_stickers()

	if DebugLogger and not OS.has_feature("editor"):
		DebugLogger.write_log("[StickerLibrary] Loaded %d total stickers (%d built-in)" % [sticker_library.size(), sticker_library.size()])

	library_changed.emit()

func _load_builtin_stickers():
	"""Load built-in sticker textures from res://sprites/painting layers/"""
	var folder_path = "res://sprites/painting layers/"
	var file_names: Array[String] = []

	if not OS.has_feature("editor"):
		file_names = [
			"1.png", "2.png", "3.png", "4.png", "5.png",
			"6.png", "7.png", "8.png", "9.png", "10.png",
			"11.png", "12.png", "13.png", "14.png", "15.png",
			"16.png", "17.png", "18.png", "19.png", "20.png",
			"21.png", "22.png", "23.png", "24.png", "25.png",
			"26.png", "27.png", "28.png", "29.png", "30.png",
			"31.png"
		]
	else:
		var dir = DirAccess.open(folder_path)
		if not dir:
			push_error("Failed to open sticker folder: %s" % folder_path)
			return

		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				file_names.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

		file_names.sort_custom(func(a, b):
			var num_a = a.get_basename().to_int()
			var num_b = b.get_basename().to_int()
			return num_a < num_b
		)

	for i in range(file_names.size()):
		var path = folder_path + file_names[i]
		var texture = load(path) as Texture2D
		if texture:
			var sticker_name = file_names[i].get_basename()
			var definition = PaintingLayerDefinition.new(sticker_name, texture, 0)
			definition.unlocked = true
			sticker_library.append(definition)
		else:
			push_error("Failed to load sticker texture: %s" % path)

func _load_custom_stickers():
	"""Load user-added PNG stickers from user://custom_stickers/"""
	var dir = DirAccess.open(CUSTOM_STICKERS_FOLDER)
	if not dir:
		return

	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	file_names.sort()

	var absolute_folder = ProjectSettings.globalize_path(CUSTOM_STICKERS_FOLDER)
	for fname in file_names:
		var absolute_path = absolute_folder.path_join(fname)
		var image = Image.new()
		var error = image.load(absolute_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			var sticker_name = "custom_" + fname.get_basename()
			var definition = PaintingLayerDefinition.new(sticker_name, texture, 0)
			definition.unlocked = true
			sticker_library.append(definition)
		else:
			push_warning("Failed to load custom sticker: %s (error %d)" % [fname, error])

func _ensure_custom_folder_exists():
	"""Create the custom stickers folder and README if they don't exist"""
	if not DirAccess.dir_exists_absolute(CUSTOM_STICKERS_FOLDER):
		DirAccess.make_dir_recursive_absolute(CUSTOM_STICKERS_FOLDER)

	var readme_path = CUSTOM_STICKERS_FOLDER + "README.txt"
	if not FileAccess.file_exists(readme_path):
		var file = FileAccess.open(readme_path, FileAccess.WRITE)
		if file:
			file.store_string("=== Custom Stickers ===\n\nDrop PNG images into this folder to add custom stickers to your game.\nThey will appear at the end of the sticker carousel.\nRestart the game after adding new stickers.\n\nRecommended max size: 1080px on the longest side.\nLarger images will still work but may affect performance.\n")
			file.close()

func reload():
	"""Reload all stickers (call after user adds new files)"""
	_load_all_stickers()

func get_definition_by_id(sticker_id: String) -> PaintingLayerDefinition:
	"""Find a sticker definition by its ID"""
	for def in sticker_library:
		if def.id == sticker_id:
			return def
	return null
