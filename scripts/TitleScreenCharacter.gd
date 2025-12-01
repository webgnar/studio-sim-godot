extends Node3D

## Simple controller for character model in title screen
## Automatically plays idle animation on load

@export var animation_name: String = "idle"

func _ready():
	print("TitleScreenCharacter: Starting animation search...")

	# Find AnimationPlayer in children
	var animation_player = _find_animation_player(self)

	if animation_player:
		print("TitleScreenCharacter: Found AnimationPlayer at: ", animation_player.get_path())
		var available_anims = animation_player.get_animation_list()
		print("TitleScreenCharacter: Available animations: ", available_anims)

		# Play the idle animation
		if animation_player.has_animation(animation_name):
			animation_player.play(animation_name)
			print("TitleScreenCharacter: Playing animation '%s'" % animation_name)
		else:
			push_warning("TitleScreenCharacter: Animation '%s' not found!" % animation_name)
			push_warning("TitleScreenCharacter: Available animations are: %s" % str(available_anims))
	else:
		push_warning("TitleScreenCharacter: No AnimationPlayer found in node tree!")
		_debug_print_tree(self, 0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively search for AnimationPlayer in node tree"""
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result

	return null

func _debug_print_tree(node: Node, depth: int):
	"""Print the node tree structure for debugging"""
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + node.name + " (" + node.get_class() + ")")

	for child in node.get_children():
		_debug_print_tree(child, depth + 1)
