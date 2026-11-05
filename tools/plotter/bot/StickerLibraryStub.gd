extends Node

## Stand-in for the game's StickerLibrary autoload, for tools that run in a
## bare project (no game autoloads, no imported assets). Loads the built-in
## stickers straight from their PNGs, in the same order as the real library
## (by number), so sticker indexes match the game.

var sticker_library: Array[PaintingLayerDefinition] = []


func _ready() -> void:
	var dir := OS.get_environment("STICKER_REPO").path_join("sprites/painting layers")
	var names: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			names.append(f)
	names.sort_custom(func(a, b): return a.get_basename().to_int() < b.get_basename().to_int())
	for f in names:
		var img := Image.load_from_file(dir.path_join(f))
		var def := PaintingLayerDefinition.new(f.get_basename(), ImageTexture.create_from_image(img), 0)
		def.unlocked = true
		sticker_library.append(def)
