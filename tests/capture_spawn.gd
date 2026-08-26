extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_viewport().get_texture().get_image()
	var output_path := output_dir.path_join("spawn_gameplay.png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save gameplay screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	quit()
