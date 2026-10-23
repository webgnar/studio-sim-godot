extends SceneTree
# usage: -- <outdir> <scene> name:px,py,pz:tx,ty,tz [...]
func _initialize():
	var args = OS.get_cmdline_user_args()
	var outdir = args[0]
	var scene = load(args[1]).instantiate()
	root.add_child(scene)
	for n in scene.find_children("*", "CanvasLayer", true, false): n.visible = false
	await process_frame
	for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
	var cam = Camera3D.new()
	cam.fov = 75
	root.add_child(cam)
	cam.make_current()
	for i in range(30): await process_frame
	for spec in args.slice(2):
		var p = spec.split(":")
		var pos = Vector3(float(p[1].split(",")[0]), float(p[1].split(",")[1]), float(p[1].split(",")[2]))
		var tgt = Vector3(float(p[2].split(",")[0]), float(p[2].split(",")[1]), float(p[2].split(",")[2]))
		cam.global_position = pos
		cam.look_at(tgt)
		cam.make_current()
		for i in range(8): await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(outdir + "/" + p[0] + ".png")
	quit()
