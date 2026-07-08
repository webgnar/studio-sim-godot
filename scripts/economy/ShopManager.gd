extends Node

## Shop Manager - Autoload that owns the shop item catalog, purchase logic,
## and prop reveal/hide system for shop-gated studio objects.
## Props are tagged in world.tscn with group "shop_prop" and meta "shop_item_id".

signal item_purchased(item_id: String)

# Item catalog: Array of Dictionaries with keys: id, display_name, description, price
var _catalog: Array = []

const _DEFAULT_SPAWN_RADIUS := 1.2
const _SPAWN_CHECK_RADII := {
	"mirror": 2.0,           # large prop + palette stack child, against a wall
	"customstickerbutton": 1.5,  # raised button with cylinder static body
}

const _GALLERY_VISITOR_SCENE = preload("res://scenes/GalleryVisitor.tscn")
# Approximate center of the gallery room floor (matches the pre-placed visitor position)
const _GALLERY_VISITOR_SPAWN_CENTER = Vector3(1.75, -14.57, 24.97)

# Visitor roster — each entry is assigned in order (index % size wraps around).
# Add new entries here as new skins are created. Empty skin_path = skinless (random personality).
const VISITOR_ROSTER: Array = [
	{"skin_path": "res://materials/NPCs/blackguy_redshirt.tres",    "display_name": "Keenan"},
	{"skin_path": "res://materials/NPCs/tanguy_greenshirt.tres",    "display_name": "Tong Pan"},
	{"skin_path": "res://materials/NPCs/blondeguy_whiteshirt.tres", "display_name": "Bruno"},
	{"skin_path": "res://materials/NPCs/jollyrich.tres",            "display_name": "Reginald"},
	{"skin_path": "res://materials/NPCs/ronald.tres",               "display_name": "Canio"},
	{"skin_path": "res://materials/NPCs/kylie.tres",                "display_name": "Kylie"},
	{"skin_path": "res://materials/NPCs/tinfoilguy.tres",          "display_name": "Karl"},
	{"skin_path": "res://materials/NPCs/maninblack.tres",          "display_name": "Agent Smith"},
	{"skin_path": "res://materials/NPCs/gw.tres",                  "display_name": "George Washington"},
	{"skin_path": "res://materials/garyskin.tres",                  "display_name": "Gary"},
	{"skin_path": "res://materials/humanskin.tres",                 "display_name": "Zack"},
	{"skin_path": "res://materials/skeletonskin.tres",              "display_name": "Mort"},
	{"skin_path": "res://materials/NPCs/kdog.tres",                "display_name": "K-Dog"},
	{"skin_path": "res://materials/NPCs/ian.tres",                 "display_name": "Ian"},
]

var _spawned_visitor_count: int = 0


func _ready() -> void:
	_build_catalog()


# ============================================================================
# Public API
# ============================================================================

func get_catalog() -> Array:
	"""Returns all shop items in order, including always_present entries."""
	return _catalog


func get_purchaseable_catalog() -> Array:
	"""Returns only items that can be purchased (excludes always_present world objects)."""
	return _catalog.filter(func(item): return not item.get("always_present", false))


func is_purchased(item_id: String) -> bool:
	"""Check if an item has been purchased this session."""
	return WorldStateManager.get_purchased_items().has(item_id)


func is_always_present(item_id: String) -> bool:
	"""Returns true if this item is permanently in the world and not purchase-gated."""
	var item = _get_item(item_id)
	return item.get("always_present", false)


func is_locked(_item_id: String) -> bool:
	return false


