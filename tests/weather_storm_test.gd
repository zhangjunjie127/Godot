extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var weather = scene.get_node("Weather/Effect")
	var day_night = scene.get_node("DayNightCycle")
	var clouds = scene.get_node("World/Clouds")
	var environment: CanvasModulate = scene.get_node("World/DayNightTint")
	var wetness: ColorRect = scene.get_node("Weather/Wetness")

	day_night.set_game_time(1, 12.0)
	day_night.process_mode = Node.PROCESS_MODE_DISABLED
	weather.start_weather_event("阴天", "半天")
	weather.advance_visual_seconds(weather.atmosphere_fade_seconds)
	if weather.visual_cloudiness < 0.75 or weather.visual_rain_density != 0.0 or weather.visual_snow_density != 0.0:
		_fail("Overcast weather did not fade in independently from precipitation")
		return
	if clouds.get_active_cloud_count() != 8 or wetness.visible or environment.color.r >= 0.9:
		_fail("Overcast cloud cover or environment grading did not initialize")
		return

	weather.start_weather_event("下雨", "半天", "大雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var thunder_before: int = weather.get_thunder_play_count()
	if not weather.trigger_lightning(1.0, 0.5) or weather.get_lightning_strength() < 0.99 or not weather.has_pending_thunder():
		_fail("Heavy rain did not trigger an immediate flash with delayed thunder")
		return
	weather.advance_visual_seconds(0.49)
	if weather.get_thunder_play_count() != thunder_before or not weather.has_pending_thunder():
		_fail("Thunder played at the flash instead of after its travel delay")
		return
	weather.advance_visual_seconds(0.02)
	if weather.get_thunder_play_count() != thunder_before + 1 or weather.has_pending_thunder():
		_fail("Delayed rolling thunder did not play")
		return

	weather.start_weather_event("晴朗", "半天")
	weather.advance_visual_seconds(weather.atmosphere_fade_seconds)
	if weather.get_lightning_strength() != 0.0 or weather.trigger_lightning(1.0, 0.0) or clouds.get_active_cloud_count() != 4:
		_fail("Clear weather retained storm effects")
		return

	print("WEATHER_STORM_OK: overcast grading, double flash and delayed thunder")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
