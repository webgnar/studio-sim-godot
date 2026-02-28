extends Node

## Shop Manager - Autoload that owns the shop item catalog, purchase logic,
## and prop reveal/hide system for shop-gated studio objects.
## Props are tagged in world.tscn with group "shop_prop" and meta "shop_item_id".

signal item_purchased(item_id: String)

# Item catalog: Array of Dictionaries with keys: id, display_name, description, price
var _catalog: Array = []


func _ready() -> void:
	_build_catalog()


# ============================================================================
# Public API
# ============================================================================

func get_catalog() -> Array:
	"""Returns all shop items in order."""
	return _catalog


func is_purchased(item_id: String) -> bool:
	"""Check if an item has been purchased this session."""
	return WorldStateManager.get_purchased_items().has(item_id)


func purchase(item_id: String) -> bool:
	"""
	Attempt to purchase an item. Deducts money, marks purchased,
	reveals the prop in the world, and saves.
	Returns true if the purchase succeeded.
	"""
	if is_purchased(item_id):
		return false

	var item = _get_item(item_id)
	if item.is_empty():
		push_warning("ShopManager: Unknown item id: " + item_id)
		return false

	if not EconomyManager.can_afford(item["price"]):
		return false

	# Deduct money
	EconomyManager.spend_money(item["price"], "shop: " + item["display_name"])

	# Mark as purchased in WorldStateManager (persisted to disk on save)
	WorldStateManager.add_purchased_item(item_id)

	# Reveal the prop(s) in the world immediately
	_reveal_item_props(item_id)

	# Save so purchased state isn't lost on crash
	WorldStateManager.save_world_state()

	item_purchased.emit(item_id)
	print("ShopManager: Purchased '%s' for $%d" % [item["display_name"], item["price"]])
	return true


func reveal_purchased_items() -> void:
	"""
	Called by WorldStateManager after load_world_state to reveal all props
	the player has already purchased. Props were hidden by WorldSetup before load.
	"""
	for item_id in WorldStateManager.get_purchased_items():
		_reveal_item_props(item_id)


# ============================================================================
# Internal helpers
# ============================================================================

func _reveal_item_props(item_id: String) -> void:
	"""Find and reveal all scene nodes tagged with this item_id."""
	var found_any := false
	for node in get_tree().get_nodes_in_group("shop_prop"):
		if node.get_meta("shop_item_id", "") == item_id:
			_reveal_prop(node)
			found_any = true
	if not found_any:
		push_warning("ShopManager: No prop nodes found for item_id: " + item_id)


func _reveal_prop(node: Node) -> void:
	"""Make a prop visible and active. Applies upward impulse to avoid player overlap."""
	node.visible = true
	# Re-enable all descendant collision shapes that were disabled before purchase
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		shape.disabled = false
	if node is RigidBody3D:
		node.freeze = false
		# Apply a small upward impulse on the next physics frame so the engine
		# can resolve any overlap between the newly-unfrozen object and the player.
		get_tree().process_frame.connect(
			func():
				if is_instance_valid(node):
					node.apply_central_impulse(Vector3.UP * 1.5),
			CONNECT_ONE_SHOT
		)


func _get_item(item_id: String) -> Dictionary:
	"""Return the catalog entry for a given item_id, or empty dict if not found."""
	for item in _catalog:
		if item["id"] == item_id:
			return item
	return {}


func _build_catalog() -> void:
	"""Define all purchasable shop items."""
	_catalog = [
		{
			"id": "nail_gun",
			"display_name": "Nail Gun",
			"description": "Hang your paintings on the wall. An essential tool for any serious artist.",
			"price": 300,
		},
		{
			"id": "trash_can",
			"display_name": "Trash Can",
			"description": "A studio staple. Every artist needs somewhere to put their mistakes.",
			"price": 75,
		},
		{
			"id": "fan",
			"display_name": "Fan",
			"description": "Keep the studio cool while you work. Comes with a power cord.",
			"price": 150,
		},
		{
			"id": "styrofoam_cube",
			"display_name": "Styrofoam Cube",
			"description": "Great for abstract compositions. Surprisingly useful as a pedestal.",
			"price": 50,
		},
		{
			"id": "cardboard_box",
			"display_name": "Cardboard Box",
			"description": "A mysterious cardboard box. Something might be inside.",
			"price": 100,
		},
		{
			"id": "water_filter",
			"display_name": "Berkey Water Filter",
			"description": "Clean water for a clear mind.",
			"price": 200,
		},
		{
			"id": "phone",
			"display_name": "Phone",
			"description": "A smartphone. Check your messages.",
			"price": 150,
		},
		{
			"id": "mirror",
			"display_name": "Mirror",
			"description": "For checking yourself out between sessions.",
			"price": 125,
		},
		{
			"id": "customstickerbutton",
			"display_name": "Custom Sticker Printer",
			"description": "Print your own custom stickers to put on paintings.",
			"price": 250,
		},
	]
