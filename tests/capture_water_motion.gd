extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.get_node("GameSession").select_gender("male")
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame

	var player: CharacterBody2D = scene.get_node("World/DepthSorted/Player")
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("World/DepthSorted/WildBoar").process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("DayNightCycle").process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("Weather/Effect").process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("World/Clouds").process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("HUD").visible = false
	scene.get_node("ScreenWeather").visible = false
	scene.get_node("NightVision").visible = false

	var output_dir := ProjectSettings.globalize_path("res://tests/output/water_motion")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for _frame: int in range(12):
		await physics_frame
	RenderingServer.force_draw(false)
	root.get_viewport().get_texture().get_image().save_png(output_dir.path_join("before.png"))
	for _frame: int in range(120):
		await physics_frame
	RenderingServer.force_draw(false)
	root.get_viewport().get_texture().get_image().save_png(output_dir.path_join("after.png"))
	print("WATER_CAPTURE_OK: " + output_dir)
	scene.free()
	await process_frame
	quit()
