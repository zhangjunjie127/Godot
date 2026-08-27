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
	var health_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthBar")
	var health_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthLabel")
	var stamina_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaBar")
	var stamina_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaLabel")
	var hunger_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HungerGroup/HungerBar")
	var hunger_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HungerGroup/HungerLabel")
	var portrait_frame: PanelContainer = scene.get_node("HUD/PlayerStatus/Margin/Content/PortraitFrame")
	var health_group: Control = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup")
	var stamina_group: Control = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup")
	var hunger_group: Control = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HungerGroup")
	var condition_icon: TextureRect = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/ConditionIcon")
	var action_icon: TextureRect = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/ActionIcon")
	var visibility_icon: TextureRect = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/VisibilityIcon")
	var phase_icon: TextureRect = scene.get_node("HUD/PhasePanel/Margin/PhaseIcon")
	var player_status: PanelContainer = scene.get_node("HUD/PlayerStatus")
	var foundation: Node2D = scene.get_node("World/Foundation")
	var blockers: Node2D = scene.get_node("World/Collision")
	var depth_sorted: Node2D = scene.get_node("World/DepthSorted")
	var player_sprite: Sprite2D = player.get_node("Sprite2D")
	var wild_boar: CharacterBody2D = scene.get_node("World/DepthSorted/WildBoar")
	var boar_sprite: Sprite2D = wild_boar.get_node("Sprite2D")
	var day_night_cycle = scene.get_node("DayNightCycle")
	var weather = scene.get_node("Weather/Effect")
	var wetness_overlay: ColorRect = scene.get_node("Weather/Wetness")
	var weather_ground = scene.get_node("World/WeatherGround")
	var screen_rain = scene.get_node("ScreenWeather/Drops")
	var era_label: Label = scene.get_node("HUD/WorldInfo/Margin/Row/Details/EraDayLabel")
	var minimap = scene.get_node("HUD/MinimapPanel/Margin/Minimap")
	var inventory_overlay: Control = scene.get_node("HUD/InventoryOverlay")
	var inventory_grid: GridContainer = scene.get_node("HUD/InventoryOverlay/InventoryPanel/Margin/Content/InventoryGrid")
	var skill_overlay: Control = scene.get_node("HUD/SkillOverlay")
	var skill_branches: VBoxContainer = scene.get_node("HUD/SkillOverlay/SkillPanel/Margin/Content/Branches")
	var ritual_row: HBoxContainer = scene.get_node("HUD/SkillOverlay/SkillPanel/Margin/Content/RitualRow")
	var day_night_tint: CanvasModulate = scene.get_node("World/DayNightTint")
	var camera: Camera2D = player.get_node("Camera2D")
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	weather.process_mode = Node.PROCESS_MODE_DISABLED
	screen_rain.process_mode = Node.PROCESS_MODE_DISABLED
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
	if health_label.text != "生命 100 / 100" or stamina_label.text != "体力 100 / 100" or hunger_label.text != "饥饿 100 / 100":
		_fail("Player status HUD did not initialize")
		return
	if health_group.size.y != 12.0 or stamina_group.size.y != 12.0 or hunger_group.size.y != 12.0:
		_fail("Health, stamina or hunger bars were not narrowed")
		return
	var meter_stack_height := hunger_group.position.y + hunger_group.size.y - health_group.position.y
	if meter_stack_height != portrait_frame.size.y or meter_stack_height != 42.0:
		_fail("Three meter bars do not match the portrait height")
		return
	if scene.get_node_or_null("HUD/WorldInfo/Margin/Row/TimeLabel") != null or scene.get_node_or_null("HUD/WorldInfo/Margin/Row/PhaseLabel") != null:
		_fail("Time or phase text was not removed from the HUD")
		return
	if player_status.scale != Vector2(0.5, 0.5) or player_status.position != Vector2(8.0, 8.0):
		_fail("Player status HUD size or top-left placement changed")
		return
	for path: NodePath in [
		"HUD/PlayerStatus",
		"HUD/WorldInfo",
		"HUD/PhasePanel",
		"HUD/MinimapPanel",
		"HUD/BottomActions",
		"HUD/InventoryOverlay/InventoryPanel",
		"HUD/SkillOverlay/SkillPanel",
	]:
		var control: Control = scene.get_node(path)
		if control.scale != Vector2(0.5, 0.5):
			_fail("UI root was not scaled to 50%: " + String(path))
			return
	if not _icon_is_ready(action_icon, "站立") or not _icon_is_ready(condition_icon, "开心") or not _icon_is_ready(visibility_icon, "公开可见"):
		_fail("Player HUD status icons did not initialize")
		return
	if action_icon.custom_minimum_size != Vector2(32.0, 32.0) or condition_icon.custom_minimum_size != Vector2(32.0, 32.0) or visibility_icon.custom_minimum_size != Vector2(32.0, 32.0):
		_fail("Player status icons were not enlarged")
		return
	if phase_icon.custom_minimum_size != Vector2(32.0, 32.0):
		_fail("Day phase icon was not enlarged inside its fixed panel")
		return
	if (action_icon.texture as AtlasTexture).region.size != Vector2(48.0, 48.0) or (phase_icon.texture as AtlasTexture).region.size != Vector2(40.0, 40.0):
		_fail("Transparent icon padding was not cropped for readability")
		return
	if weather.current_weather != "下雨":
		_fail("Rain weather did not initialize")
		return
	weather.advance_visual_seconds(1.0)
	if weather.visual_rain_density <= 0.0 or weather.visual_rain_density >= 0.60:
		_fail("Rain did not fade in gradually")
		return
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if not wetness_overlay.visible or not weather_ground.raining or weather_ground._puddles.size() != 20:
		_fail("Rain did not enable wet terrain and puddles")
		return
	if weather.current_rain_level != "中雨" or weather.get_active_rain_particle_count() != 90:
		_fail("Medium rain density did not initialize")
		return
	weather.set_rain_level("小雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var light_rain_count: int = weather.get_active_rain_particle_count()
	weather.set_rain_level("中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var medium_rain_count: int = weather.get_active_rain_particle_count()
	weather.set_rain_level("大雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var heavy_rain_count: int = weather.get_active_rain_particle_count()
	if not (light_rain_count < medium_rain_count and medium_rain_count < heavy_rain_count and heavy_rain_count == 150):
		_fail("Light, medium and heavy rain densities are not distinct")
		return
	screen_rain.advance_effects(1.0)
	if screen_rain._drops.is_empty():
		_fail("Heavy rain did not create droplets on the screen")
		return
	weather.start_weather_event("晴朗", "半天")
	weather.advance_visual_seconds(1.0)
	if weather.visual_rain_density <= 0.0 or not wetness_overlay.visible:
		_fail("Rain stopped abruptly instead of fading out")
		return
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if weather.visual_rain_density != 0.0 or wetness_overlay.visible or weather_ground.raining:
		_fail("Rain fade-out did not finish cleanly")
		return
	screen_rain.advance_effects(0.2)
	if screen_rain._drops.is_empty():
		_fail("Screen droplets vanished abruptly when rain ended")
		return
	screen_rain.advance_effects(6.0)
	if not screen_rain._drops.is_empty():
		_fail("Screen droplets did not fade away")
		return
	weather.start_weather_event("下雨", "半天", "中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	weather_ground.advance_effects(2.0)
	var initial_impact_count: int = weather_ground._impacts.size()
	weather_ground.spawn_impact(player.global_position)
	if weather_ground._impacts.size() != initial_impact_count + 1:
		_fail("Rain impact did not create a splash and ripple")
		return
	weather_ground.advance_effects(1.0)
	if not weather_ground._impacts.is_empty():
		_fail("Rain ripple did not expire cleanly")
		return
	weather.start_weather_event("下雨", "半天", "中雨")
	if weather.current_duration_mode != "半天" or weather.remaining_game_minutes != 720:
		_fail("Half-day rain duration is incorrect")
		return
	weather.advance_game_minutes(719)
	if weather.current_weather != "下雨":
		_fail("Half-day rain ended early")
		return
	weather.advance_game_minutes(1)
	if weather.current_weather != "晴朗":
		_fail("Half-day rain did not end after 720 game minutes")
		return
	weather.start_weather_event("下雪", "一天")
	if weather.current_duration_mode != "一天" or weather.remaining_game_minutes != 1440:
		_fail("Full-day snow duration is incorrect")
		return
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if wetness_overlay.visible or weather_ground.raining:
		_fail("Rain wetness remained active during snow")
		return
	weather.advance_game_minutes(1439)
	if weather.current_weather != "下雪":
		_fail("Full-day snow ended early")
		return
	weather.advance_game_minutes(1)
	if weather.current_weather != "晴朗":
		_fail("Full-day snow did not end after 1440 game minutes")
		return
	for _sample: int in range(40):
		weather.trigger_special_weather("下雨")
		if weather.event_duration_days < 3 or weather.event_duration_days > 10:
			_fail("Special weather duration escaped the 3-10 day range")
			return
	weather.start_weather_event("下雨", "半天", "中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if not wetness_overlay.visible or not weather_ground.raining:
		_fail("Rain wetness did not reactivate")
		return
	weather_ground.advance_effects(2.0)
	var impact_particle: Dictionary = weather._rain_particles[0]
	impact_particle["position"] = Vector2(320.0, 100.0)
	impact_particle["velocity"] = Vector2(-60.0, 400.0)
	impact_particle["impact_y"] = 102.0
	impact_particle["splash"] = true
	weather.advance_visual_seconds(0.01)
	if weather_ground._impacts.is_empty():
		_fail("Falling rain did not trigger a ground splash")
		return
	var rain_speeds: Dictionary = {}
	var rain_lengths: Dictionary = {}
	var maximum_rain_length := 0.0
	var maximum_rain_width := 0.0
	for particle: Dictionary in weather._rain_particles:
		var velocity: Vector2 = particle["velocity"]
		if velocity.x >= 0.0 or velocity.y <= 0.0:
			_fail("Rain motion does not follow the visible streak direction")
			return
		rain_speeds[roundi(velocity.length())] = true
		rain_lengths[roundi(float(particle["length"]))] = true
		maximum_rain_length = maxf(maximum_rain_length, float(particle["length"]))
		maximum_rain_width = maxf(maximum_rain_width, float(particle["width"]))
	if rain_speeds.size() < 6 or rain_lengths.size() < 5:
		_fail("Rain particles still look mechanically uniform")
		return
	if maximum_rain_length > 12.0 or maximum_rain_width > 0.9:
		_fail("Falling rain streaks are still too large")
		return
	var sampled_rain_motion := false
	for particle: Dictionary in weather._rain_particles:
		var before: Vector2 = particle["position"]
		if before.x <= 10.0 or before.y >= 300.0:
			continue
		var velocity: Vector2 = particle["velocity"]
		weather.advance_visual_seconds(0.01)
		var actual_motion: Vector2 = (particle["position"] as Vector2) - before
		if actual_motion.distance_to(velocity * 0.01) > 0.01:
			_fail("Rain particle movement jumped or opposed its streak")
			return
		sampled_rain_motion = true
		break
	if not sampled_rain_motion:
		_fail("Rain motion regression sample was unavailable")
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
	if skill_branches.get_child_count() != 3 or ritual_row.get_child_count() != 1 or scene.skill_tree.skill_points != 12:
		_fail("Three-branch skill tree did not initialize")
		return
	for branch_row: HBoxContainer in skill_branches.get_children():
		if branch_row.get_child_count() != 8:
			_fail("Skill branch did not render four illuminated nodes")
			return
	if scene.skill_tree.get_total_skill_count() != 12:
		_fail("Skill tree does not contain 12 branch skills")
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
	if weather.current_weather != "晴朗":
		_fail("Half-day weather did not follow the game calendar")
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
	if era_label.text != "原始时代 · 第 2 日":
		_fail("Day/night clock did not update the HUD")
		return
	if not _icon_is_ready(phase_icon, "夜晚"):
		_fail("Night icon did not update beside the minimap")
		return
	if day_night_tint.color.r >= 0.7:
		_fail("Night environment tint did not darken the world")
		return
	day_night_cycle.set_game_time(1, 7.0)
	await process_frame
	if not _icon_is_ready(phase_icon, "白天"):
		_fail("Day icon did not update beside the minimap")
		return
	day_night_cycle.set_game_time(1, 19.0)
	await process_frame
	if not _icon_is_ready(phase_icon, "黄昏"):
		_fail("Dusk icon did not update beside the minimap")
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
		if visibility_icon.tooltip_text == "草丛隐蔽":
			break
	if not _icon_is_ready(visibility_icon, "草丛隐蔽"):
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
		if visibility_icon.tooltip_text == "公开可见":
			break
	if not _icon_is_ready(visibility_icon, "公开可见"):
		push_error("Player did not leave concealment")
		quit(1)
		return

	Input.action_press("player_run")
	Input.action_press("ui_right")
	for _frame: int in range(8):
		await physics_frame
	if not _icon_is_ready(action_icon, "奔跑"):
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

	player.set_health(60.0)
	await process_frame
	if not is_equal_approx(health_bar.value, 60.0) or health_label.text != "生命 60 / 100" or not _icon_is_ready(condition_icon, "不开心"):
		_fail("Health HUD did not track player damage")
		return
	player.set_health(30.0)
	await process_frame
	if not _icon_is_ready(condition_icon, "生病"):
		_fail("Sick health state did not activate")
		return
	player.set_health(10.0)
	await process_frame
	if not _icon_is_ready(condition_icon, "濒死"):
		_fail("Dying health state did not activate")
		return
	player.set_health(100.0)
	await process_frame
	if not _icon_is_ready(condition_icon, "开心"):
		_fail("Happy health state did not recover")
		return

	player.set_hunger(50.0)
	var hunger_fill := hunger_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if not is_equal_approx(hunger_bar.value, 50.0) or hunger_label.text != "饥饿 50 / 100" or hunger_fill.bg_color.r <= hunger_fill.bg_color.g:
		_fail("Hunger meter did not reach its yellow midpoint")
		return
	player.set_hunger(10.0)
	hunger_fill = hunger_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if hunger_fill.bg_color.r <= hunger_fill.bg_color.g * 2.0:
		_fail("Low hunger did not turn the meter red")
		return
	player.set_hunger(100.0)

	Input.action_press("player_crouch")
	await physics_frame
	await physics_frame
	if not _icon_is_ready(action_icon, "蹲伏"):
		_fail("Crouch state did not activate")
		return
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_crouch/sheet-transparent.png":
		_fail("Crouch state did not use its animation sheet")
		return
	if player_sprite.scale != Vector2(0.44, 0.44):
		_fail("Crouch animation fell back to sprite squashing")
		return
	Input.action_release("player_crouch")

	Input.action_press("player_crawl")
	for _frame: int in range(18):
		await physics_frame
	if not _icon_is_ready(action_icon, "趴下"):
		_fail("Prone state did not activate")
		return
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_prone_idle/sheet-transparent.png":
		_fail("Stationary prone state did not use its idle animation")
		return
	if player_sprite.frame_coords.x == 0:
		_fail("Prone idle animation did not advance")
		return
	Input.action_press("ui_right")
	for _frame: int in range(12):
		await physics_frame
	if not _icon_is_ready(action_icon, "爬行"):
		_fail("Prone movement did not enter the crawl state")
		return
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_crawl/sheet-transparent.png":
		_fail("Moving prone state did not use its crawl animation")
		return
	if player_sprite.frame_coords.x == 0:
		_fail("Crawl animation did not advance")
		return
	Input.action_release("ui_right")
	Input.action_release("player_crawl")

	Input.action_press("player_jump")
	for _frame: int in range(10):
		await physics_frame
	if not _icon_is_ready(action_icon, "跳跃"):
		_fail("Jump state did not activate")
		return
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_jump/sheet-transparent.png":
		_fail("Jump state did not use its animation sheet")
		return
	if player_sprite.frame_coords.x == 0:
		_fail("Jump animation did not advance")
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

	for branch: Dictionary in scene.skill_tree.BRANCHES:
		for skill: Dictionary in branch["skills"]:
			var skill_id := String(skill["id"])
			if not scene.skill_tree.unlock_skill(skill_id):
				_fail("Skill branch could not unlock: " + skill_id)
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

	print("SMOKE_OK: light/medium/heavy rain, smooth fades, screen droplets, weather durations, hunger and HUD")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _icon_is_ready(icon: TextureRect, tooltip: String) -> bool:
	return icon.texture is AtlasTexture and icon.tooltip_text == tooltip
