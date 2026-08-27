extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	var capture_hour := 7.0
	var capture_panel := ""
	var capture_state := ""
	var capture_weather := "下雨"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hour="):
			capture_hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--panel="):
			capture_panel = argument.trim_prefix("--panel=")
		elif argument.begins_with("--state="):
			capture_state = argument.trim_prefix("--state=")
		elif argument.begins_with("--weather="):
			capture_weather = argument.trim_prefix("--weather=")
	var day_night_cycle = scene.get_node("DayNightCycle")
	day_night_cycle.set_game_time(1, capture_hour)
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	var weather = scene.get_node("Weather/Effect")
	weather.set_weather(capture_weather)
	if capture_panel == "inventory":
		scene._toggle_inventory()
	elif capture_panel == "skills":
		scene._toggle_skill_tree()
	match capture_state:
		"crouch":
			Input.action_press("player_crouch")
		"prone":
			Input.action_press("player_crawl")
		"crawl":
			Input.action_press("player_crawl")
			Input.action_press("ui_right")
		"jump":
			Input.action_press("player_jump")
	var capture_frames := 24 if capture_weather == "下雨" else 12 if not capture_state.is_empty() else 2
	for _frame: int in range(capture_frames):
		await physics_frame
	await RenderingServer.frame_post_draw

	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_viewport().get_texture().get_image()
	var suffix := "night" if capture_hour < 5.0 or capture_hour >= 21.0 else "day"
	if not capture_panel.is_empty():
		suffix += "_" + capture_panel
	if not capture_state.is_empty():
		suffix += "_" + capture_state
	if not capture_weather.is_empty():
		suffix += "_" + capture_weather
	var output_path := output_dir.path_join("spawn_gameplay_" + suffix + ".png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save gameplay screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	quit()
