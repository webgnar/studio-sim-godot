extends Node

## Centralized sticker library loader
## Loads built-in stickers from res:// and custom stickers from user://custom_stickers/
## Both PaintingSystem2D and PaintingSystem3D reference this singleton

signal library_changed

var sticker_library: Array[PaintingLayerDefinition] = []

const CUSTOM_STICKERS_FOLDER = "user://custom_stickers/"
const BOUGHT_STICKERS_SUBFOLDER = "bought_stickers/"

func _ready():
	_ensure_custom_folder_exists()
	_load_all_stickers()
	if ShopManager:
		ShopManager.item_purchased.connect(_on_item_purchased)

func _on_item_purchased(item_id: String) -> void:
	if item_id == "customstickerbutton":
		reload()

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

	# ResourceLoader.list_directory() (unlike DirAccess) correctly enumerates
	# imported resources inside an exported PCK, not just in the editor's live
	# filesystem — so this one path works identically in both, and new sticker
	# PNGs are picked up automatically without a hardcoded filename list to
	# keep in sync (that list previously went stale and silently dropped
	# stickers 55+ from exported builds).
	for entry in ResourceLoader.list_directory(folder_path):
		if not entry.ends_with("/") and entry.ends_with(".png"):
			file_names.append(entry)

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
	"""Load user-added PNG stickers from user://custom_stickers/ and its bought_stickers subfolder."""
	var listed_ids: Array = WorldStateManager.get_listed_sticker_ids() if has_node("/root/WorldStateManager") else []
	var has_modder = has_node("/root/WorldStateManager") and "customstickerbutton" in WorldStateManager.get_purchased_items()

	if has_modder:
		_load_stickers_from_folder(CUSTOM_STICKERS_FOLDER, "custom_", listed_ids)
		# Marketplace purchases require the same unlock (you can't reach the
		# Marketplace tab without it) — gate the folder read too, so manually
		# dropping a PNG in here can't bypass the purchase. Also pass listed_ids
		# so a bought sticker currently re-listed for resale hides from the carousel.
		_load_stickers_from_folder(CUSTOM_STICKERS_FOLDER + BOUGHT_STICKERS_SUBFOLDER, "bought_", listed_ids)


func _load_stickers_from_folder(folder: String, id_prefix: String, exclude_base_names: Array) -> void:
	var dir = DirAccess.open(folder)
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

	var absolute_folder = ProjectSettings.globalize_path(folder)
	for fname in file_names:
		var base_name = fname.get_basename()
		if base_name in exclude_base_names:
			continue  # sticker is currently listed for sale — hide from carousel
		var absolute_path = absolute_folder.path_join(fname)
		var image = Image.new()
		var error = image.load(absolute_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			var sticker_id = id_prefix + base_name
			var definition = PaintingLayerDefinition.new(sticker_id, texture, 0)
			definition.unlocked = true
			sticker_library.append(definition)
		else:
			push_warning("Failed to load sticker: %s (error %d)" % [fname, error])

func _ensure_custom_folder_exists():
	"""Create the custom stickers folder and README if they don't exist"""
	if not DirAccess.dir_exists_absolute(CUSTOM_STICKERS_FOLDER):
		DirAccess.make_dir_recursive_absolute(CUSTOM_STICKERS_FOLDER)

	var readme_path = CUSTOM_STICKERS_FOLDER + "README.txt"
	if not FileAccess.file_exists(readme_path):
		var file = FileAccess.open(readme_path, FileAccess.WRITE)
		if file:
			file.store_string("=== Custom Stickers ===\n\nDrop PNG images into this folder to add custom stickers to your game.\nThey will appear at the end of the sticker carousel.\nRestart the game after adding new stickers.\n\nRecommended max size: 1080px on the longest side.\nLarger images will still work but may affect performance.\n\nNote: the 'bought_stickers' subfolder is managed automatically by the\ngame — it holds stickers you've purchased from the marketplace. Don't\nput your own stickers there; add them directly to this folder instead.\n")
			file.close()

	_ensure_bought_stickers_folder_exists()

func _ensure_bought_stickers_folder_exists() -> void:
	"""Create the bought_stickers subfolder if missing. Also migrates the
	pre-rename 'marketplace' folder so players updating from an older build
	don't lose stickers they already bought. Runs here (not just in
	StickerMarketplaceManager) because StickerLibrary's autoload _ready()
	runs first (project.godot autoload order) and reads this folder
	immediately — waiting for StickerMarketplaceManager to migrate it would
	be one session too late."""
	var absolute_folder = ProjectSettings.globalize_path(CUSTOM_STICKERS_FOLDER + BOUGHT_STICKERS_SUBFOLDER)
	if DirAccess.dir_exists_absolute(absolute_folder):
		return
	var old_absolute_folder = ProjectSettings.globalize_path(CUSTOM_STICKERS_FOLDER + "marketplace/")
	if DirAccess.dir_exists_absolute(old_absolute_folder):
		DirAccess.rename_absolute(old_absolute_folder, absolute_folder)
	else:
		DirAccess.make_dir_recursive_absolute(absolute_folder)

func reload():
	"""Reload all stickers (call after user adds new files)"""
	_load_all_stickers()

func get_custom_stickers_for_marketplace() -> Array[PaintingLayerDefinition]:
	"""Returns unlisted stickers available to sell: your own custom stickers
	(id prefix 'custom_') and stickers you've bought and can resell (id prefix 'bought_')."""
	var result: Array[PaintingLayerDefinition] = []
	for def in sticker_library:
		if def.id.begins_with("custom_") or def.id.begins_with("bought_"):
			result.append(def)
	return result

func get_sticker_file_path(sticker_id: String) -> String:
	"""Map a custom/bought sticker id back to its PNG file path on disk (for the marketplace sell flow)."""
	if sticker_id.begins_with("custom_"):
		return CUSTOM_STICKERS_FOLDER + sticker_id.substr(7) + ".png"
	if sticker_id.begins_with("bought_"):
		return CUSTOM_STICKERS_FOLDER + BOUGHT_STICKERS_SUBFOLDER + sticker_id.substr(7) + ".png"
	return ""

func get_sticker_display_name(sticker_id: String) -> String:
	"""Strip the internal id prefix ('custom_' or 'bought_') for display purposes."""
	if sticker_id.begins_with("custom_") or sticker_id.begins_with("bought_"):
		return sticker_id.substr(7)
	return sticker_id

func get_definition_by_id(sticker_id: String) -> PaintingLayerDefinition:
	"""Find a sticker definition by its ID"""
	for def in sticker_library:
		if def.id == sticker_id:
			return def
	return null
