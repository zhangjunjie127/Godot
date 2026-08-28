extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("GameSession").select_gender("male")
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame

	var player = scene.get_node("World/DepthSorted/Player")
	var day_night = scene.get_node("DayNightCycle")
	var night_vision = scene.get_node("NightVision/Mask")
	day_night.process_mode = Node.PROCESS_MODE_DISABLED
	day_night.set_game_time(1, 21.0)
	await process_frame
	var outer_alpha: Variant = night_vision.material.get_shader_parameter("outer_alpha")
	if outer_alpha == null or not is_equal_approx(float(outer_alpha), 0.75):
		_fail("Night darkness is not 75 percent with a torch")
		return
	var torch_inner_alpha: Variant = night_vision.material.get_shader_parameter("torch_inner_alpha")
	if torch_inner_alpha == null or not is_equal_approx(float(torch_inner_alpha), 0.20):
		_fail("Torch-lit darkness is not 20 percent")
		return
	scene.inventory.remove_item("torch", 1)
	await process_frame
	outer_alpha = night_vision.material.get_shader_parameter("outer_alpha")
	if outer_alpha == null or not is_equal_approx(float(outer_alpha), 0.75):
		_fail("Night darkness changed when the torch was removed")
		return

	var clouds := scene.get_node_or_null("World/Clouds")
	if clouds == null or not (clouds is Node2D):
		_fail("Clouds are not world-space Node2D scenery")
		return
	clouds.set_weather("晴朗")
	var cloud_before: Vector2 = clouds.get_cloud_world_position(0)
	player.global_position += Vector2(260.0, 120.0)
	for _frame: int in range(60):
		await process_frame
	var cloud_after: Vector2 = clouds.get_cloud_world_position(0)
	if not is_equal_approx(cloud_after.y, cloud_before.y):
		_fail("Clouds followed the player or camera")
		return
	var cloud_distance := cloud_before.x - cloud_after.x
	if cloud_distance < 20.0:
		_fail("Clouds moved only %.2f units during real process frames" % cloud_distance)
		return

	var expected_items := [
		"wood_oak", "wood_pine", "wood_birch", "wood_palm", "wood_ancient",
		"fruit_berry", "fruit_banana", "fruit_coconut", "fruit_rainforest", "fruit_citrus",
		"meat_boar", "meat_poultry", "meat_fish", "meat_shellfish", "meat_strange",
	]
	for item_id: String in expected_items:
		if scene._item_icon(item_id) == null:
			_fail("Missing inventory icon for " + item_id)
			return

	var resource_nodes := get_nodes_in_group("interactable_resource")
	var action_types := {}
	for node: Node in resource_nodes:
		action_types[String(node.action_type)] = true
	for required_action: String in ["采集", "采石", "伐木"]:
		if not action_types.has(required_action):
			_fail("Missing world resource action: " + required_action)
			return

	var gather_node: Node2D = null
	for node: Node in resource_nodes:
		if String(node.action_type) == "采集":
			gather_node = node as Node2D
			break
	if gather_node == null:
		_fail("No gatherable food node was loaded")
		return
	var gather_item_id := String(gather_node.resource_id)
	var gather_before: int = scene.inventory.get_item_count(gather_item_id)
	player.global_position = gather_node.global_position
	scene._try_interact()
	if scene.inventory.get_item_count(gather_item_id) <= gather_before:
		_fail("Gathering did not add food to the backpack")
		return
	for action_name: String in ["采石", "伐木"]:
		var target: Node2D = null
		for node: Node in resource_nodes:
			if String(node.action_type) == action_name:
				target = node as Node2D
				break
		if target == null:
			_fail("No resource node for " + action_name)
			return
		var item_id := String(target.resource_id)
		var item_before: int = scene.inventory.get_item_count(item_id)
		player.global_position = target.global_position
		for _hit: int in range(target.hits_required):
			scene._try_interact()
		if scene.inventory.get_item_count(item_id) <= item_before:
			_fail(action_name + " did not add material to the backpack")
			return

	var boar = scene.get_node("World/DepthSorted/WildBoar")
	player.global_position = boar.global_position
	for _hit: int in range(boar.hits_required):
		scene._try_interact()
	if scene.inventory.get_item_count("meat_boar") == 0 or not boar.is_hunted:
		_fail("Hunting did not produce wild boar meat")
		return

	var underwater = scene.get_node_or_null("UnderwaterWorld")
	if underwater == null:
		_fail("Underwater map scene is missing")
		return
	var background := underwater.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture == null or background.texture.get_width() < 1200 or background.texture.get_height() < 700:
		_fail("Underwater map background is missing or too small")
		return
	if underwater.get_node_or_null("Collision/LeftWall") != null or underwater.get_node_or_null("Collision/RightWall") != null or underwater.get_node_or_null("Collision/Seabed") != null:
		_fail("Underwater map still has wall or seabed collisions")
		return
	var coast_entry := scene.get_node("World/GameplayMetadata/SouthCoastCave") as Marker2D
	player.global_position = coast_entry.global_position
	scene._try_interact()
	await physics_frame
	if not underwater.visible or not player.water_mode or player.get_parent() != underwater.get_node("DepthSorted"):
		_fail("South coast interaction did not enter swimming mode")
		return
	if not is_equal_approx(player.water_surface_y, underwater.WATER_SURFACE_Y):
		_fail("Swimming did not bind to the visible waterline")
		return
	player.global_position = Vector2(420.0, underwater.WATER_SURFACE_Y + 120.0)
	Input.action_press("ui_right")
	for _frame: int in range(3):
		await physics_frame
	Input.action_release("ui_right")
	if player.get_movement_state() != player.STATE_DIVE or player.oxygen >= player.max_oxygen:
		_fail("Diving did not activate underwater movement and oxygen use")
		return
	player.global_position = underwater.get_node("ExitMarker").global_position
	scene._try_interact()
	await physics_frame
	if underwater.visible or player.water_mode or player.get_parent() != scene.get_node("World/DepthSorted"):
		_fail("Underwater exit did not restore the land map")
		return

	print("SURVIVAL_GAMEPLAY_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
