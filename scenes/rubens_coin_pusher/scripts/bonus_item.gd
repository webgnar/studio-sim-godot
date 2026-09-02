extends RigidBody3D

## A "jackpot" bonus prize that drops in place of a plain ball every 200
## points (see GameManager.add_score/BONUS_ITEMS). Same sphere-collision
## approach as ball.gd, but the visual is one of the imported
## models/coinpusher_items/*.glb models instead of a plain sphere mesh —
## picked and configured by GameManager before this node enters the tree.
##
## `bonus_data` must be set (via set_meta) before this node is added to the
## tree: {"path": String, "scale": float, "radius": float, "offset": Vector3}.
## - scale: uniform scale so the model's longest dimension matches the other
##   bonus items (they're wildly different sizes natively — see GameManager).
## - offset: recenters the model so its bounding-box center (not its own
##   origin, which several of these are off-center from) lines up with the
##   RigidBody's origin, i.e. the center of the SphereShape3D collision.

func _ready():
	var data: Dictionary = get_meta("bonus_data", {})
	var model_path: String = data.get("path", "")
	var model_scale: float = data.get("scale", 0.01)
	var radius: float = data.get("radius", 0.09)
	var offset: Vector3 = data.get("offset", Vector3.ZERO)

	mass = 0.015  # heavier than the plain ball (0.005), roughly matching its larger size
	add_to_group("balls")  # same scoring/cleanup path as the plain ball — see main.gd's _on_score
	continuous_cd = true

	var phys = PhysicsMaterial.new()
	phys.friction = 0.5
	phys.bounce = 0.3
	physics_material_override = phys

	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)

	if model_path != "":
		var scene: PackedScene = load(model_path)
		if scene:
			var inst := scene.instantiate()
			add_child(inst)
			inst.scale = Vector3.ONE * model_scale
			inst.position = offset

func _physics_process(_delta):
	# Relative to the machine's own position, not a hardcoded world Y — see the
	# same fix in coin.gd/ball.gd for why.
	if GameManager.main_scene and global_position.y < GameManager.main_scene.global_position.y - 5:
		queue_free()
