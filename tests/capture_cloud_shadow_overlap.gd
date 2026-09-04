extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var day_night := scene.get_node("DayNightCycle")
	var weather := scene.get_node("Weather/Effect")
	var clouds := scene.get_node("World/Clouds")
	day_night.set_game_time(1, 10.0)
	weather.set_weather("晴朗")
	clouds.set_weather("晴朗")
	scene._dismiss_forecast()
	day_night.process_mode = Node.PROCESS_MODE_DISABLED
	weather.process_mode = Node.PROCESS_MODE_DISABLED
	clouds.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("World/DepthSorted").visible = false
	scene.get_node("HUD").visible = false
	scene.get_node("ScreenWeather").visible = false
	scene.get_node("NightVision").visible = false
	for chunk: Node in scene.get_node("World/Foundation").get_children():
		var water_surface := chunk.get_node_or_null("WaterSurface") as CanvasItem
		if water_surface != null:
			water_surface.visible = false

	var active_shadows: Array[Sprite2D] = []
	for cloud: Dictionary in clouds.clouds:
		var shadow := cloud["sprite"] as Sprite2D
		if shadow.visible:
			active_shadows.append(shadow)
		shadow.visible = false
	await process_frame
	RenderingServer.force_draw(false)
	var without_shadow := root.get_viewport().get_texture().get_image()
	for shadow: Sprite2D in active_shadows:
		shadow.visible = true
	await process_frame
	RenderingServer.force_draw(false)
	var with_shadow := root.get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://tests/output/cloud_shadow_overlap.png")
	without_shadow.save_png(ProjectSettings.globalize_path("res://tests/output/cloud_shadow_without.png"))
	if with_shadow == null or with_shadow.save_png(output_path) != OK:
		push_error("Failed to capture ordered cloud-shadow overlap")
		quit(1)
		return
	var mean_difference := _mean_rgb_difference(without_shadow, with_shadow)
	if mean_difference < 0.35:
		push_error("Cloud shadows are not visibly affecting the normal spawn view: %.3f" % mean_difference)
		quit(1)
		return
	print("CLOUD_SHADOW_CAPTURE_OK: %s mean_difference=%.3f" % [output_path, mean_difference])
	quit()


func _mean_rgb_difference(before: Image, after: Image) -> float:
	var before_bytes := before.get_data()
	var after_bytes := after.get_data()
	var total := 0.0
	for index: int in range(0, mini(before_bytes.size(), after_bytes.size()), 4):
		total += absf(float(before_bytes[index]) - float(after_bytes[index]))
		total += absf(float(before_bytes[index + 1]) - float(after_bytes[index + 1]))
		total += absf(float(before_bytes[index + 2]) - float(after_bytes[index + 2]))
	return total / maxf(float(before.get_width() * before.get_height() * 3), 1.0)
