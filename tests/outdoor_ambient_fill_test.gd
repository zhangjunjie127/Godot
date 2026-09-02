extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var layer := scene.get_node_or_null("OutdoorAtmosphere") as CanvasLayer
	var fill := scene.get_node_or_null("OutdoorAtmosphere/Fill") as ColorRect
	var weather_layer := scene.get_node("Weather") as CanvasLayer
	var hud_layer := scene.get_node("HUD") as CanvasLayer
	if layer == null or fill == null or fill.material == null:
		_fail("Outdoor ambient fill layer did not initialize")
		return
	if layer.layer >= weather_layer.layer or layer.layer >= hud_layer.layer:
		_fail("Outdoor ambient fill would affect weather or HUD rendering")
		return

	var day_night := scene.get_node("DayNightCycle")
	day_night.set_weather_cloudiness(0.0)
	day_night.set_game_time(1, 10.0)
	await process_frame
	if fill.get_current_strength() < 0.095:
		_fail("Clear daytime ambient fill did not activate")
		return
	var clear_saturation := float(fill.material.get_shader_parameter("saturation"))
	var clear_exposure := float(fill.material.get_shader_parameter("exposure"))
	if clear_saturation >= 1.0 or clear_exposure >= 0.0:
		_fail("Clear daytime color grade did not restrain saturation and highlights")
		return

	day_night.set_weather_cloudiness(1.0)
	await process_frame
	if fill.get_current_strength() <= fill.daytime_strength:
		_fail("Overcast ambient fill did not increase diffuse shadow light")
		return
	if float(fill.material.get_shader_parameter("saturation")) >= clear_saturation or float(fill.material.get_shader_parameter("exposure")) >= clear_exposure:
		_fail("Overcast profile did not cool and flatten the outdoor grade")
		return

	day_night.set_game_time(1, 21.0)
	await process_frame
	if fill.get_current_strength() > 0.001:
		_fail("Outdoor ambient fill remained active at night")
		return

	print("OUTDOOR_AMBIENT_FILL_OK")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
