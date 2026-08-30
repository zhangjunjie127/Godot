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
	weather.advance_visual_seconds(weather.day_ambience_fade_seconds)
	var birds := scene.get_node("Weather/DayBirds") as AudioStreamPlayer
	var wind := scene.get_node("Weather/DayWind") as AudioStreamPlayer
	if weather.get_day_ambience_amount() < 0.99 or birds.stream == null or wind.stream == null:
		_fail("Clear daytime ambience did not fade in with both audio tracks")
		return
	if weather.get_day_birds_volume_db() < weather.birds_max_volume_db - 0.1 or weather.get_day_wind_volume_db() < weather.wind_max_volume_db - 0.1:
		_fail("Clear daytime ambience did not reach its configured volume")
		return
	if (birds.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD or (wind.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail("Clear daytime ambience tracks are not configured to loop")
		return

	day_night.set_game_time(1, 19.0)
	weather.advance_visual_seconds(weather.day_ambience_fade_seconds)
	if weather.get_day_ambience_amount() != 0.0 or weather.get_day_birds_volume_db() > -49.9 or weather.get_day_wind_volume_db() > -49.9:
		_fail("Clear daytime ambience did not fade out at dusk")
		return

	print("WEATHER_STORM_OK: storms and clear daytime ambience")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
