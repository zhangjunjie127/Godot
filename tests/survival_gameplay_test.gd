extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	if outer_alpha == null or not is_equal_approx(float(outer_alpha), 0.50):
		_fail("Night darkness is not 50 percent with a torch")
		return
	var torch_inner_alpha: Variant = night_vision.material.get_shader_parameter("torch_inner_alpha")
	if torch_inner_alpha == null or not is_equal_approx(float(torch_inner_alpha), 0.20):
		_fail("Torch-lit darkness is not 20 percent")
		return
	scene.inventory.remove_item("torch", 1)
	await process_frame
	outer_alpha = night_vision.material.get_shader_parameter("outer_alpha")
	if outer_alpha == null or not is_equal_approx(float(outer_alpha), 0.50):
		_fail("Night darkness changed when the torch was removed")
		return

	var clouds := scene.get_node_or_null("World/Clouds")
	if clouds == null or not (clouds is Node2D):
		_fail("Clouds are not world-space Node2D scenery")
		return
	clouds.set_weather("晴朗")
	var cloud_before: Vector2 = clouds.get_cloud_world_position(0)
	player.global_position += Vector2(260.0, 120.0)
	if not clouds.is_processing():
		_fail("Clouds are not processing independently")
		return
	clouds.process_mode = Node.PROCESS_MODE_DISABLED
	clouds.advance_clouds(1.0)
	var cloud_after: Vector2 = clouds.get_cloud_world_position(0)
	if absf(cloud_after.y - cloud_before.y) > 8.0:
		_fail("Clouds followed the player or camera")
		return
	var cloud_distance := cloud_before.x - cloud_after.x
	var expected_cloud_distance := float(clouds.clouds[0]["speed"])
	if not is_equal_approx(cloud_distance, expected_cloud_distance):
		_fail("Cloud movement did not match its independent speed")
		return
	var cloud_speeds: Array[float] = []
	for cloud: Dictionary in clouds.clouds:
		cloud_speeds.append(float(cloud["speed"]))
	if cloud_speeds.min() < 26.0 or cloud_speeds.max() > 34.0 or cloud_speeds.max() - cloud_speeds.min() < 1.0:
		_fail("Clouds do not have close but visibly independent speeds")
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
	if not boar.scale.is_equal_approx(Vector2(3.0, 3.0)) or not boar.get_node("Sprite2D").scale.is_equal_approx(Vector2(0.36, 0.36)):
		_fail("The wild boar is not three times its original authored size")
		return
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
	var land_collision := scene.get_node_or_null("World/Collision")
	var ocean_polygon := scene.get_node_or_null("World/Collision/OceanEast/Polygon") as CollisionPolygon2D
	if land_collision == null or land_collision.get_child_count() < 10 or ocean_polygon == null:
		_fail("Editable land collision scene was not loaded")
		return
	if not scene.get_node("World").is_water_position(Vector2(8050.0, 3900.0)):
		_fail("Surface swimming no longer follows the editable water collision polygon")
		return
	if scene.get_node_or_null("WaterTransition") != null:
		_fail("The obsolete automatic water-entry transition still exists")
		return
	var background := underwater.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture == null or background.texture.get_width() < 1200 or background.texture.get_height() < 700:
		_fail("Underwater map background is missing or too small")
		return
	if underwater.get_node_or_null("Collision/LeftWall") != null or underwater.get_node_or_null("Collision/RightWall") != null or underwater.get_node_or_null("Collision/Seabed") != null:
		_fail("Underwater map still has wall or seabed collisions")
		return
	for _frame: int in range(50):
		await physics_frame
	player.global_position = Vector2(4100.0, 4700.0)
	Input.action_press("player_jump")
	for _frame: int in range(10):
		await physics_frame
	Input.action_release("player_jump")
	if player.get_movement_state() != player.STATE_JUMP or player.get("surface_swimming") == true or player.water_mode:
		_fail("Space on land did not remain a normal jump: state=%s surface=%s underwater=%s" % [player.get_movement_state(), player.get("surface_swimming") == true, player.water_mode])
		return
	for _frame: int in range(40):
		await physics_frame
	player.global_position = Vector2(6200.0, 3000.0)
	Input.action_press("ui_right")
	for _frame: int in range(420):
		await physics_frame
		if player.get("surface_swimming") == true:
			break
	Input.action_release("ui_right")
	if player.get("surface_swimming") != true:
		_fail("Walking into water did not enter surface swimming mode")
		return
	if underwater.visible or player.water_mode or player.get_parent() != scene.get_node("World/DepthSorted"):
		_fail("Walking into water incorrectly switched to the underwater map")
		return
	if player.get_movement_state() != player.STATE_SWIM or not is_equal_approx(player.oxygen, player.max_oxygen):
		_fail("Surface swimming did not use swimming movement without oxygen drain")
		return
	var surface_swim_before: Vector2 = player.global_position
	Input.action_press("ui_right")
	for _frame: int in range(30):
		await physics_frame
	Input.action_release("ui_right")
	if player.global_position.x - surface_swim_before.x < 15.0 or player.get("surface_swimming") != true:
		_fail("The player could not swim freely on the water surface")
		return
	if player.sprite.texture != load("res://assets/characters/player_male_swim/sheet-transparent.png"):
		_fail("Surface swimming did not use the dedicated swimming animation")
		return
	Input.action_press("player_jump")
	await physics_frame
	Input.action_release("player_jump")
	await physics_frame
	if not underwater.visible or not player.water_mode or player.get_parent() != underwater.get_node("DepthSorted"):
		_fail("Space while surface swimming did not dive to the underwater map")
		return
	if player.get("surface_swimming") == true:
		_fail("Surface swimming remained active after diving underwater")
		return
	if not is_equal_approx(player.water_surface_y, underwater.WATER_SURFACE_Y):
		_fail("Diving did not bind to the underwater waterline")
		return
	if underwater.get_node("DepthSorted").modulate.is_equal_approx(Color.WHITE):
		_fail("Underwater actors are not affected by the water color")
		return
	var underwater_fish := get_nodes_in_group("underwater_fish")
	if underwater_fish.size() < 3:
		_fail("Three animated underwater fish species were not loaded")
		return
	for candidate: Node in get_nodes_in_group("interactable_resource"):
		if underwater.is_ancestor_of(candidate):
			_fail("Underwater food resource props were not removed")
			return
	player.global_position = Vector2(420.0, underwater.WATER_SURFACE_Y + 120.0)
	var swim_before: Vector2 = player.global_position
	Input.action_press("ui_right")
	for _frame: int in range(30):
		await physics_frame
	Input.action_release("ui_right")
	if player.global_position.x - swim_before.x < 15.0:
		_fail("The player did not move underwater")
		return
	if player.get_movement_state() != player.STATE_DIVE or player.oxygen >= player.max_oxygen:
		_fail("Diving did not activate underwater movement and oxygen use")
		return
	if player.sprite.texture != load("res://assets/characters/player_male_swim/sheet-transparent.png"):
		_fail("The dedicated swimming animation was not used")
		return
	var bubble_effect := underwater.get_node_or_null("DepthSorted/BubbleEffect")
	if bubble_effect == null or bubble_effect.get_bubble_count() == 0:
		_fail("Swimming did not create a bubble trail")
		return
	player.global_position = Vector2(underwater.MAP_SIZE.x - 4.0, underwater.WATER_SURFACE_Y + 120.0)
	Input.action_press("ui_right")
	for _frame: int in range(12):
		await physics_frame
	Input.action_release("ui_right")
	if player.global_position.x <= underwater.MAP_SIZE.x:
		_fail("The removed underwater right boundary still blocks movement")
		return
	player.global_position = Vector2(420.0, underwater.MAP_SIZE.y - 4.0)
	Input.action_press("ui_down")
	for _frame: int in range(12):
		await physics_frame
	Input.action_release("ui_down")
	if player.global_position.y <= underwater.MAP_SIZE.y:
		_fail("The removed underwater seabed boundary still blocks movement")
		return
	player.global_position = underwater.get_node("ExitMarker").global_position
	scene._try_interact()
	await physics_frame
	if underwater.visible or player.water_mode or player.get_parent() != scene.get_node("World/DepthSorted") or player.get("surface_swimming") != true:
		_fail("Underwater exit did not restore surface swimming")
		return

	scene.enter_underwater()
	player.global_position = Vector2(420.0, underwater.WATER_SURFACE_Y + 120.0)
	player.set_health(1.0)
	player.set_oxygen(0.0)
	for _frame: int in range(30):
		await physics_frame
	var death_overlay := scene.get("death_overlay") as Control
	if not bool(player.get("is_dead")) or player.health > 0.0 or death_overlay == null or not death_overlay.visible:
		_fail("Zero oxygen and zero health did not produce player death")
		return

	print("SURVIVAL_GAMEPLAY_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
