extends Control

@onready var debug_label = $Label

func _process(delta):
	var player = get_node_or_null("/root/World3D/Player")
	if player:
		debug_label.text = "FPS: %d\nPos: %s" % [Engine.get_frames_per_second(), str(player.global_position)]