func purchase(item_id: String) -> bool:
	"""
	Attempt to purchase an item. Deducts money, marks purchased,
	reveals the prop in the world, and saves.
	Returns true if the purchase succeeded.
	"""
	var item = _get_item(item_id)
	if item.is_empty():
		push_warning("ShopManager: Unknown item id: " + item_id)
		return false

	var is_repeatable: bool = item.get("repeatable", false)

	# Non-repeatable items can only be bought once
	if not is_repeatable and is_purchased(item_id):
		return false

	if not is_repeatable and is_locked(item_id):
		return false

	if not EconomyManager.can_afford(item["price"]):
		return false

	# Only check for player blocking on one-time prop items
	if not is_repeatable and not item.get("no_prop", false) and is_player_blocking_spawn(item_id):
		return false

	# Deduct money
	EconomyManager.spend_money(item["price"], "shop: " + item["display_name"])

	if is_repeatable:
		_handle_repeatable_purchase(item_id)
	else:
		# Mark as purchased in WorldStateManager (persisted to disk on save)
		WorldStateManager.add_purchased_item(item_id)
		# Reveal the prop(s) in the world immediately
		if not item.get("no_prop", false):
			_reveal_item_props(item_id)

	item_purchased.emit(item_id)
	print("ShopManager: Purchased '%s' for $%d" % [item["display_name"], item["price"]])

	# Achievement: Consciousness Creates Reality
	if item_id == "customstickerbutton":
		if SteamManager:
			SteamManager.unlock_achievement("ACH_CONSCIOUSNESS_CREATES_REALITY")

	# Achievement: RF Receiver
	if item_id == "rf_receiver":
		if SteamManager:
			SteamManager.unlock_achievement("ACH_RF_RECEIVER")

	# Achievement: Brave New World (all three free energy devices)
	var free_energy_ids = ["geet", "wfc", "seg"]
	if item_id in free_energy_ids:
		var purchased = WorldStateManager.get_purchased_items()
		if free_energy_ids.all(func(id): return id in purchased):
			if SteamManager:
				SteamManager.unlock_achievement("ACH_BRAVE_NEW_WORLD")
	return true


func reveal_purchased_items() -> void:
	"""
	Called by WorldStateManager after load_world_state to reveal all props
	the player has already purchased. Props were hidden by WorldSetup before load.
	"""
	for item_id in WorldStateManager.get_purchased_items():
		var item = _get_item(item_id)
		if item.get("no_prop", false):
			continue
		_reveal_item_props(item_id)


func spawn_gallery_visitor() -> void:
	"""Instantiate a GalleryVisitor NPC in the gallery room. Called on purchase and on save load."""
	var visitor = _GALLERY_VISITOR_SCENE.instantiate()

	# Assign skin + name from roster, cycling if more visitors than roster entries
	var config: Dictionary = VISITOR_ROSTER[_spawned_visitor_count % VISITOR_ROSTER.size()]
	_spawned_visitor_count += 1
	if config.get("skin_path", "") != "":
		var mat: StandardMaterial3D = load(config["skin_path"])
		if mat:
			visitor.skin_material = mat
	if config.get("display_name", "") != "":
		visitor.visitor_display_name = config["display_name"]

	# Parent to the same node as the pre-placed visitor so it lives in the right scene context
	var world_root: Node = null
	var existing = get_tree().get_nodes_in_group("gallery_visitors")
	if not existing.is_empty():
		world_root = existing[0].get_parent()
	else:
		world_root = get_tree().root
	world_root.add_child(visitor)
	var scatter = Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	visitor.global_position = _GALLERY_VISITOR_SPAWN_CENTER + scatter


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
	node.process_mode = Node.PROCESS_MODE_INHERIT
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


func is_player_blocking_spawn(item_id: String) -> bool:
	"""Returns true if the player is standing inside the spawn zone of the given item."""
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return false
	var player_pos: Vector3 = player.global_position
	for node in get_tree().get_nodes_in_group("shop_prop"):
		if node.get_meta("shop_item_id", "") == item_id:
			var radius: float = _SPAWN_CHECK_RADII.get(item_id, _DEFAULT_SPAWN_RADIUS)
			if player_pos.distance_to(node.global_position) < radius:
				return true
	return false


