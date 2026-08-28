extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var capture_hour := 7.0
	var capture_panel := ""
	var capture_state := ""
	var capture_weather := "下雨"
	var capture_rain_level := "中雨"
	var capture_snow_level := "中雪"
	var capture_gender := "male"
	var capture_torch := true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hour="):
			capture_hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--panel="):
			capture_panel = argument.trim_prefix("--panel=")
		elif argument.begins_with("--state="):
			capture_state = argument.trim_prefix("--state=")
		elif argument.begins_with("--weather="):
			capture_weather = argument.trim_prefix("--weather=")
		elif argument.begins_with("--rain-level="):
			capture_rain_level = argument.trim_prefix("--rain-level=")
		elif argument.begins_with("--snow-level="):
			capture_snow_level = argument.trim_prefix("--snow-level=")
		elif argument.begins_with("--gender="):
			capture_gender = argument.trim_prefix("--gender=")
		elif argument == "--no-torch":
			capture_torch = false
	root.get_node("GameSession").select_gender(capture_gender)
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	if not capture_torch:
		scene.inventory.remove_item("torch", 1)
	var day_night_cycle = scene.get_node("DayNightCycle")
	day_night_cycle.set_game_time(1, capture_hour)
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	var weather = scene.get_node("Weather/Effect")
	weather.set_weather(capture_weather)
	if capture_weather == "下雨":
		weather.set_rain_level(capture_rain_level)
		weather.advance_visual_seconds(weather.rain_fade_seconds)
	elif capture_weather == "下雪":
		weather.set_snow_level(capture_snow_level)
		weather.advance_visual_seconds(weather.rain_fade_seconds)
	if capture_panel == "inventory":
		scene._toggle_inventory()
	elif capture_panel == "skills":
		scene._toggle_skill_tree()
	elif capture_panel == "map":
		scene._toggle_world_map()
	elif capture_panel == "forecast":
		scene._show_weather_forecast(weather.get_forecast(2))
	match capture_state:
		"crouch":
			Input.action_press("player_crouch")
		"prone":
			Input.action_press("player_crawl")
		"crawl":
			Input.action_press("player_crawl")
			Input.action_press("ui_right")
		"walk_down":
			Input.action_press("ui_down")
		"jump":
			Input.action_press("player_jump")
		"pickup":
			Input.action_press("player_pickup")
		"idle_relaxed":
			scene.player._idle_elapsed = 1.0
		"idle_sit":
			scene.player.seated_idle_delay = 0.0
	var capture_frames := 60 if capture_weather == "下雨" else 12 if not capture_state.is_empty() else 2
	for _frame: int in range(capture_frames):
		await physics_frame
	RenderingServer.force_draw(false)

	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_viewport().get_texture().get_image()
	var suffix := "night" if capture_hour < 6.0 or capture_hour >= 21.0 else "dusk" if capture_hour >= 18.0 else "day"
	if not capture_panel.is_empty():
		suffix += "_" + capture_panel
	if not capture_state.is_empty():
		suffix += "_" + capture_state
	if not capture_torch:
		suffix += "_no_torch"
	if not capture_weather.is_empty():
		suffix += "_" + capture_weather
	if capture_weather == "下雨":
		suffix += "_" + capture_rain_level
	elif capture_weather == "下雪":
		suffix += "_" + capture_snow_level
	suffix += "_" + capture_gender
	var output_path := output_dir.path_join("spawn_gameplay_" + suffix + ".png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save gameplay screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	scene.free()
	await process_frame
	quit()
