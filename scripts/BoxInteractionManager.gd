extends Node3D
# Example script showing how to use the ClickableBox system
# Attach this to your World node or any parent node

func _ready() -> void:
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Find the box in the scene and make it clickable
	setup_box_interaction()

func setup_box_interaction() -> void:
	# Find the box node (adjust the path based on your scene structure)
	var box_node = get_node_or_null("bottom")  # This matches your scene structure
	
	if box_node:
		# Add the ClickableBox script to the box
		if not box_node.has_method("_on_clicked"):  # Check if script not already added
			var clickable_script = load("res://scripts/ClickableBox.gd")
			box_node.set_script(clickable_script)
			
			# Connect to the box's signals to handle interactions
			box_node.clicked.connect(_on_box_clicked)
			box_node.hover_started.connect(_on_box_hover_started) 
			box_node.hover_ended.connect(_on_box_hover_ended)
			
			print("Made box clickable: " + box_node.name)
	else:
		print("Box node not found! Check the node path.")

# Handle what happens when the box is clicked
func _on_box_clicked() -> void:
	print("Box was clicked! Doing something awesome...")
	
	# Example interactions you can do:
	
	# 1. Show a message or UI
	show_interaction_message("You opened the box!")
	
	# 2. Spawn an item
	# spawn_item_from_box()
	
	# 3. Play a sound effect
	# AudioManager.play_sound("box_open")
	
	# 4. Change game state
	# GameManager.box_opened = true

# Handle hover effects
func _on_box_hover_started() -> void:
	# Show interaction prompt
	show_interaction_prompt("Click to open box")

func _on_box_hover_ended() -> void:
	# Hide interaction prompt
	hide_interaction_prompt()

# Example helper functions
func show_interaction_message(message: String) -> void:
	print("MESSAGE: " + message)
	# You can create a UI label here to show messages
	# Example:
	# var ui_label = get_node("UI/InteractionLabel")
	# if ui_label:
	#     ui_label.text = message
	#     ui_label.show()

func show_interaction_prompt(prompt: String) -> void:
	print("PROMPT: " + prompt)
	# Show crosshair prompt or UI element
	# Example:
	# var crosshair = get_node("UI/Crosshair/InteractionText")
	# if crosshair:
	#     crosshair.text = prompt
	#     crosshair.show()

func hide_interaction_prompt() -> void:
	print("Hiding interaction prompt")
	# Hide the interaction prompt
	# Example:
	# var crosshair = get_node("UI/Crosshair/InteractionText")
	# if crosshair:
	#     crosshair.hide()

# Example function to spawn items
func spawn_item_from_box() -> void:
	var box_node = get_node("bottom")
	if box_node:
		# Create a simple item (could be a pickup, particle effect, etc.)
		# var item = preload("res://scenes/ItemPickup.tscn")  # Replace with your item scene
		# if item:
		#	var item_instance = item.instantiate()
		#	get_parent().add_child(item_instance)
		#	item_instance.global_position = box_node.global_position + Vector3(0, 2, 0)