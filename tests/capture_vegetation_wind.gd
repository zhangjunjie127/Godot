extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("World/DepthSorted/Player") as Node2D
	var vegetation := scene.get_node("World/DepthSorted/CentralVegetation") as Node2D
	var palm_root := scene.get_node("World/DepthSorted/NortheastPalm01") as Node2D
	var palm := palm_root.get_node("Sprite2D") as Sprite2D
	var tree_root := vegetation.get_node("Tree004") as Node2D
	var tree := tree_root.get_node("Sprite2D") as Sprite2D
	var leaf_root := vegetation.get_node("TropicalPlant010") as Node2D
	var leaf_plant := leaf_root.get_node("Sprite2D") as Sprite2D

	for child: Node in vegetation.get_children():
		(child as CanvasItem).visible = child == tree_root or child == leaf_root
	palm_root.global_position = player.global_position + Vector2(-155.0, 115.0)
	tree_root.global_position = player.global_position + Vector2(30.0, 115.0)
	leaf_root.global_position = player.global_position + Vector2(175.0, 115.0)
	player.visible = false
	player.get_node("Camera2D").zoom = Vector2(0.66, 0.66)
	scene.get_node("World/DepthSorted/WildBoar").visible = false
	scene.get_node("World/Clouds").visible = false
	scene._dismiss_forecast()

	for sprite: Sprite2D in [palm, tree, leaf_plant]:
		sprite.process_mode = Node.PROCESS_MODE_DISABLED
		sprite.set_wind_strength(1.2)
		sprite.advance_wind(0.0)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame: int in range(4):
		await process_frame
	var before := _viewport_image()
	before.save_png(ProjectSettings.globalize_path("res://tests/output/vegetation_wind_before.png"))

	for sprite: Sprite2D in [palm, tree, leaf_plant]:
		sprite.advance_wind(1.1)
	for _frame: int in range(2):
		await process_frame
	var after := _viewport_image()
	after.save_png(ProjectSettings.globalize_path("res://tests/output/vegetation_wind_after.png"))
	if _changed_pixel_count(before, after) < 120:
		push_error("Vegetation wind did not produce a visible canopy deformation")
		quit(1)
		return
	print("VEGETATION_WIND_CAPTURE_OK")
	scene.free()
	await process_frame
	quit()


func _viewport_image() -> Image:
	RenderingServer.force_draw(false)
	return root.get_viewport().get_texture().get_image()


func _changed_pixel_count(before: Image, after: Image) -> int:
	var changed := 0
	for y: int in range(0, before.get_height(), 2):
		for x: int in range(0, before.get_width(), 2):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
				changed += 1
	return changed
