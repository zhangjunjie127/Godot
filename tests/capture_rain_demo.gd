extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed_scene := load("res://effects/rain/RainDemo.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	for _frame: int in range(90):
		await physics_frame
	RenderingServer.force_draw(false)
	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("rain_demo.png")
	var error := root.get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Failed to save rain demo screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	scene.rain_visual.set_intensity(0.0)
	await process_frame
	scene.free()
	await process_frame
	quit()
