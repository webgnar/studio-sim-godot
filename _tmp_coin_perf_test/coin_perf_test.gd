extends Node3D
# TEMP headless perf/destroy test for the coin pusher. Delete after use.

const SHOTS := 800
const SHOT_INTERVAL_FRAMES := 15  # 4 shots/sec at 60 fps

var machine: Node3D
var shoot_area: Node
var rain: Node
var variant := "baseline"
var frame := 0
var shots := 0
var tracked := {}
var tracked_balls := {}
var balls_seen := 0
var destroyed := {"scored": 0, "fell_killplane": 0, "cap_or_other": 0}
var spawned := 0
var frame_usec_accum := 0
var frame_count_accum := 0
var last_usec := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("variant="):
			variant = a.substr(8)
	var proxy := Node3D.new()
	add_child(proxy)
	# Exact transform CoinPusherMachine has in world.tscn
	proxy.transform = Transform3D(Basis(Vector3(-4.371139e-08, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, -4.371139e-08)), Vector3(-4.2185297, -15.550892, 16.855978))
	machine = load("res://scenes/rubens_coin_pusher/scenes/coin_pusher.tscn").instantiate()
	proxy.add_child(machine)
	shoot_area = machine.get_node("CoinShootArea")
	# The real in-world listener for ball payouts (EconomyManager.painting_sold)
	rain = load("res://scenes/UI/MoneyRainLayer.tscn").instantiate()
	add_child(rain)
	GameManager.coins_loaded = 100000
	print("variant=", variant, " machine global=", machine.global_position)
	last_usec = Time.get_ticks_usec()

func _physics_process(_delta: float) -> void:
	for c in get_tree().get_nodes_in_group("coins"):
		var id := c.get_instance_id()
		if not tracked.has(id):
			tracked[id] = true
			spawned += 1
			c.tree_exiting.connect(_on_coin_exit.bind(c))
			if "sleep" in variant:
				c.can_sleep = true
			if "nocontact" in variant:
				c.contact_monitor = false
			if "nocd" in variant:
				c.continuous_cd = false
	if variant.begins_with("cap"):
		var cap := int(variant.substr(3))
		var cs := get_tree().get_nodes_in_group("coins")
		for i in maxi(cs.size() - cap, 0):
			cs[i].queue_free()
	for b in get_tree().get_nodes_in_group("balls"):
		var bid := b.get_instance_id()
		if not tracked_balls.has(bid):
			tracked_balls[bid] = true
			balls_seen += 1

	frame += 1
	if frame > 60 and frame % SHOT_INTERVAL_FRAMES == 0 and shots < SHOTS:
		shoot_area.interact(null)
		shots += 1
		if shots % 50 == 0:
			_report()
	if shots >= SHOTS and frame % 600 == 0:
		_report()
		for b in get_tree().get_nodes_in_group("balls"):
			var lp: Vector3 = machine.to_local(b.global_position)
			var r: float = (b.get_child(0) as CollisionShape3D).shape.radius
			print("    BALL r=%.3f bonus=%s local=(%.3f, %.3f, %.3f) speed=%.4f" % [r, b.has_meta("bonus_data"), lp.x, lp.y, lp.z, b.linear_velocity.length()])
		get_tree().quit()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	frame_usec_accum += now - last_usec
	frame_count_accum += 1
	last_usec = now

func _on_coin_exit(c: Node3D) -> void:
	var lp: Vector3 = machine.to_local(c.global_position)
	if lp.y < -5.0:
		destroyed.fell_killplane += 1
	elif lp.y < 0.62 and lp.z > -0.23 and lp.z < 0.0:
		destroyed.scored += 1
	else:
		destroyed.cap_or_other += 1

func _report() -> void:
	var coins := get_tree().get_nodes_in_group("coins")
	var escaped := 0
	var on_platform := 0
	var max_y := 0.0
	var asleep := 0
	for c in coins:
		var lp: Vector3 = machine.to_local(c.global_position)
		if absf(lp.x) > 0.36 or lp.z > 0.0 or lp.z < -1.2 or lp.y < 0.4 or lp.y > 1.9:
			escaped += 1
		elif lp.y > 0.88:
			on_platform += 1
			max_y = maxf(max_y, lp.y)
		if c.sleeping:
			asleep += 1
	var avg_ms := (frame_usec_accum / maxf(frame_count_accum, 1)) / 1000.0
	var balls := get_tree().get_nodes_in_group("balls")
	var bonus_alive := 0
	for b in balls:
		if b.has_meta("bonus_data"):
			bonus_alive += 1
	print("shots=%d spawned=%d alive=%d on_platform=%d escaped=%d asleep=%d pile_top_y=%.3f score=%d destroyed=%s | avg_frame=%.2fms physics_time=%.2fms" % [
		shots, spawned, coins.size(), on_platform, escaped, asleep, max_y, GameManager.score, destroyed, avg_ms,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	print("    balls_dropped=%d balls_alive=%d (bonus_alive=%d) pending_drops=%d nodes=%d orphans=%d objects=%d active_bodies=%d pairs=%d rain_children=%d" % [
		balls_seen, balls.size(), bonus_alive, GameManager.pending_drops.size(),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), rain.get_child_count() if rain else -1])
	frame_usec_accum = 0
	frame_count_accum = 0
	last_usec = Time.get_ticks_usec()
