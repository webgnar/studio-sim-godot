@tool
extends EditorScript

## Tool script to regenerate the missions manifest
## Run this from Script > Run to update the manifest after adding/removing missions

const MISSIONS_PATH = "res://resources/missions/"
const MANIFEST_PATH = "res://resources/missions/missions_manifest.json"

func _run():
	generate_manifest()
	print("✓ Mission manifest regenerated successfully!")

static func generate_manifest() -> bool:
	"""Scan missions directory and create manifest file"""
	var missions: Array[String] = []

	var dir = DirAccess.open(MISSIONS_PATH)
	if not dir:
		push_error("Failed to open missions folder: %s" % MISSIONS_PATH)
		return false

	# Get all .tres files
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			missions.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort alphabetically
	missions.sort()

	# Save manifest
	var manifest = {
		"missions": missions,
		"generated_at": Time.get_datetime_string_from_system()
	}

	var file = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to create manifest file: %s" % MANIFEST_PATH)
		return false

	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()

	print("Generated manifest with %d missions" % missions.size())
	return true
