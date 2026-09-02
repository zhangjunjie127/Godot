extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var player := scene.get_node("World/DepthSorted/Player") as Node2D
	var boar := scene.get_node("World/DepthSorted/WildBoar") as Node2D
	var vegetation := scene.get_node("World/DepthSorted/CentralVegetation") as Node2D
	var tree_a := scene.get_node("World/DepthSorted/CentralVegetation/Tree001") as Node2D
	var tree_b := scene.get_node("World/DepthSorted/CentralVegetation/Tree002") as Node2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	boar.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in vegetation.get_children():
		(child as CanvasItem).visible = child == tree_a or child == tree_b
	tree_a.global_position = player.global_position + Vector2(-105.0, 105.0)
	tree_b.global_position = player.global_position + Vector2(105.0, 105.0)
	boar.global_position = player.global_position + Vector2(150.0, 105.0)
	player.get_node("Camera2D").zoom = Vector2(0.58, 0.58)
	scene.get_node("DayNightCycle").set_game_time(1, 10.0)
	scene.get_node("Weather/Effect").set_weather("晴朗")
	scene.get_node("World/Clouds").visible = false
	scene._dismiss_forecast()

	for _frame: int in range(8):
		await physics_frame
	RenderingServer.force_draw(false)
	var output_path := ProjectSettings.globalize_path("res://tests/output/unified_shadows.png")
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.save_png(output_path) != OK:
		push_error("Failed to capture unified ground shadows")
		quit(1)
		return
	print("UNIFIED_SHADOW_CAPTURE_OK: " + output_path)
	scene.free()
	await process_frame
	quit()
