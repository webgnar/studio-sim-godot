extends InteractionComponent
class_name StudioAssistantPurchaseButton

## Purchase button for Studio Assistant upgrade
## Extends InteractionComponent for proper player interaction

@export var purchase_sound: AudioStream  # Sound played on successful purchase

func _ready() -> void:
	print("StudioAssistantPurchaseButton: _ready() called on node: ", name)
	super._ready()  # Call parent InteractionComponent._ready() first
	_update_interaction_text()
	print("StudioAssistantPurchaseButton: Interaction text set to: ", interaction_text)

	# Connect to AutomationManager signal to update text when purchased
	if has_node("/root/AutomationManager"):
		AutomationManager.assistant_purchased.connect(_on_assistant_purchased)
		print("StudioAssistantPurchaseButton: Connected to AutomationManager signals")

func _on_interacted(_player_interaction_component: PlayerInteractionComponent) -> void:
	print("StudioAssistantPurchaseButton: _on_interacted() called!")

	# Check if already purchased
	if AutomationManager.is_assistant_active():
		print("StudioAssistantPurchaseButton: Already purchased")
		return

	# Check if can afford
	if not AutomationManager.can_purchase_assistant():
		var status = AutomationManager.get_assistant_status()
		var money = EconomyManager.get_money()

		print("StudioAssistantPurchaseButton: Cannot afford!")
		print("  Cost: $%d (you have $%d)" % [status.cost, money])

		# TODO: Show "not enough money" UI feedback
		return

	# Attempt purchase
	if AutomationManager.purchase_studio_assistant():
		print("StudioAssistantPurchaseButton: Purchase successful!")
		_update_interaction_text()

		# Play success sound
		if purchase_sound:
			_play_sound(purchase_sound)

		# Visual feedback - flash green
		_play_purchase_animation()
	else:
		print("StudioAssistantPurchaseButton: Purchase failed!")

func _on_assistant_purchased():
	"""Called when assistant is purchased (from anywhere)"""
	_update_interaction_text()

func _update_interaction_text():
	"""Update the interaction prompt based on purchase state"""
	if not has_node("/root/AutomationManager"):
		interaction_text = "Upgrade Unavailable"
		is_disabled = true
		return

	var status = AutomationManager.get_assistant_status()

	if status.active:
		interaction_text = "Studio Assistant Active"
		is_disabled = true
	elif AutomationManager.can_purchase_assistant():
		interaction_text = "Hire Studio Assistant ($%d)" % status.cost
		is_disabled = false
	else:
		var money = EconomyManager.get_money() if has_node("/root/EconomyManager") else 0

		if money < status.cost:
			interaction_text = "Hire Assistant ($%d) - Need $%d more" % [status.cost, status.cost - money]
		else:
			interaction_text = "Hire Assistant ($%d)" % status.cost

		is_disabled = false  # Allow looking at it to see requirements

func _play_purchase_animation():
	"""Play a visual flash animation on successful purchase"""
	# Find the button model to flash
	var button_model = get_node_or_null("button model")
	if not button_model:
		return

	# Create a material flash effect
	var tween = create_tween()
	tween.set_parallel(true)

	# Flash white then fade to normal
	# Note: This works best if the button has a MeshInstance3D child
	var mesh_instances = _find_all_mesh_instances(button_model)
	for mesh in mesh_instances:
		if mesh.get_surface_override_material_count() > 0:
			var material = mesh.get_surface_override_material(0)
			if material:
				# Flash emission for glow effect
				if material is StandardMaterial3D:
					var original_emission = material.emission_energy
					material.emission_enabled = true
					material.emission = Color.GREEN
					tween.tween_property(material, "emission_energy", 2.0, 0.2)
					tween.tween_property(material, "emission_energy", original_emission, 0.5).set_delay(0.2)

func _find_all_mesh_instances(node: Node) -> Array:
	"""Recursively find all MeshInstance3D nodes"""
	var meshes = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_find_all_mesh_instances(child))
	return meshes
