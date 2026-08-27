extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	var capture_hour := 7.0
	var capture_panel := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hour="):
			capture_hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--panel="):
			capture_panel = argument.trim_prefix("--panel=")
	var day_night_cycle = scene.get_node("DayNightCycle")
	day_night_cycle.set_game_time(1, capture_hour)
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	if capture_panel == "inventory":
		scene._toggle_inventory()
	elif capture_panel == "skills":
		scene._toggle_skill_tree()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_viewport().get_texture().get_image()
	var suffix := "night" if capture_hour < 5.0 or capture_hour >= 21.0 else "day"
	if not capture_panel.is_empty():
		suffix += "_" + capture_panel
	var output_path := output_dir.path_join("spawn_gameplay_" + suffix + ".png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save gameplay screenshot")
		quit(1)
		return
	print("SCREENSHOT_OK: " + output_path)
	quit()