func _handle_repeatable_purchase(item_id: String) -> void:
	"""Handle side effects for items that can be purchased multiple times."""
	match item_id:
		"gallery_visitor":
			WorldStateManager.increment_gallery_visitor_count()
			spawn_gallery_visitor()


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
			"title": "Gnarwalkie Nail Gun",
			"description": "Hang your paintings on the wall. An essential tool for viewing your artwork in a gallery setting.",
			"price": 300,
		},
		{
			"id": "trash_can",
			"display_name": "Trash Can",
			"title": "Trash Can",
			"description": "A studio staple. Every artist needs somewhere to put their mistakes.",
			"price": 75,
		},
		{
			"id": "fan",
			"display_name": "Fan",
			"title": "Fan",
			"description": "Keeps the studio cool while you work. Comes with a power cord.",
			"price": 150,
		},
		{
			"id": "styrofoam_cube",
			"display_name": "Styrofoam Cube",
			"title": "Styrofoam Cube",
			"description": "Great for breaking up physical space inside the studio. Surprisingly useful as a pedestal.",
			"price": 150,
		},
		{
			"id": "cardboard_box",
			"display_name": "Cardboard Box",
			"title": "Cardboard Box",
			"description": "A mysterious cardboard box. Something useful might be inside.",
			"price": 100,
		},
		{
			"id": "water_filter",
			"display_name": "Water Filter",
			"title": "Proprietary Water Filter",
			"description": (
				"Clean water for a clear mind. A sleek plastic tower of liquid clarity."
				+ " Pour questionable water into the top, wait patiently, and watch as"
				+ " invisible microscopic villains are dramatically evicted before reaching"
				+ " your glass.\n\n"
				+ "Requires no electricity, no plumbing, and no trust in municipal optimism."
				+ " Just gravity, confidence, and an unwavering belief that two metal"
				+ " cylinders stacked together can solve everything.\n\n"
				+ "Perfect for off-grid cabins, emergency preparedness, or anyone who enjoys"
				+ " their water filtered with a side of apocalypse readiness."
			),
			"price": 200,
		},
		{
			"id": "phone",
			"display_name": "Phone",
			"title": "Phone",
			"description": "A smartphone with a mysterious website loaded onto its home screen.",
			"price": 150,
		},
		{
			"id": "mirror",
			"display_name": "Mirror",
			"title": "Mirror",
			"description": "For checking yourself out between sessions. Perfect for viewing your work through a different lens.",
			"price": 220,
		},
		{
			"id": "skateboard",
			"display_name": "Skateboard",
			"title": "Skateboard",
			"description": "A brand-new board leaning against the wall. Old habits.",
			"price": 175,
		},
		{
			"id": "monstera",
			"display_name": "Monstera Plant",
			"title": "Monstera Deliciosa",
			"description": "Big leafy vibes. Every studio needs one.",
			"price": 100,
		},
		{
			"id": "fern_plant",
			"display_name": "Fern Plant",
			"title": "Polypodiopsida",
			"description": "Delicate, unfurling fiddleheads. A little prehistoric energy for the studio.",
			"price": 125,
		},
		{
			"id": "madpalm",
			"display_name": "Madagascar Palm",
			"title": "Pachypodium lamerei",
			"description": "Spiky, drought-tolerant, and technically a succulent. The Madagascar Palm doesn't care what you call it.",
			"price": 175,
		},
		{
			"id": "psywheel",
			"display_name": "Psywheel",
			"title": "Psywheel",
			"description": "A homemade meditation device crafted out of an eraser, a toothpick, and a folded piece of paper. Used to practice telekinesis. When it's spinning, you know you are onto something.",
			"price": 150,
		},
		{
			"id": "cyclone",
			"display_name": "Cyclone",
			"title": "Cyclone",
			"description": "A spinning circle of false hope and questionable reflexes. Perfect for testing hand–eye coordination, patience, and your ability to blame the machine instead of yourself.",
			"price": 300,
		},
		{
			"id": "seg",
			"display_name": "SEG",
			"title": "Searl Effect Generator",
			"description": (
				"A legendary machine born somewhere between experimental engineering and"
				+ " late-night scientific rebellion. Inspired by the controversial designs"
				+ " attributed to inventor John Searl, this rotating assembly of magnetized"
				+ " rollers and concentric rings is said to unlock phenomena that mainstream"
				+ " physics politely refuses to acknowledge.\n\n"
				+ "Supporters claim that once the rollers reach a precise rotational harmony,"
				+ " the generator enters the Searl Effect, a self-sustaining electromagnetic"
				+ " state where motion feeds energy back into itself. The result, allegedly,"
				+ " is power generation without fuel, friction, or financial regret.\n\n"
				+ "Rumored capabilities include:\n"
				+ "- Free electrical energy produced directly from ambient fields.\n"
				+ "- Self-acceleration after startup, requiring little or no external power.\n"
				+ "- Gravity reduction effects, ranging from slight weight loss to full"
				+ " levitation of the device itself.\n"
				+ "- Silent propulsion, theoretically enabling hovering vehicles or"
				+ " anti-gravity transport.\n"
				+ "- Ionization of surrounding air, creating glowing corona effects and"
				+ " dramatic sci-fi ambiance.\n"
				+ "- Localized cooling, as nearby temperatures supposedly drop during"
				+ " operation.\n"
				+ "- Electromagnetic shielding, because ordinary reality struggles to keep"
				+ " up.\n"
				+ "- Reports of improved electronics efficiency nearby (and occasionally"
				+ " improved confidence).\n\n"
				+ "Whether a revolutionary breakthrough or an extremely sophisticated"
				+ " conversation piece, the Searl Effect Generator undeniably transforms any"
				+ " space into a cutting-edge research facility, or at least a place where"
				+ " bold ideas spin very, very fast."
			),
			"price": 420,
		},
		{
			"id": "geet",
			"display_name": "GEET Engine",
			"title": "GEET Plasma Reactor",
			"description": (
				"The GEET (Global Environmental Energy Technology) is, on its surface, a"
				+ " deceptively simple device: a fuel pre-treater consisting of ferromagnetic"
				+ " pipes, a calibrated steel rod, and a sealed vacuum chamber no bigger than"
				+ " a thermos. But what happens inside defies easy categorization. The"
				+ " engine's own exhaust heat is routed back through the incoming fuel vapor"
				+ " in a counterflow arrangement, hot gases moving one direction, raw fuel"
				+ " traveling the other, spiraling around a magnetized rod of precise,"
				+ " engine-specific length. Inside this vacuum-maintained chamber, something"
				+ " anomalous occurs. The heavier hydrocarbon molecules crack apart. The fuel"
				+ " transitions into a low-temperature plasma state, a thing that should,"
				+ " according to standard physics, require the heat of an electrical arc to"
				+ " achieve, yet somehow manifests here through thermodynamic resonance alone."
				+ " Pantone's own documentation described over seventy simultaneous phenomena"
				+ " occurring within the reactor during operation. Scientists who witnessed it"
				+ " firsthand said they would not have believed it had they not seen it"
				+ " themselves.\n\n"
				+ "What came out the other end was cleaner than the air going in. Independent"
				+ " tests at a California smog certification station recorded zero detectable"
				+ " pollution from a gasoline engine running on crude oil. The reactor was"
				+ " documented running engines on diesel, vegetable oil, contaminated waste"
				+ " fluids, Mountain Dew, iced tea, and reportedly, at one demonstration in"
				+ " Arizona, on a mixture that was eighty percent water. Engineers watching"
				+ " the dyno tests described engines revving to twice their rated RPM and"
				+ " idling down to fractions of normal speed with no mechanical explanation."
				+ " The plasma field generated by the device was measured as a pulsating"
				+ " direct current (self-generated, radial, and longitudinal), influenced by"
				+ " the Earth's own gravitational field and the direction of mass movement"
				+ " within the chamber. Pantone maintained that no external electrical"
				+ " enhancement could improve the effect; the energy had to arise naturally"
				+ " from within the system or it would not arise at all.\n\n"
				+ "When Paul Pantone refused to sell his patents to the interests circling"
				+ " him (the oil companies, the quiet men in suits who kept showing up at"
				+ " demonstrations and then disappearing), the machinery turned on him."
				+ " In 2005, the state of Utah charged him with two counts of securities"
				+ " fraud. The case was prosecuted hard, and by the summer of that year"
				+ " Pantone was not in a prison cell but in a state mental hospital in"
				+ " Provo — a distinction that carries its own kind of weight. He remained"
				+ " institutionalized for nearly four years. His son David, convinced his"
				+ " father had full mental faculty, began releasing recorded audio interviews"
				+ " from inside the facility, building a public record. A sympathetic"
				+ " politician eventually intervened. Pantone was released in May 2009."
				+ " Notably, two researchers at Los Alamos National Laboratory later"
				+ " published work on plasma-assisted combustion that closely mirrored"
				+ " GEET's core principles, and Pantone claimed both men had attended his"
				+ " private training courses.\n\n"
				+ "He died in December 2015, after a long illness, largely unknown outside"
				+ " fringe engineering circles and the European universities and hobbyist"
				+ " groups who had taken his technology further than his own country ever"
				+ " allowed. His US patent, number 5,794,601, filed in 1993, sits in the"
				+ " public record, quiet and unremarkable, describing a fuel pre-treater"
				+ " that makes no performance claims. The technology has been quietly"
				+ " reproduced in Brazil, Israel, France, and elsewhere. The original red"
				+ " Briggs & Stratton engine he dragged to demonstrations for thirty years,"
				+ " wrapped in its confusing tangle of piping, is gone. What remains are"
				+ " the schematics, the testimonies of engineers who walked away shaken,"
				+ " and the question that nobody with power ever seemed to want answered:"
				+ " if it didn't work, why did they work so hard to stop him?"
			),
			"price": 420,
		},
		{
			"id": "wfc",
			"display_name": "Water Fuel Cell",
			"title": "Stanley Meyer Water Fuel Cell",
			"description": (
				"A replication of the work by Stanley Meyer, this device represents one of"
				+ " the most captivating alternative energy visions of the modern era: a"
				+ " system said to unlock the power stored within ordinary water. Meyer"
				+ " proposed that water could be dissociated into hydrogen and oxygen not"
				+ " through brute-force electrolysis, but through precisely tuned"
				+ " high-voltage, low-current electrical pulses. His design centered around"
				+ " resonant charging coils and a carefully engineered water capacitor,"
				+ " where the molecular bonds of H2O were theorized to weaken under specific"
				+ " electrical frequencies. In his view, resonance, not raw amperage, was"
				+ " the key to dramatically increasing efficiency. If true, it suggested a"
				+ " paradigm shift in how electrical energy interacts with molecular"
				+ " structures.\n\n"
				+ "Stanley Meyer collapsed suddenly from a brain aneurysm just an hour after"
				+ " meeting with government officials at a Cracker Barrel restaurant in Ohio."
				+ " According to the story, he had refused to sell his patents for use in"
				+ " military applications, leaving those around him stunned as he fell before"
				+ " he could even leave the building. The abruptness of his death only"
				+ " deepened the aura of mystery surrounding his work.\n\n"
				+ "Meyer himself described the origins of his inventions in deeply personal,"
				+ " spiritual terms. He claimed that during moments between sleep and"
				+ " wakefulness, he received vivid visions of the Water Fuel Cell, images"
				+ " he believed were sent to him by angels. His Christian faith, he said,"
				+ " provided both the moral compass and the inspiration that guided him in"
				+ " turning those visions into mechanical reality."
			),
			"price": 555,
		},
		{
			"id": "coin_pusher",
			"display_name": "Coin Pusher",
			"title": "Coin Pusher Machine",
			"description": "A fully functional arcade coin pusher machine for your studio. Insert coins, watch them fall, and try your luck at the spinning wheel bonus.",
			"price": 12000,
		},
		{
			"id": "gallery_visitor",
			"display_name": "Gallery Visitor",
			"title": "Gallery Visitor Pass",
			"description": "Invites another visitor to your gallery. Each visitor increases the sale value of your shipped paintings. The more eyes on your work, the more it's worth.",
			"price": 500,
			"repeatable": true,
		},
		{
			"id": "worklamp",
			"display_name": "Work Lamp",
			"title": "Work Lamp",
			"description": "A sturdy adjustable work lamp. Light up your workspace, or carry it around to illuminate whatever catches your eye.",
			"price": 500,
		},
		{
			"id": "rf_receiver",
			"display_name": "RF Receiver",
			"title": "RF Receiver",
			"description": "A small radio frequency receiver module. Plug it into the boombox to pick up live radio stations from around the world. Without it, you're stuck with whatever tapes you've got.",
			"price": 500,
			"no_prop": true,
		},
		{
			"id": "boombox",
			"display_name": "Boombox",
			"title": "Boombox",
			"description": "A portable stereo sitting in the studio. Old school. Moves very strangely when playing.",
			"price": 0,
			"always_present": true,
		},
		{
			"id": "basketball",
			"display_name": "Basketball",
			"title": "Basketball",
			"description": "A cheap knock off non brand name basketball. How did this even get into the gallery? Whose child is bouncing balls in a gallery?",
			"price": 0,
			"always_present": true,
		},
		{
			"id": "customstickerbutton",
			"display_name": "Custom Sticker Modder",
			"title": "Custom Sticker Modding button",
			"description": "Purchasing this adds a Blue Button to the game in a hidden location. Pressing it allows you to Modify Studio Sim, by adding your own custom Stickers to the painting UI array. Hint: You will need to crouch to reach it.",
			"price": 2500,
		},
	]
	_apply_desc_keys()


