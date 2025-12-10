extends RigidBody3D
class_name CarryablePainting

# Metadata for save system
var painting_id: String = ""
var texture_path: String = ""

func _ready():
	# Auto-register with save system if metadata exists
	if painting_id != "" and texture_path != "":
		WorldStateManager.register_painting(self, painting_id, texture_path)

func _exit_tree():
	# Auto-unregister when removed from scene
	WorldStateManager.unregister_painting(self)
