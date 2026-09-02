extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var day_night := scene.get_node("DayNightCycle")
	var weather := scene.get_node("Weather/Effect")
	var player := scene.get_node("World/DepthSorted/Player") as Node2D
	var clouds := scene.get_node("World/Clouds")
	day_night.set_game_time(1, 10.0)
	weather.set_weather("晴朗")
	clouds.set_weather("晴朗")
	scene._dismiss_forecast()
	for index: int in range(2):
		var shadow := clouds.clouds[index]["sprite"] as Sprite2D
		shadow.visible = true
		shadow.global_position = player.global_position + Vector2(0.0, 20.0)
		shadow.scale = Vector2.ONE * 1.9
	for index: int in range(2, clouds.clouds.size()):
		(clouds.clouds[index]["sprite"] as Sprite2D).visible = false

	for _frame: int in range(3):
		await physics_frame
	RenderingServer.force_draw(false)
	var output_path := ProjectSettings.globalize_path("res://tests/output/cloud_shadow_overlap.png")
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.save_png(output_path) != OK:
		push_error("Failed to capture ordered cloud-shadow overlap")
		quit(1)
		return
	print("CLOUD_SHADOW_CAPTURE_OK: " + output_path)
	quit()
