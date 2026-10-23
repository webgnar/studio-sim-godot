extends SceneTree
## Turns the static CSG shells of world.tscn into meshes with a lightmap UV2,
## so LightmapGI can bake them (CSG itself can't be baked).
## Run after editing any of these CSG nodes, then re-bake the LightmapGI:
##   godot --path . --script res://tools/bake_csg_shells.gd
## The CSG nodes stay in the scene, hidden, for their collision.

const OUT_DIR := "res://scenes/world_lightmap"
const TEXEL := 0.1  # meters per lightmap texel

const SHELLS := [
	"celing", "celing2", "hallway", "studio", "gallery", "hall of fame",
	"AssistantStudio/CSGCombiner3D", "hvac group/CSGCombiner3D", "greenhouse/CSGCombiner3D",
	"gallery/NavigationRegion3D/floor", "gallery/NavigationRegion3D/pedestal",
	"gallery/NavigationRegion3D/pedestal2", "gallery/NavigationRegion3D/pedestal3",
	"gallery/NavigationRegion3D/CSGBox3D", "gallery/NavigationRegion3D/wall south",
	"gallery/NavigationRegion3D/wall g2 south", "gallery/NavigationRegion3D/wall g2 south3",
	"gallery/NavigationRegion3D/wall g2 south4", "gallery/NavigationRegion3D/wall west",
	"gallery/NavigationRegion3D/wall east", "gallery/NavigationRegion3D/wall north",
	"gallery/Hidden Door/CSGBox3D",
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var w: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	for i in 3: await process_frame
	for path: String in SHELLS:
		var csg := w.get_node(path) as CSGShape3D
		var mesh := csg.bake_static_mesh()
		var before := mesh.get_aabb()
		var err := mesh.lightmap_unwrap(Transform3D(csg.global_basis, Vector3.ZERO), TEXEL)
		var file: String = OUT_DIR + "/" + path.replace("/", "_").replace(" ", "_") + ".res"
		ResourceSaver.save(mesh, file, ResourceSaver.FLAG_COMPRESS)
		print("SHELL ", path, " -> ", file, " err=", err, " size_hint=", mesh.lightmap_size_hint, " aabb ", before, " -> ", mesh.get_aabb())
	quit()
