extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	scene.get_node("DayNightCycle").set_game_time(1, 11.0)
	scene.get_node("Weather/Effect").set_weather("晴朗")
	scene._dismiss_forecast()
	scene.enter_underwater()
	var player = scene.player
	player.global_position = Vector2(820.0, 430.0)
	player.set_oxygen(76.0)
	Input.action_press("ui_right")
	for _frame: int in range(12):
		await physics_frame
	Input.action_release("ui_right")
	RenderingServer.force_draw(false)

	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("underwater_gameplay.png")
	var error := root.get_viewport().get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Failed to save underwater screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	quit()
