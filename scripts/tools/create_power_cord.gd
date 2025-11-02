@tool
extends EditorScript

## Quick tool to create a power cord scene
## Run this from Editor → Run Script

func _run() -> void:
	print("🔧 Creating power cord scene...")
	
	# Create root
	var root = Node3D.new()
	root.name = "PowerCord"
	
	# Add PowerCord script
	var script = load("res://scripts/components/PowerCord.gd")
	root.set_script(script)
	
	# Create anchor point (Marker3D)
	var anchor = Marker3D.new()
	anchor.name = "AnchorPoint"
	anchor.position = Vector3.ZERO
	root.add_child(anchor)
	anchor.set_owner(root)
	
	# Create plug (RigidBody3D)
	var plug = RigidBody3D.new()
	plug.name = "Plug"
	plug.position = Vector3(0, -1.5, 0)  # Hang down 1.5m
	plug.mass = 0.2
	plug.linear_damp = 2.0
	plug.angular_damp = 3.0
	plug.collision_layer = 4
	plug.collision_mask = 3
	root.add_child(plug)
	plug.set_owner(root)
	
	# Add collision to plug
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.05
	collision.shape = shape
	plug.add_child(collision)
	collision.set_owner(root)
	
	# Add plug visual
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.1
	mesh_inst.mesh = mesh
	plug.add_child(mesh_inst)
	mesh_inst.set_owner(root)
	
	# Add PowerCordPlugComponent
	var plug_component_script = load("res://scripts/components/PowerCordPlugComponent.gd")
	var plug_component = Node.new()
	plug_component.set_script(plug_component_script)
	plug_component.name = "PowerCordPlugComponent"
	plug.add_child(plug_component)
	plug_component.set_owner(root)
	
	# Set references on PowerCord
	root.anchor_point = anchor
	root.plug_body = plug
	
	# Save scene
	var scene = PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, "res://scenes/props/power_cord.tscn")
	
	print("✅ Power cord scene created at scenes/props/power_cord.tscn")
	print("   - AnchorPoint: Position this where you want the fixed end")
	print("   - Plug: Physics object player can pick up")
