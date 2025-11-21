extends Node3D  # or whatever your world root extends

@onready var painting_root_3d = $PaintingRoot
@onready var painting_root_2d = $PaintingRoot2d

func _ready():
	# Register both painting systems with the mode manager
	PaintingModeManager.register_3d_system(painting_root_3d, painting_root_3d)
	PaintingModeManager.register_2d_system(painting_root_2d.get_node("CanvasViewport/CanvasRoot"), painting_root_2d)
