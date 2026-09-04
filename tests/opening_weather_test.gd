extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var weather = scene.get_node("Weather/Effect")
	var day_night = scene.get_node("DayNightCycle")
	weather.process_mode = Node.PROCESS_MODE_DISABLED
	day_night.process_mode = Node.PROCESS_MODE_DISABLED
	if weather.current_weather != weather.WEATHER_CLEAR or weather.remaining_game_minutes != 5340:
		_fail("Opening weather is not locked clear through the end of day four")
		return
	for forecast: Dictionary in weather.get_forecast(2):
		if String(forecast["weather"]) != weather.WEATHER_CLEAR:
			_fail("Opening forecast contains non-clear weather")
			return
	if weather.trigger_special_weather(weather.WEATHER_RAIN):
		_fail("Special weather bypassed the opening clear-weather lock")
		return
	day_night.set_game_time(4, 23.5)
	if weather.current_weather != weather.WEATHER_CLEAR or weather.remaining_game_minutes != 30:
		_fail("Clear-weather lock ended before day five")
		return
	day_night.set_game_time(5, 0.0)
	if weather.current_weather == weather.WEATHER_CLEAR:
		_fail("Random weather did not resume on day five")
		return
	print("OPENING_WEATHER_OK: days 1-4 clear, random weather resumes on day 5")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
