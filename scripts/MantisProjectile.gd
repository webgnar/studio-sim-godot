extends CharacterBody3D
class_name MantisProjectile

var direction: Vector3
var speed: float
var sprite_frames: SpriteFrames
var spark_texture: Texture2D
var _lifetime: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2

	var shape := SphereShape3D.new()
	shape.radius = 0.2
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = sprite_frames
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.005
	sprite.play("default")
	add_child(sprite)

func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime > 8.0:
		queue_free()
		return

	velocity = direction * speed
	move_and_slide()

	if get_slide_collision_count() > 0:
		_spawn_spark()
		queue_free()

func _spawn_spark() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = spark_texture
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var mesh := QuadMesh.new()
	mesh.material = mat
	mesh.size = Vector2(0.6, 0.6)

	var spark := MeshInstance3D.new()
	spark.mesh = mesh
	spark.global_position = global_position
	get_tree().root.add_child(spark)

	var tween := get_tree().create_tween()
	tween.tween_property(spark, "scale", Vector3.ZERO, 0.3).from(Vector3.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(spark.queue_free)
