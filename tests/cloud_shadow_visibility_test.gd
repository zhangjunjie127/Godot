extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var day_night = scene.get_node("DayNightCycle")
	var clouds = scene.get_node("World/Clouds")
	day_night.process_mode = Node.PROCESS_MODE_DISABLED

	day_night.set_game_time(1, 10.0)
	clouds.set_weather("晴朗")
	if not clouds.visible or clouds.get_shadow_coverage() <= 0.001:
		_fail("Clear daytime did not enable cloud shadows")
		return

	for weather_name: String in ["阴天", "下雨", "下雪"]:
		clouds.set_weather(weather_name)
		if clouds.visible or clouds.get_shadow_coverage() > 0.001:
			_fail("Cloud shadows remained active during " + weather_name)
			return

	clouds.set_weather("晴朗")
	for time_case: Dictionary in [{"hour": 19.0, "name": "黄昏"}, {"hour": 22.0, "name": "夜晚"}]:
		day_night.set_game_time(1, float(time_case["hour"]))
		if clouds.visible or clouds.get_shadow_coverage() > 0.001:
			_fail("Cloud shadows remained active during " + String(time_case["name"]))
			return

	print("CLOUD_SHADOW_VISIBILITY_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
