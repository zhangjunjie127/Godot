extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await physics_frame

	var player: CharacterBody2D = scene.get_node("World/DepthSorted/Player")
	var grass: Area2D = scene.get_node("World/DepthSorted/EastGrass")
	var status: Label = scene.get_node("HUD/StatusTray/Margin/Row/ConcealmentLabel")
	var action: Label = scene.get_node("HUD/StatusTray/Margin/Row/ActionLabel")
	var health_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthBar")
	var health_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthLabel")
	var stamina_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaBar")
	var stamina_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaLabel")
	var player_status: PanelContainer = scene.get_node("HUD/PlayerStatus")
	var foundation: Node2D = scene.get_node("World/Foundation")
	var blockers: Node2D = scene.get_node("World/Collision")
	var depth_sorted: Node2D = scene.get_node("World/DepthSorted")
	var player_sprite: Sprite2D = player.get_node("Sprite2D")
	var wild_boar: CharacterBody2D = scene.get_node("World/DepthSorted/WildBoar")
	var boar_sprite: Sprite2D = wild_boar.get_node("Sprite2D")
	var day_night_cycle = scene.get_node("DayNightCycle")
	var era_label: Label = scene.get_node("HUD/WorldInfo/Margin/Row/Details/EraDayLabel")
	var time_label: Label = scene.get_node("HUD/WorldInfo/Margin/Row/TimeLabel")
	var phase_label: Label = scene.get_node("HUD/WorldInfo/Margin/Row/PhaseLabel")
	var minimap = scene.get_node("HUD/MinimapPanel/Margin/Minimap")
	var inventory_overlay: Control = scene.get_node("HUD/InventoryOverlay")
	var inventory_grid: GridContainer = scene.get_node("HUD/InventoryOverlay/InventoryPanel/Margin/Content/InventoryGrid")
	var skill_overlay: Control = scene.get_node("HUD/SkillOverlay")
	var skill_tree_row: HBoxContainer = scene.get_node("HUD/SkillOverlay/SkillPanel/Margin/Content/TreeRow")
	var day_night_tint: CanvasModulate = scene.get_node("World/DayNightTint")
	var camera: Camera2D = player.get_node("Camera2D")
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	if player.world_size != Vector2(2048.0, 2048.0):
		_fail("Expanded map did not load its 2048 world size")
		return
	if camera.zoom.x < 0.546:
		_fail("Camera zoom changed unexpectedly")
		return
	if foundation.get_child_count() != 4:
		_fail("Spawn foundation did not load four runtime chunks")
		return
	if blockers.get_child_count() < 2:
		_fail("Spawn map collision blockers did not load")
		return
	if health_label.text != "生命 100 / 100" or stamina_label.text != "体力 100 / 100":
		_fail("Player status HUD did not initialize")
		return
	if player_status.scale != Vector2.ONE or player_status.position != Vector2(8.0, 8.0):
		_fail("Player status HUD size or top-left placement changed")
		return
	if minimap.player != player or minimap.world_size != Vector2(2048.0, 2048.0):
		_fail("Minimap did not bind to the local player")
		return
	if scene.inventory.slots.size() != 20 or scene.inventory.get_item_count("stone_axe") != 1:
		_fail("Starter backpack did not initialize with 20 slots and a stone axe")
		return
	if inventory_grid.get_child_count() != 20:
		_fail("Backpack UI did not render all slots")
		return
	if skill_tree_row.get_child_count() != 11 or scene.skill_tree.skill_points != 5:
		_fail("Horizontal skill tree did not initialize")
		return
	if scene.get_node_or_null("World/DepthSorted/EastGrass") == null:
		_fail("Interactive vegetation did not load")
		return
	var vegetation_count := 0
	for child: Node in depth_sorted.get_children():
		if child.name.begins_with("Vegetation"):
			vegetation_count += 1
	if vegetation_count != 33:
		_fail("All 33 vegetation assets did not load")
		return
	if player_sprite.hframes != 4 or player_sprite.vframes != 4:
		_fail("Player four-direction animation sheet did not load")
		return
	if boar_sprite.hframes != 4 or boar_sprite.vframes != 4:
		_fail("Wild boar animation sheet did not load")
		return
	day_night_cycle.set_game_time(1, 6.0)
	day_night_cycle.advance_real_seconds(900.0)
	if not is_equal_approx(day_night_cycle.current_hour, 18.0) or day_night_cycle.current_phase != "黄昏":
		_fail("Fifteen-minute daytime duration is incorrect")
		return
	day_night_cycle.advance_real_seconds(300.0)
	if not is_equal_approx(day_night_cycle.current_hour, 21.0) or day_night_cycle.current_phase != "夜晚":
		_fail("Five-minute dusk duration is incorrect")
		return
	day_night_cycle.advance_real_seconds(600.0)
	if day_night_cycle.current_day != 2 or not is_equal_approx(day_night_cycle.current_hour, 6.0) or day_night_cycle.current_phase != "白天":
		_fail("Ten-minute night duration is incorrect")
		return

	day_night_cycle.set_game_time(2, 21.0)
	await process_frame
	if era_label.text != "原始时代 · 第 2 日" or time_label.text != "21:00" or phase_label.text != "夜晚":
		_fail("Day/night clock did not update the HUD")
		return
	if day_night_tint.color.r >= 0.7:
		_fail("Night environment tint did not darken the world")
		return
	day_night_cycle.set_game_time(1, 7.0)
	await process_frame

	var lake_query := PhysicsPointQueryParameters2D.new()
	lake_query.position = Vector2(600.0, 1600.0)
	lake_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(lake_query).is_empty():
		_fail("Lake collision did not block a deep-water point")
		return

	var ford_query := PhysicsPointQueryParameters2D.new()
	ford_query.position = Vector2(1040.0, 1210.0)
	ford_query.collision_mask = 2
	if not scene.get_world_2d().direct_space_state.intersect_point(ford_query).is_empty():
		_fail("Central river crossing was blocked")
		return

	var mountain_query := PhysicsPointQueryParameters2D.new()
	mountain_query.position = Vector2(500.0, 200.0)
	mountain_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(mountain_query).is_empty():
		_fail("Mountain collision did not block the ridge")
		return

	var crater_query := PhysicsPointQueryParameters2D.new()
	crater_query.position = Vector2(1460.0, 600.0)
	crater_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(crater_query).is_empty():
		_fail("Desert crater collision did not load")
		return

	player.global_position = grass.global_position
	for _frame: int in range(8):
		await physics_frame
		if status.text == "草丛隐蔽":
			break
	if status.text != "草丛隐蔽":
		push_error("Player did not enter concealment")
		quit(1)
		return
	if not player.visible:
		push_error("Local player must remain visible while concealed")
		quit(1)
		return

	player.set_local_player(false)
	if player.visible:
		push_error("Remote player must not render while concealed")
		quit(1)
		return
	player.set_local_player(true)

	player.global_position = Vector2(2000.0, 2000.0)
	for _frame: int in range(8):
		await physics_frame
		if status.text == "公开可见":
			break
	if status.text != "公开可见":
		push_error("Player did not leave concealment")
		quit(1)
		return

	Input.action_press("player_run")
	Input.action_press("ui_right")
	for _frame: int in range(8):
		await physics_frame
	if action.text != "奔跑":
		_fail("Run state did not activate")
		return
	if player_sprite.frame_coords.y != 1 or player_sprite.frame_coords.x == 0:
		_fail("Player right-facing run animation did not advance")
		return
	if stamina_bar.value >= stamina_bar.max_value:
		_fail("Running did not consume stamina")
		return
	Input.action_release("ui_right")
	Input.action_release("player_run")
	Input.action_press("ui_left")
	await physics_frame
	await physics_frame
	if player_sprite.frame_coords.y != 2:
		_fail("Player left-facing animation is reversed")
		return
	Input.action_release("ui_left")

	player.take_damage(25.0)
	await process_frame
	if not is_equal_approx(health_bar.value, 75.0) or health_label.text != "生命 75 / 100":
		_fail("Health HUD did not track player damage")
		return

	Input.action_press("player_crouch")
	await physics_frame
	await physics_frame
	if action.text != "蹲伏":
		_fail("Crouch state did not activate")
		return
	Input.action_release("player_crouch")

	Input.action_press("player_crawl")
	await physics_frame
	await physics_frame
	if action.text != "爬行":
		_fail("Crawl state did not activate")
		return
	Input.action_release("player_crawl")

	Input.action_press("player_jump")
	await physics_frame
	await physics_frame
	if action.text != "跳跃":
		_fail("Jump state did not activate")
		return
	Input.action_release("player_jump")

	if scene.inventory.add_item("plant_fiber", "植物纤维", 120, 99) != 120:
		_fail("Backpack could not stack items")
		return
	if scene.inventory.get_item_count("plant_fiber") != 120 or scene.inventory.remove_item("plant_fiber", 21) != 21:
		_fail("Backpack item counts are incorrect")
		return
	scene._toggle_inventory()
	if not inventory_overlay.visible or skill_overlay.visible:
		_fail("Backpack toggle did not open the correct panel")
		return
	scene._toggle_skill_tree()
	if inventory_overlay.visible or not skill_overlay.visible:
		_fail("Skill tree toggle did not open the correct panel")
		return

	for skill_id: String in ["survival", "gathering", "building", "hunting", "defense"]:
		if not scene.skill_tree.unlock_skill(skill_id):
			_fail("Skill chain could not unlock: " + skill_id)
			return
	if scene.skill_tree.skill_points != 0 or not scene.skill_tree.is_ritual_ready():
		_fail("Ritual did not activate after all skills were filled")
		return
	if not scene.skill_tree.unlock_skill("ascension_ritual") or scene.skill_tree.current_era != "青铜时代":
		_fail("Ritual did not evolve the player to the next era")
		return
	await process_frame
	if not era_label.text.begins_with("青铜时代"):
		_fail("Era evolution did not update the HUD")
		return

	print("SMOKE_OK: movement directions, 15/5/10 clock, HUD, minimap, backpack and era skill tree")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
