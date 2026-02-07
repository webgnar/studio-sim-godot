extends RigidBody3D
class_name CarryablePainting

# Metadata for save system
var painting_id: String = ""
var texture_path: String = ""
var painting_name: String = ""
var artist_statement: String = ""
var signature_texture_path: String = ""

# Runtime reference
var signature_system: PaintingSignatureSystem = null

func _ready():
	signature_system = get_node_or_null("PaintingSignatureSystem") as PaintingSignatureSystem

	# Auto-register with save system if metadata exists
	if painting_id != "" and texture_path != "":
		WorldStateManager.register_painting(self, painting_id, texture_path)

func _exit_tree():
	# Auto-unregister when removed from scene
	WorldStateManager.unregister_painting(self)
