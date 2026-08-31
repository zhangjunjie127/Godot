extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")
	var camera := player.get_node("Camera2D") as Camera2D
	var weather = scene.get_node("Weather/Effect")
	camera.position_smoothing_enabled = false
	weather.start_weather_event("晴朗", "半天")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	scene._dismiss_forecast()
	player.global_position = Vector2(7000.0, 3000.0)
	player.set_surface_swimming(true)
	Input.action_press("ui_down")
	for _frame: int in range(45):
		await physics_frame
	Input.action_release("ui_down")
	for _frame: int in range(3):
		await process_frame

	var first_path := OS.get_temp_dir().path_join("surface_water_before.png")
	var second_path := OS.get_temp_dir().path_join("surface_water_after.png")
	root.get_viewport().get_texture().get_image().save_png(first_path)
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(second_path)
	print("SURFACE_WATER_CAPTURED:%s|%s" % [first_path, second_path])
	scene.free()
	await process_frame
	quit()