func _apply_desc_keys() -> void:
	"""Assign translation keys for item descriptions (avoids multi-line CSV keys)."""
	var keys := {
		"nail_gun": "SHOP_DESC_NAIL_GUN",
		"trash_can": "SHOP_DESC_TRASH_CAN",
		"fan": "SHOP_DESC_FAN",
		"styrofoam_cube": "SHOP_DESC_STYROFOAM_CUBE",
		"cardboard_box": "SHOP_DESC_CARDBOARD_BOX",
		"water_filter": "SHOP_DESC_WATER_FILTER",
		"phone": "SHOP_DESC_PHONE",
		"mirror": "SHOP_DESC_MIRROR",
		"skateboard": "SHOP_DESC_SKATEBOARD",
		"monstera": "SHOP_DESC_MONSTERA",
		"fern_plant": "SHOP_DESC_FERN_PLANT",
		"madpalm": "SHOP_DESC_MADPALM",
		"psywheel": "SHOP_DESC_PSYWHEEL",
		"cyclone": "SHOP_DESC_CYCLONE",
		"seg": "SHOP_DESC_SEG",
		"geet": "SHOP_DESC_GEET",
		"wfc": "SHOP_DESC_WFC",
		"coin_pusher": "SHOP_DESC_COIN_PUSHER",
		"gallery_visitor": "SHOP_DESC_GALLERY_VISITOR",
		"customstickerbutton": "SHOP_DESC_CUSTOM_STICKER",
		"worklamp": "SHOP_DESC_WORKLAMP",
		"rf_receiver": "SHOP_DESC_RF_RECEIVER",
	}
	for item in _catalog:
		if keys.has(item["id"]):
			item["desc_key"] = keys[item["id"]]
