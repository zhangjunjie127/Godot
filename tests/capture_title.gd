extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://start_menu.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	RenderingServer.force_draw(false)
	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("title_cover.png")
	var error := root.get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Failed to save title screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	quit()
