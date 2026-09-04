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
	var metrics := _shadow_difference_metrics(without_shadow, with_shadow)
	var mean_difference := float(metrics["mean"])
	if mean_difference < 0.35:
		push_error("Cloud shadows are not visibly affecting the normal spawn view: %.3f" % mean_difference)
		quit(1)
		return
	if mean_difference > 2.0:
		push_error("Cloud shadow output is abnormally strong, likely because its shader failed: %.3f" % mean_difference)
		quit(1)
		return
	var roughness := float(metrics["roughness"])
	if roughness > 0.30:
		push_error("Cloud shadow edges contain visible high-frequency patterning: %.3f" % roughness)
		quit(1)
		return
	print("CLOUD_SHADOW_CAPTURE_OK: %s mean_difference=%.3f roughness=%.3f" % [output_path, mean_difference, roughness])
	quit()


func _shadow_difference_metrics(before: Image, after: Image) -> Dictionary:
	var before_bytes := before.get_data()
	var after_bytes := after.get_data()
	var width := before.get_width()
	var height := before.get_height()
	var differences := PackedFloat32Array()
	differences.resize(width * height)
	var total := 0.0
	for pixel: int in range(width * height):
		var index := pixel * 4
		var difference := (
			absf(float(before_bytes[index]) - float(after_bytes[index]))
			+ absf(float(before_bytes[index + 1]) - float(after_bytes[index + 1]))
			+ absf(float(before_bytes[index + 2]) - float(after_bytes[index + 2]))
		) / 3.0
		differences[pixel] = difference
		total += difference
	var neighbor_delta := 0.0
	for y: int in range(height):
		for x: int in range(width):
			var pixel := y * width + x
			if x + 1 < width:
				neighbor_delta += absf(differences[pixel] - differences[pixel + 1])
			if y + 1 < height:
				neighbor_delta += absf(differences[pixel] - differences[pixel + width])
	return {
		"mean": total / maxf(float(width * height), 1.0),
		"roughness": neighbor_delta / maxf(total, 1.0),
	}
