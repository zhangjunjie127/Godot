extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var menu_scene := (load("res://start_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu_scene)
	await process_frame
	if menu_scene.get_node("TitleBlock/Title").text != "我要上天" or menu_scene.get_node("TitleBlock/Subtitle").text != "ASCENSION" or not menu_scene.get_node("StartButton").visible:
		_fail("Title screen or Start Game button did not initialize")
		return
	if menu_scene.get_node_or_null("GenderPanel") != null:
		_fail("The removed gender selection panel is still present")
		return
	menu_scene.queue_free()
	await process_frame
	var rain_demo_scene := load("res://effects/rain/RainDemo.tscn") as PackedScene
	if rain_demo_scene == null:
		_fail("RainDemo scene did not load")
		return
	var rain_demo := rain_demo_scene.instantiate()
	root.add_child(rain_demo)
	await process_frame
	if not rain_demo.get_node("Weather/RainVisuals/FarStreaks").process_material is ParticleProcessMaterial or not rain_demo.get_node("GroundEffects").has_method("get_ripple_spawn_rate"):
		_fail("RainDemo did not initialize GPU streaks and graded ground feedback")
		return
	rain_demo.free()
	await process_frame
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
	var rain_visual = scene.get_node("Weather/RainVisuals")
	var far_rain: GPUParticles2D = rain_visual.get_node("FarStreaks")
	var near_rain: GPUParticles2D = rain_visual.get_node("NearStreaks")
	var puddle_surface: Sprite2D = scene.get_node("World/RainPuddleSurface")
	var weather_ground = scene.get_node("World/WeatherGround")
	var snow_world = scene.get_node("World/SnowWorld")
	var screen_rain = scene.get_node("ScreenWeather/Drops")
	var cloud_layer = scene.get_node("World/Clouds")
	var night_vision = scene.get_node("NightVision/Mask")
	var era_label: Label = scene.get_node("HUD/WorldInfo/Margin/Row/Details/EraDayLabel")
	var world_info: PanelContainer = scene.get_node("HUD/WorldInfo")
	var minimap = scene.get_node("HUD/MinimapPanel/Margin/Minimap")
	var map_name_label: Label = scene.get_node("HUD/MinimapPanel/Margin/Minimap/AreaLabel")
	var minimap_coordinate_label: Label = scene.get_node("HUD/MinimapPanel/Margin/Minimap/CoordinateLabel")
	var minimap_panel: PanelContainer = scene.get_node("HUD/MinimapPanel")
	var forecast_popup: PanelContainer = scene.get_node("HUD/ForecastPopup")
	var forecast_label: Label = scene.get_node("HUD/ForecastPopup/Margin/ForecastLabel")
	var inventory_overlay: Control = scene.get_node("HUD/InventoryOverlay")
	var inventory_grid: GridContainer = scene.get_node("HUD/InventoryOverlay/InventoryPanel/Margin/Content/InventoryGrid")
	var skill_overlay: Control = scene.get_node("HUD/SkillOverlay")
	var skill_branches: VBoxContainer = scene.get_node("HUD/SkillOverlay/SkillPanel/Margin/Content/TreeRow/Branches")
	var ritual_row: HBoxContainer = scene.get_node("HUD/SkillOverlay/SkillPanel/Margin/Content/TreeRow/RitualRow")
	var world_map_overlay: Control = scene.get_node("HUD/WorldMapOverlay")
	var world_map = scene.get_node("HUD/WorldMapOverlay/MapPanel/Margin/Content/Map")
	var day_night_tint: CanvasModulate = scene.get_node("World/DayNightTint")
	var camera: Camera2D = player.get_node("Camera2D")
	day_night_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	weather.process_mode = Node.PROCESS_MODE_DISABLED
	screen_rain.process_mode = Node.PROCESS_MODE_DISABLED
	cloud_layer.process_mode = Node.PROCESS_MODE_DISABLED
	if player.world_size != Vector2(8192.0, 8192.0):
		_fail("Replacement map did not load its 8192 world size")
		return
	if player.move_speed != 85.0 or player.run_speed != 140.0 or player.crouch_speed != 41.0 or player.crawl_speed != 23.0:
		_fail("Player movement speeds were not reduced by 50 percent")
		return
	if not is_equal_approx(camera.zoom.x, 0.273):
		_fail("Camera was not pulled back by 50 percent")
		return
	var initial_chunk_count: int = scene.get_node("World").get_loaded_chunk_count()
	if foundation.get_child_count() != initial_chunk_count or initial_chunk_count < 4 or initial_chunk_count > 12:
		_fail("Spawn foundation did not stream the camera-visible chunk range: nodes=%d loaded=%d" % [foundation.get_child_count(), initial_chunk_count])
		return
	for chunk: Sprite2D in foundation.get_children():
		var water_surface := chunk.get_node_or_null("WaterSurface") as Sprite2D
		if water_surface == null or water_surface.texture != chunk.texture or not water_surface.material is ShaderMaterial:
			_fail("A streamed map chunk is missing its editable water surface overlay: " + chunk.name)
			return
		var water_material := water_surface.material as ShaderMaterial
		var water_mask := water_material.get_shader_parameter("water_mask") as Texture2D
		if water_mask == null or water_mask.get_size() != chunk.texture.get_size():
			_fail("A water mask does not match its map chunk dimensions: " + chunk.name)
			return
		if water_material.get_shader_parameter("chunk_world_origin") != chunk.position:
			_fail("Water motion is not aligned to map world coordinates: " + chunk.name)
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
		"HUD/ForecastPopup",
		"HUD/WorldMapOverlay/MapPanel",
	]:
		var control: Control = scene.get_node(path)
		if control.scale != Vector2(0.5, 0.5):
			_fail("UI root was not scaled to 50%: " + String(path))
			return
	var minimap_visible_bottom := minimap_panel.global_position.y + minimap_panel.size.y * minimap_panel.get_global_transform().get_scale().y
	if not is_equal_approx(world_info.global_position.y, minimap_visible_bottom):
		_fail("Era and day panel is not tight against the minimap border")
		return
	if map_name_label.text != "升天群岛" or map_name_label.get_parent() != minimap:
		_fail("Tropical island map name was not placed inside the minimap")
		return
	var original_player_position: Vector2 = player.global_position
	player.global_position = Vector2(1200.0, 1300.0)
	scene.get_node("World")._process(0.0)
	var corner_chunk_count: int = scene.get_node("World").get_loaded_chunk_count()
	if corner_chunk_count < 1 or corner_chunk_count > initial_chunk_count:
		_fail("Map chunk streaming did not release distant chunks at the northwest corner: %d" % corner_chunk_count)
		return
	scene._process(0.0)
	if minimap_coordinate_label.text != "1200,1300" or minimap_coordinate_label.get_parent() != minimap or minimap_coordinate_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT:
		_fail("Player coordinates are not updating at the minimap bottom-right")
		return
	player.global_position = original_player_position
	scene.get_node("World")._process(0.0)
	scene._process(0.0)
	if not forecast_popup.visible or not forecast_label.text.contains("未来 1 日") or weather.get_forecast(2).size() != 2:
		_fail("Two-day scheduled weather forecast did not initialize")
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
	if not wetness_overlay.visible or not puddle_surface.visible or not weather_ground.raining:
		_fail("Layered rain did not enable wet grading, puddles and ground effects")
		return
	if not is_equal_approx(rain_visual.intensity, weather.visual_rain_density) or rain_visual.get_layer_particle_counts() != Vector2i(360, 160):
		_fail("Rain streak layer did not follow the authoritative weather intensity")
		return
	if rain_visual._rain_loop == null or rain_visual._rain_loop.stream == null or rain_visual.get_audio_volume_db() <= -80.0:
		_fail("Rain audio loop did not initialize with the layered effect")
		return
	var audio_players := scene.find_children("*", "AudioStreamPlayer", true, false)
	var thunder_audio := scene.get_node("Weather/Thunder") as AudioStreamPlayer
	var day_birds_audio := scene.get_node("Weather/DayBirds") as AudioStreamPlayer
	var day_wind_audio := scene.get_node("Weather/DayWind") as AudioStreamPlayer
	if audio_players.size() != 4 or rain_visual._rain_loop not in audio_players or thunder_audio not in audio_players or day_birds_audio not in audio_players or day_wind_audio not in audio_players:
		_fail("Weather audio must contain only rain, thunder, daytime birds and daytime wind")
		return
	if wetness_overlay.material.get_shader_parameter("rain_intensity") <= 0.0 or puddle_surface.material.get_shader_parameter("rain_intensity") <= 0.0 or puddle_surface.material.get_shader_parameter("puddle_amount") <= 0.0:
		_fail("Wet grade or puddle refraction shader did not receive rain intensity")
		return
	if puddle_surface.material.get_shader_parameter("puddle_mask") != puddle_surface.texture or puddle_surface.material.get_shader_parameter("ripple_flow") == null:
		_fail("Puddle refraction does not share the authored mask and G/B ripple field")
		return
	var ripple_flow_texture := puddle_surface.material.get_shader_parameter("ripple_flow") as Texture2D
	var ripple_flow_image := ripple_flow_texture.get_image()
	var ripple_channel_difference := 0.0
	for sample_y: int in range(1, 8):
		for sample_x: int in range(1, 8):
			var ripple_sample := ripple_flow_image.get_pixel(ripple_flow_image.get_width() * sample_x / 8, ripple_flow_image.get_height() * sample_y / 8)
			ripple_channel_difference += absf(ripple_sample.g - ripple_sample.b)
	if ripple_channel_difference < 0.1:
		_fail("Puddle ripple field does not contain independent G/B motion channels")
		return
	var small_cutoff: Variant = puddle_surface.material.get_shader_parameter("small_cutoff")
	var medium_cutoff: Variant = puddle_surface.material.get_shader_parameter("medium_cutoff")
	var heavy_cutoff: Variant = puddle_surface.material.get_shader_parameter("heavy_cutoff")
	var medium_spread: Variant = puddle_surface.material.get_shader_parameter("medium_spread_pixels")
	var heavy_spread: Variant = puddle_surface.material.get_shader_parameter("heavy_spread_pixels")
	var edge_feather: Variant = puddle_surface.material.get_shader_parameter("edge_feather_pixels")
	var water_opacity: Variant = puddle_surface.material.get_shader_parameter("water_opacity")
	if small_cutoff == null or medium_cutoff == null or heavy_cutoff == null or medium_spread == null or heavy_spread == null or edge_feather == null or water_opacity == null or float(small_cutoff) <= float(medium_cutoff) or not is_equal_approx(float(medium_spread), 3.0) or not is_equal_approx(float(heavy_spread), 4.0) or float(edge_feather) <= 0.0 or float(water_opacity) < 0.40:
		_fail("Medium and heavy puddle coverage were not doubled")
		return
	if weather.current_rain_level != "中雨" or weather.get_active_rain_particle_count() != 255:
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
	if not (light_rain_count < medium_rain_count and medium_rain_count < heavy_rain_count and heavy_rain_count == 520):
		_fail("Light, medium and heavy rain densities are not distinct")
		return
	weather.start_weather_event("晴朗", "半天")
	weather.advance_visual_seconds(weather.rain_fade_seconds + weather.puddle_drain_seconds)
	weather.start_weather_event("下雨", "半天", "小雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var light_impact_rate: float = weather_ground.get_impact_spawn_rate()
	if puddle_surface.visible or weather.get_puddle_amount() != 0.0 or light_impact_rate <= 0.0 or weather_ground.get_ripple_spawn_rate() != 0.0:
		_fail("Light rain should create splashes without puddles or ripples")
		return
	weather.set_rain_level("中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var medium_impact_rate: float = weather_ground.get_impact_spawn_rate()
	var medium_ripple_rate: float = weather_ground.get_ripple_spawn_rate()
	var medium_puddle_amount: float = weather.get_puddle_amount()
	if not puddle_surface.visible or medium_puddle_amount <= 0.0 or medium_impact_rate <= light_impact_rate or medium_ripple_rate <= 0.0:
		_fail("Medium rain should add limited puddles, splashes and ripples")
		return
	weather.set_rain_level("大雨")
	weather.advance_visual_seconds(weather.puddle_formation_seconds)
	if weather.get_puddle_amount() <= medium_puddle_amount or weather_ground.get_impact_spawn_rate() <= medium_impact_rate or weather_ground.get_ripple_spawn_rate() <= medium_ripple_rate:
		_fail("Heavy rain should increase puddles, splashes and ripple emphasis")
		return
	weather.set_rain_level("小雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if not puddle_surface.visible or weather.get_puddle_amount() <= medium_puddle_amount:
		_fail("Puddles drained while rain was still falling")
		return
	weather.set_rain_level("大雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var sampled_feedback_position: Vector2 = weather_ground.get_visible_feedback_position()
	if sampled_feedback_position == Vector2.INF or not weather_ground.is_feedback_area(sampled_feedback_position):
		_fail("Rain feedback could not find a visible ground position")
		return
	screen_rain.advance_effects(1.0)
	if screen_rain._drops.is_empty():
		_fail("Heavy rain did not create droplets on the screen")
		return
	var largest_screen_drop := 0.0
	var longest_screen_trail := 0.0
	for drop: Dictionary in screen_rain._drops:
		largest_screen_drop = maxf(largest_screen_drop, float(drop["radius"]))
		longest_screen_trail = maxf(longest_screen_trail, float(drop["trail_length"]))
	if largest_screen_drop > 2.2 or longest_screen_trail < 8.0:
		_fail("Screen droplets were not halved or did not gain sliding trails")
		return
	if screen_rain.TRAIL_DIRECTION_Y >= 0.0:
		_fail("Screen droplet trails do not point upward")
		return
	weather.start_weather_event("晴朗", "半天")
	weather.advance_visual_seconds(1.0)
	if weather.visual_rain_density <= 0.0 or not wetness_overlay.visible:
		_fail("Rain stopped abruptly instead of fading out")
		return
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if weather.visual_rain_density != 0.0 or wetness_overlay.visible or not puddle_surface.visible or weather.get_puddle_amount() <= 0.0 or weather_ground.raining or rain_visual.is_audio_playing():
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
	weather.advance_visual_seconds(weather.puddle_drain_seconds)
	if weather.get_puddle_amount() != 0.0 or puddle_surface.visible:
		_fail("Puddles did not drain after rain fully stopped")
		return
	weather.start_weather_event("下雨", "半天", "中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds + weather.puddle_formation_seconds)
	if not weather_ground.has_method("is_puddle_position") or not weather_ground.has_method("spawn_step_feedback"):
		_fail("Player puddle feedback API is missing")
		return
	if weather_ground.puddle_mask != puddle_surface.texture:
		_fail("Puddle visuals and player footstep sampling do not share the same art texture")
		return
	var wet_step_position := Vector2(2176.0, 1952.0)
	var dry_step_position := Vector2(32.0, 32.0)
	if not weather_ground.is_puddle_position(wet_step_position) or weather_ground.is_puddle_position(dry_step_position):
		_fail("Puddle mask sampling does not match known wet and dry terrain")
		return
	weather_ground._impacts.clear()
	weather_ground._ripples.clear()
	if not weather_ground.spawn_step_feedback(wet_step_position, 1.0) or weather_ground._impacts.size() != 1 or weather_ground._ripples.size() != 1:
		_fail("Walking through a puddle did not create a splash and ripple")
		return
	if weather_ground.spawn_step_feedback(dry_step_position, 1.0) or weather_ground._impacts.size() != 1 or weather_ground._ripples.size() != 1:
		_fail("Dry-ground footsteps incorrectly created puddle feedback")
		return
	weather_ground._impacts.clear()
	weather_ground._ripples.clear()
	player.global_position = wet_step_position
	scene._last_puddle_step_position = wet_step_position - Vector2(32.0, 0.0)
	scene._process(0.0)
	if weather_ground._impacts.is_empty() or weather_ground._ripples.is_empty():
		_fail("Main gameplay movement did not trigger puddle footsteps")
		return
	var initial_impact_count: int = weather_ground._impacts.size()
	var initial_ripple_count: int = weather_ground._ripples.size()
	var puddle_position := Vector2(32.0, 32.0)
	if not weather_ground.is_feedback_area(puddle_position):
		_fail("Rain feedback rejected ordinary terrain")
		return
	weather_ground.spawn_impact(puddle_position)
	if weather_ground._impacts.size() != initial_impact_count + 1 or weather_ground._ripples.size() != initial_ripple_count:
		_fail("Dry-ground rain impact did not create a splash-only response")
		return
	weather_ground.spawn_impact(wet_step_position)
	if weather_ground._impacts.size() != initial_impact_count + 1 or weather_ground._ripples.size() != initial_ripple_count + 1:
		_fail("Puddle rain impact did not create a ripple-only response")
		return
	weather_ground.set_rain_strength(0.0)
	weather_ground.advance_effects(2.0)
	if not weather_ground._impacts.is_empty() or not weather_ground._ripples.is_empty():
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
	weather.start_weather_event("下雪", "一天", "中雪")
	if weather.current_duration_mode != "一天" or weather.remaining_game_minutes != 1440:
		_fail("Full-day snow duration is incorrect")
		return
	weather.advance_visual_seconds(1.0)
	if weather.visual_snow_density <= 0.0 or weather.visual_snow_density >= 0.60:
		_fail("Snow did not fade in gradually")
		return
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if wetness_overlay.visible or weather_ground.raining:
		_fail("Rain wetness remained active during snow")
		return
	if weather.current_snow_level != "中雪" or weather.get_active_snow_particle_count() != 108:
		_fail("Medium snow density did not initialize")
		return
	weather.set_snow_level("小雪")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var light_snow_count: int = weather.get_active_snow_particle_count()
	weather.set_snow_level("中雪")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var medium_snow_count: int = weather.get_active_snow_particle_count()
	weather.set_snow_level("大雪")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var heavy_snow_count: int = weather.get_active_snow_particle_count()
	if not (light_snow_count < medium_snow_count and medium_snow_count < heavy_snow_count and heavy_snow_count == 180):
		_fail("Light, medium and heavy snow densities are not distinct")
		return
	var snow_position_before: Vector2 = snow_world.get_particle_world_position(0)
	player.global_position += Vector2(240.0, 120.0)
	await process_frame
	if snow_world.get_particle_world_position(0) != snow_position_before:
		_fail("World-space snow followed the player or camera")
		return
	weather.advance_game_minutes(1439)
	if weather.current_weather != "下雪":
		_fail("Full-day snow ended early")
		return
	weather.advance_game_minutes(1)
	if weather.current_weather != "晴朗":
		_fail("Full-day snow did not end after 1440 game minutes")
		return
	weather.advance_visual_seconds(1.0)
	if weather.visual_snow_density <= 0.0:
		_fail("Snow stopped abruptly instead of fading out")
		return
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if weather.visual_snow_density != 0.0 or weather.get_active_snow_particle_count() != 0:
		_fail("Snow fade-out did not finish cleanly")
		return
	for _sample: int in range(40):
		weather.trigger_special_weather("下雨")
		if weather.event_duration_days < 3 or weather.event_duration_days > 10:
			_fail("Special weather duration escaped the 3-10 day range")
			return
	for _sample: int in range(40):
		weather.trigger_special_weather("下雪")
		if weather.event_duration_days < 3 or weather.event_duration_days > 10 or weather.current_snow_level != "大雪":
			_fail("Special snow did not reuse the 3-10 day heavy-weather logic")
			return
	weather.start_weather_event("下雨", "半天", "中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if not wetness_overlay.visible or not weather_ground.raining:
		_fail("Rain wetness did not reactivate")
		return
	weather_ground.spawn_impact(Vector2(32.0, 32.0))
	if weather_ground._impacts.is_empty():
		_fail("Falling rain did not trigger a ground splash")
		return
	var far_material := far_rain.process_material as ParticleProcessMaterial
	var near_material := near_rain.process_material as ParticleProcessMaterial
	if far_material == null or near_material == null or not far_material.particle_flag_align_y or not near_material.particle_flag_align_y:
		_fail("GPU rain layers did not align streaks to their velocity")
		return
	if far_material.direction.x >= 0.0 or far_material.direction.y <= 0.0 or near_material.initial_velocity_min <= far_material.initial_velocity_max:
		_fail("Rain direction or depth-layer speed ordering is incorrect")
		return
	if far_material.spread <= 0.0 or far_material.scale_min >= far_material.scale_max or far_rain.randomness < 0.3:
		_fail("GPU rain still lacks natural spread, scale or lifetime variation")
		return
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	if far_rain.visibility_rect.size.x < viewport_size.x * 1.4 or far_rain.visibility_rect.size.y < viewport_size.y + 150.0:
		_fail("Camera movement can reveal gaps around the rain emitter")
		return
	var wind_before: Vector2 = rain_visual.get_wind_vector()
	rain_visual.advance_effects(0.5)
	var wind_after: Vector2 = rain_visual.get_wind_vector()
	if wind_after.x >= 0.0 or wind_after.y <= 0.0 or wind_before.distance_to(wind_after) > 0.08:
		_fail("Rain gusts jump instead of changing smoothly")
		return
	if minimap.player != player or minimap.world_size != Vector2(8192.0, 8192.0):
		_fail("Minimap did not bind to the local player")
		return
	if scene.inventory.slots.size() != 20 or scene.inventory.get_item_count("stone_axe") != 1 or scene.inventory.get_item_count("torch") != 1:
		_fail("Starter backpack did not initialize with the temporary torch")
		return
	if inventory_grid.get_child_count() != 20:
		_fail("Backpack UI did not render all slots")
		return
	var stone_axe_button := inventory_grid.get_child(0) as Button
	var torch_button := inventory_grid.get_child(1) as Button
	if stone_axe_button.icon == null or torch_button.icon == null or stone_axe_button.tooltip_text.find("石斧") < 0 or torch_button.tooltip_text.find("火把") < 0:
		_fail("Stone axe or torch inventory icon did not render")
		return
	if skill_branches.get_child_count() != 3 or ritual_row.get_child_count() != 1 or scene.skill_tree.skill_points != 12:
		_fail("Three-branch skill tree did not initialize")
		return
	if ritual_row.get_parent() != skill_branches.get_parent() or ritual_row.get_index() <= skill_branches.get_index():
		_fail("Ascension ritual was not placed to the right of all three branches")
		return
	cloud_layer.set_weather("晴朗")
	if cloud_layer.get_active_cloud_count() != 4:
		_fail("Clear weather did not show randomized clouds")
		return
	for cloud: Dictionary in cloud_layer.clouds:
		if not cloud_layer.BLOCK_CLOUD_CELLS.has(int(cloud["cell"])):
			_fail("Thin cloud frames were not removed")
			return
	cloud_layer.set_weather("下雨")
	if cloud_layer.get_active_cloud_count() != 0:
		_fail("Cloud layer remained active outside clear weather")
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
		if child.name.begins_with("New"):
			vegetation_count += 1
	if vegetation_count != 0:
		_fail("Decorative vegetation props were not removed")
		return
	if player_sprite.hframes != 12 or player_sprite.vframes != 8:
		_fail("Male player 12-frame eight-direction animation sheet did not load")
		return
	if (
		player._direction_row(Vector2.DOWN) != 0
		or player._direction_row(Vector2(1.0, 1.0)) != 1
		or player._direction_row(Vector2.RIGHT) != 2
		or player._direction_row(Vector2(1.0, -1.0)) != 3
		or player._direction_row(Vector2.UP) != 4
		or player._direction_row(Vector2(-1.0, -1.0)) != 5
		or player._direction_row(Vector2.LEFT) != 6
		or player._direction_row(Vector2(-1.0, 1.0)) != 7
	):
		_fail("Male eight-direction row mapping is incorrect")
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
	if day_night_tint.color.r > 0.07 or not night_vision.visible or not player.torch_equipped:
		_fail("Night did not become nearly black or auto-equip the backpack torch")
		return
	if night_vision.NO_TORCH_RADIUS != 41.0 or night_vision.TORCH_RADIUS != 82.0:
		_fail("Torch and no-torch visibility ranges were not halved")
		return
	if night_vision.get_visibility_radius(true) != night_vision.get_visibility_radius(false) * 2.0:
		_fail("Torch night visibility radius is not exactly double")
		return
	if float(night_vision.material.get_shader_parameter("softness_px")) < 50.0:
		_fail("Torch visibility transition is too narrow")
		return
	await physics_frame
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_torch_hold/sheet-transparent.png":
		_fail("Night torch-holding animation did not activate")
		return
	scene.inventory.remove_item("torch", 1)
	await process_frame
	if player.torch_equipped or night_vision.current_radius != night_vision.NO_TORCH_RADIUS:
		_fail("No-torch night visibility did not use the small radius")
		return
	scene.inventory.add_item("torch", "临时火把", 1, 1)
	await process_frame
	if not player.torch_equipped or night_vision.current_radius != night_vision.TORCH_RADIUS:
		_fail("Torch inventory state did not restore the larger night radius")
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
	if not cloud_layer.get_cloud_tint().is_equal_approx(day_night_tint.color):
		_fail("Dusk and night tint did not affect the cloud layer")
		return
	day_night_cycle.set_game_time(1, 7.0)
	await process_frame

	var ocean_query := PhysicsPointQueryParameters2D.new()
	ocean_query.position = Vector2(8050.0, 3900.0)
	ocean_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(ocean_query).is_empty():
		_fail("Ocean collision did not cover a deep-water point")
		return

	var walkable_query := PhysicsPointQueryParameters2D.new()
	walkable_query.position = Vector2(4100.0, 4700.0)
	walkable_query.collision_mask = 2
	if not scene.get_world_2d().direct_space_state.intersect_point(walkable_query).is_empty():
		_fail("Replacement map spawn point was blocked")
		return

	var mountain_query := PhysicsPointQueryParameters2D.new()
	mountain_query.position = Vector2(3400.0, 1050.0)
	mountain_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(mountain_query).is_empty():
		_fail("Mountain collision did not block the north summit")
		return

	var ridge_query := PhysicsPointQueryParameters2D.new()
	ridge_query.position = Vector2(4520.0, 2050.0)
	ridge_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(ridge_query).is_empty():
		_fail("Central rock needle collision did not load")
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

	player.global_position = Vector2(4100.0, 4700.0)
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
	if player_sprite.frame_coords.y != 2 or player_sprite.frame_coords.x == 0:
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
	if player_sprite.frame_coords.y != 6:
		_fail("Player left-facing animation is reversed")
		return
	Input.action_release("ui_left")
	Input.action_press("ui_down")
	await physics_frame
	await physics_frame
	if player_sprite.frame_coords.y != 0 or player_sprite.position.y != -140.0 or player_sprite.scale != Vector2(2.2, 2.2):
		_fail("Down-facing movement does not overlap the character with its shadow")
		return
	Input.action_release("ui_down")

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
	if player_sprite.scale != Vector2(2.2, 2.2):
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

	Input.action_press("player_pickup")
	await physics_frame
	await physics_frame
	if action_icon.tooltip_text != "拾取" or player_sprite.texture.resource_path != "res://assets/characters/player_male_pickup/sheet-transparent.png":
		_fail("F did not trigger the four-direction pickup animation")
		return
	Input.action_release("player_pickup")
	for _frame: int in range(50):
		await physics_frame
	if action_icon.tooltip_text == "拾取":
		_fail("Pickup animation did not return to movement control")
		return

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
	for _frame: int in range(40):
		await physics_frame
	player._active_animation = ""
	await physics_frame
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_idle_relaxed/sheet-transparent.png" or player_sprite.scale != Vector2(2.2, 2.2):
		_fail("Relaxed standing breathing animation or shared character scale did not activate")
		return
	player._animation_elapsed = 1.0 / 12.0
	if player._animation_frame("idle_relaxed", false) != 1:
		_fail("The replacement idle animation is not playing at its authored 12 FPS")
		return
	player._animation_elapsed = 100.0
	player._active_animation = ""
	await physics_frame
	var portrait: TextureRect = scene.get_node("HUD/PlayerStatus/Margin/Content/PortraitFrame/Portrait")
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_idle_relaxed/sheet-transparent.png" or player_sprite.scale != Vector2(2.2, 2.2) or portrait.texture.resource_path != "res://assets/characters/player_male.png":
		_fail("Extended idle switched away from the standing breathing animation")
		return
	if player_sprite.hframes != 12 or player_sprite.vframes != 8:
		_fail("The male player did not retain the 12-frame eight-direction layout")
		return

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
	scene._toggle_world_map()
	if not world_map_overlay.visible or inventory_overlay.visible or skill_overlay.visible or world_map.player != player:
		_fail("M world map did not open with the player marker")
		return
	if not world_map.world_mode or world_map.get_board_count() != 9:
		_fail("M world map is not composed of nine map boards surrounded by ocean")
		return
	scene._toggle_world_map()

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

	print("SMOKE_OK: title, male player, idle, item icons, world snow, forecast and gameplay systems")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _icon_is_ready(icon: TextureRect, tooltip: String) -> bool:
	return icon.texture is AtlasTexture and icon.tooltip_text == tooltip
