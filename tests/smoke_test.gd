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
	var wet_footstep_audio := scene.get_node("Weather/WetFootstep") as AudioStreamPlayer
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
	if not player.global_position.is_equal_approx(Vector2(6500.0, 2500.0)):
		_fail("Player did not spawn on the upper-right beach")
		return
	var map_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/spawn/spawn_map.json"))
	var map_chunks: Array = map_manifest.get("chunks", [])
	if map_chunks.size() != 16:
		_fail("Replacement map manifest did not keep the 4x4 chunk layout")
		return
	for map_chunk: Dictionary in map_chunks:
		var shoreline_path := "res://" + String(map_chunk.get("water", {}).get("shoreline", ""))
		var shoreline_texture := load(shoreline_path) as Texture2D
		if shoreline_texture == null or shoreline_texture.get_size() != Vector2(512.0, 512.0):
			_fail("A generated shoreline mask is missing or incorrectly sized: " + shoreline_path)
			return
	if player.move_speed != 170.0 or player.run_speed != 280.0 or player.crouch_speed != 82.0 or player.crawl_speed != 46.0:
		_fail("Normal player movement speeds were not restored")
		return
	if not is_equal_approx(camera.zoom.x, 0.273):
		_fail("Camera was not pulled back by 50 percent")
		return
	var initial_chunk_count: int = scene.get_node("World").get_loaded_chunk_count()
	if foundation.get_child_count() != initial_chunk_count or initial_chunk_count < 4 or initial_chunk_count > 12:
		_fail("Spawn foundation did not stream the camera-visible chunk range: nodes=%d loaded=%d" % [foundation.get_child_count(), initial_chunk_count])
		return
	for chunk: Sprite2D in foundation.get_children():
		if chunk.texture == null or chunk.texture.get_size() != Vector2(2048.0, 2048.0):
			_fail("A replacement map chunk is not 2048x2048: " + chunk.name)
			return
		var water_surface := chunk.get_node_or_null("WaterSurface") as Sprite2D
		if water_surface == null or water_surface.texture != chunk.texture or not water_surface.material is ShaderMaterial:
			_fail("A streamed map chunk is missing its editable water surface overlay: " + chunk.name)
			return
		var water_material := water_surface.material as ShaderMaterial
		var water_mask := water_material.get_shader_parameter("water_mask") as Texture2D
		if water_mask == null or water_mask.get_size() != chunk.texture.get_size():
			_fail("A water mask does not match its map chunk dimensions: " + chunk.name)
			return
		var water_depth := water_material.get_shader_parameter("water_depth") as Texture2D
		if water_depth == null or water_depth.get_size() != Vector2(512.0, 512.0):
			_fail("The optimized shoreline depth mask is missing: " + chunk.name)
			return
		var shoreline_mask := water_material.get_shader_parameter("shoreline_mask") as Texture2D
		if shoreline_mask == null or shoreline_mask.get_size() != Vector2(512.0, 512.0):
			_fail("The optimized animated shoreline mask is missing: " + chunk.name)
			return
		if water_material.get_shader_parameter("chunk_world_origin") != chunk.position:
			_fail("Water motion is not aligned to map world coordinates: " + chunk.name)
			return
		if not is_equal_approx(float(water_material.get_shader_parameter("distortion_pixels")), 5.8):
			_fail("The enhanced natural-refraction water preset was not applied: " + chunk.name)
			return
		if not is_equal_approx(float(water_material.get_shader_parameter("shallow_opacity")), 0.44) or not is_equal_approx(float(water_material.get_shader_parameter("deep_opacity")), 0.84):
			_fail("Water depth did not control shallow transparency and deep reflection: " + chunk.name)
			return
		if not is_equal_approx(float(water_material.get_shader_parameter("wave_strength")), 0.065):
			_fail("Traveling surface waves were not applied: " + chunk.name)
			return
		if not is_equal_approx(float(water_material.get_shader_parameter("baked_edge_cover")), 0.75) or not is_equal_approx(float(water_material.get_shader_parameter("shore_foam_strength")), 0.72):
			_fail("Animated shoreline cover preset was not applied: " + chunk.name)
			return
	var water_interactions := scene.get_node_or_null("World/WaterSurfaceInteractions")
	if water_interactions == null:
		_fail("Surface-swimming ripple feedback is missing")
		return
	scene.get_node("World").set_water_weather_strength(0.8)
	for chunk: Sprite2D in foundation.get_children():
		var water_surface := chunk.get_node("WaterSurface") as Sprite2D
		if not is_equal_approx(float(water_surface.material.get_shader_parameter("weather_strength")), 0.8):
			_fail("Rain intensity did not strengthen the natural water motion")
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
	if scene.get_node_or_null("HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/ActionIcon") != null:
		_fail("Movement-state icon was not removed from the player HUD")
		return
	if not _icon_is_ready(condition_icon, "开心") or not _icon_is_ready(visibility_icon, "公开可见"):
		_fail("Player HUD status icons did not initialize")
		return
	if condition_icon.custom_minimum_size != Vector2(32.0, 32.0) or visibility_icon.custom_minimum_size != Vector2(32.0, 32.0):
		_fail("Player status icons were not enlarged")
		return
	if phase_icon.custom_minimum_size != Vector2(32.0, 32.0):
		_fail("Day phase icon was not enlarged inside its fixed panel")
		return
	if (phase_icon.texture as AtlasTexture).region.size != Vector2(40.0, 40.0):
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
	if not wetness_overlay.visible or puddle_surface.visible or not weather_ground.raining or weather.get_puddle_amount() != 0.0:
		_fail("Rain did not retain wet grading while keeping puddle visuals disabled")
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
	if audio_players.size() != 5 or rain_visual._rain_loop not in audio_players or thunder_audio not in audio_players or day_birds_audio not in audio_players or day_wind_audio not in audio_players or wet_footstep_audio not in audio_players:
		_fail("Rainy footstep audio was not retained with the weather audio")
		return
	if wetness_overlay.material.get_shader_parameter("rain_intensity") <= 0.0 or float(puddle_surface.material.get_shader_parameter("puddle_amount")) != 0.0:
		_fail("Wet grade or disabled puddle shader state is incorrect")
		return
	if weather.current_rain_level != "中雨" or weather.get_active_rain_particle_count() != 255:
		_fail("Medium rain density did not initialize")
		return
	if rain_visual.get_mist_strength() <= 0.0:
		_fail("Medium rain did not enable the low ground mist layer")
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
	var light_water_ripple_rate: float = weather_ground.get_water_ripple_spawn_rate()
	if puddle_surface.visible or weather.get_puddle_amount() != 0.0 or light_impact_rate <= 0.0 or light_water_ripple_rate <= 0.0 or weather_ground.get_ripple_spawn_rate() != 0.0:
		_fail("Light rain should create land splashes and water ripples without puddles")
		return
	weather.set_rain_level("中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	var medium_impact_rate: float = weather_ground.get_impact_spawn_rate()
	var medium_water_ripple_rate: float = weather_ground.get_water_ripple_spawn_rate()
	if puddle_surface.visible or weather.get_puddle_amount() != 0.0 or medium_impact_rate <= light_impact_rate or medium_water_ripple_rate <= light_water_ripple_rate or weather_ground.get_ripple_spawn_rate() != 0.0:
		_fail("Medium rain should strengthen land splashes and water ripples without enabling puddles")
		return
	weather.set_rain_level("大雨")
	weather.advance_visual_seconds(weather.puddle_formation_seconds)
	if puddle_surface.visible or weather.get_puddle_amount() != 0.0 or weather_ground.get_impact_spawn_rate() <= medium_impact_rate or weather_ground.get_water_ripple_spawn_rate() <= medium_water_ripple_rate or weather_ground.get_ripple_spawn_rate() != 0.0:
		_fail("Heavy rain should increase splash density without puddles")
		return
	weather.set_rain_level("小雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	if puddle_surface.visible or weather.get_puddle_amount() != 0.0:
		_fail("Puddle visuals returned while rain was falling")
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
	if weather.visual_rain_density != 0.0 or wetness_overlay.visible or puddle_surface.visible or weather.get_puddle_amount() != 0.0 or weather_ground.raining or rain_visual.is_audio_playing():
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
	var wet_step_position := Vector2(2176.0, 1952.0)
	weather_ground._impacts.clear()
	weather_ground._ripples.clear()
	var step_audio_before: int = scene.get_rain_step_play_count()
	player.global_position = wet_step_position
	player._set_movement_state(player.STATE_WALK)
	scene._last_puddle_step_position = wet_step_position - Vector2(90.0, 0.0)
	scene._process(0.0)
	if scene.get_rain_step_play_count() != step_audio_before + 1 or not weather_ground._impacts.is_empty() or not weather_ground._ripples.is_empty():
		_fail("Rainy movement did not keep footstep audio separate from puddle visuals")
		return
	var initial_impact_count := 0
	var land_position := Vector2(6500.0, 2500.0)
	var water_position := Vector2(7300.0, 2500.0)
	if not weather_ground.is_feedback_area(land_position) or weather_ground.is_water_surface_position(land_position):
		_fail("Rain feedback could not identify ordinary terrain")
		return
	weather_ground.spawn_impact(land_position)
	if weather_ground._impacts.size() != initial_impact_count + 1 or not weather_ground._ripples.is_empty():
		_fail("Land rain impact did not create a splash-only response")
		return
	if not weather_ground.is_water_surface_position(water_position):
		_fail("Rain feedback could not identify the natural water surface")
		return
	weather_ground.spawn_impact(water_position)
	if weather_ground._impacts.size() != initial_impact_count + 1 or weather_ground._ripples.size() != 1:
		_fail("Natural water rain impact did not create a ripple-only response")
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
	weather_ground.spawn_impact(Vector2(6500.0, 2500.0))
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
	if skill_branches.get_child_count() != 5 or ritual_row.get_child_count() != 1 or scene.skill_tree.skill_points != 12:
		_fail("Primitive Era five-branch skill tree did not initialize")
		return
	if ritual_row.get_parent() != skill_branches.get_parent() or ritual_row.get_index() <= skill_branches.get_index():
		_fail("Ascension ritual was not placed after all five branches")
		return
	cloud_layer.set_weather("晴朗")
	if cloud_layer.get_active_cloud_count() != cloud_layer.CLEAR_CLOUD_COUNT or not cloud_layer.is_shadow_only():
		_fail("Clear weather did not show randomized ground shadows")
		return
	var shared_cloud_shadow_material: Material = null
	for cloud: Dictionary in cloud_layer.clouds:
		if not cloud_layer.BLOCK_CLOUD_CELLS.has(int(cloud["cell"])):
			_fail("Thin cloud frames were not removed")
			return
		var shadow := cloud["sprite"] as Sprite2D
		if shadow.material == null or shadow.material.shader.resource_path != "res://shaders/ordered_shadow.gdshader":
			_fail("Cloud shadow is missing the ordered screen-space material")
			return
		if shared_cloud_shadow_material == null:
			shared_cloud_shadow_material = shadow.material
		elif shadow.material != shared_cloud_shadow_material:
			_fail("Cloud shadows are not composed through one shared mask")
			return
	var ordered_material := shared_cloud_shadow_material as ShaderMaterial
	var shadow_multiplier: Vector3 = ordered_material.get_shader_parameter("shadow_multiplier")
	if cloud_layer.get_shadow_coverage() <= 0.0 or is_equal_approx(shadow_multiplier.x, shadow_multiplier.y):
		_fail("Cloud shadows are missing daylight coverage or colored tint")
		return
	if "BAYER_4X4" not in ordered_material.shader.code or "SCREEN_UV" not in ordered_material.shader.code:
		_fail("Cloud shadows are not using stable screen-space ordered dithering")
		return
	cloud_layer.set_weather("下雨")
	if cloud_layer.get_active_cloud_count() != 0:
		_fail("Cloud layer remained active outside clear weather")
		return
	for branch_row: HBoxContainer in skill_branches.get_children():
		if branch_row.get_child_count() != 8:
			_fail("Skill branch did not render four illuminated nodes")
			return
	if scene.skill_tree.get_total_skill_count() != 20 or scene.skill_tree.get_total_skill_cost() != 40:
		_fail("Primitive Era skill tree does not contain 20 skills costing 40 SP")
		return
	if scene.get_node_or_null("World/DepthSorted/EastGrass") != null:
		_fail("Interactive vegetation was not removed")
		return
	var expected_first_row_assets := PackedStringArray([
		"res://assets/maps/props/vegetation/palms/palm_tree_001.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_002.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_003.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_004.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_005.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_006.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_007.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_008.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_009.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_010.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_011.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_012.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_013.png",
		"res://assets/maps/props/vegetation/palms/palm_tree_014.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_001.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_002.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_003.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_004.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_005.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_006.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_007.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_008.png",
		"res://assets/maps/props/vegetation/tropical_plants/tropical_plant_009.png",
	])
	var placed_first_row_assets := {}
	var northeast_beach := Rect2(5900.0, 1900.0, 1100.0, 1000.0)
	for child: Node in depth_sorted.get_children():
		var child_name := child.name.to_lower()
		var is_beach_plant := child_name.begins_with("northeastpalm") or child_name.begins_with("northeastbeachplant")
		if child_name.contains("grass") or (child_name.contains("plant") and not is_beach_plant) or (child_name.contains("tree") and not is_beach_plant):
			_fail("A vegetation patch remains in the depth-sorted map")
			return
		if is_beach_plant:
			for visual: Node in child.get_children():
				if visual is Sprite2D and (visual as Sprite2D).texture != null:
					placed_first_row_assets[(visual as Sprite2D).texture.resource_path] = true
			var is_added_asset := child_name.begins_with("northeastbeachplant") or (
				child_name.begins_with("northeastpalm") and int(child_name.trim_prefix("northeastpalm")) >= 8
			)
			if is_added_asset and not northeast_beach.has_point((child as Node2D).position):
				_fail("A newly placed first-row plant is outside the northeast beach")
				return
		if child_name.begins_with("northeastpalm"):
			var blocker := child.get_node_or_null("Blocker") as StaticBody2D
			if child.get_node_or_null("Sprite2D") == null or blocker == null or blocker.get_child_count() != 1 or not blocker.get_child(0) is CollisionShape2D:
				_fail("A northeast beach palm is missing its sprite or trunk collision")
				return
	for asset_path: String in expected_first_row_assets:
		if not placed_first_row_assets.has(asset_path):
			_fail("A first-row vegetation asset is missing from the beach: " + asset_path)
			return
	var wind_vegetation := get_nodes_in_group("wind_vegetation")
	if wind_vegetation.size() < 17:
		_fail("Vegetation wind did not include every coconut palm: %d" % wind_vegetation.size())
		return
	var wind_categories := {"palms": false, "trees": false, "tropical_plants": false, "foliage": false}
	var palm_phases: Array[float] = []
	for wind_sprite: Node in wind_vegetation:
		if not wind_sprite is Sprite2D or (wind_sprite as Sprite2D).texture == null:
			_fail("A non-sprite entered the vegetation wind group")
			return
		var wind_path := (wind_sprite as Sprite2D).texture.resource_path
		var matched_category := false
		for category: String in wind_categories:
			if "/vegetation/%s/" % category in wind_path:
				wind_categories[category] = true
				matched_category = true
				if category == "palms":
					palm_phases.append(float((wind_sprite as Sprite2D).get_instance_shader_parameter("wind_phase")))
				break
		if not matched_category:
			_fail("An unsupported asset entered the vegetation wind group: " + wind_path)
			return
	for category: String in wind_categories:
		if not bool(wind_categories[category]):
			_fail("Vegetation wind is missing category: " + category)
			return
	if palm_phases.size() < 2 or is_equal_approx(palm_phases[0], palm_phases[1]):
		_fail("Coconut palms do not have independent wind phases")
		return
	var wind_sample = scene.get_node("World/DepthSorted/NortheastPalm01/Sprite2D")
	wind_sample.process_mode = Node.PROCESS_MODE_DISABLED
	wind_sample.set_wind_strength(1.0)
	var trunk_anchor_before: Vector2 = wind_sample.get_trunk_anchor_position()
	var transform_before: Transform2D = wind_sample.transform
	var wind_time_before := float(wind_sample.get_instance_shader_parameter("wind_time"))
	for _wind_step: int in range(8):
		wind_sample.advance_wind(0.35)
		if wind_sample.get_trunk_anchor_position().distance_to(trunk_anchor_before) > 0.01:
			_fail("Palm wind animation moved the trunk base away from its collision anchor")
			return
		if wind_sample.transform != transform_before:
			_fail("Vegetation wind changed the sprite transform instead of deforming internal pixels")
			return
	if float(wind_sample.get_instance_shader_parameter("wind_time")) <= wind_time_before:
		_fail("Vegetation wind shader time did not advance")
		return
	var trunk_amplitude := float(wind_sample.get_instance_shader_parameter("trunk_amplitude_pixels"))
	var leaf_amplitude := float(wind_sample.get_instance_shader_parameter("leaf_amplitude_pixels"))
	if leaf_amplitude <= trunk_amplitude or float(wind_sample.get_instance_shader_parameter("root_lock_height")) <= 0.0:
		_fail("Palm leaves and trunk are not using separate sway ranges with a fixed root")
		return
	wind_sample.clear_wind_strength_override()
	var central_vegetation := scene.get_node_or_null("World/DepthSorted/CentralVegetation") as Node2D
	if central_vegetation == null or central_vegetation.position != Vector2(4096.0, 3950.0) or not central_vegetation.y_sort_enabled:
		_fail("Central vegetation scene is missing, misplaced or not depth sorted")
		return
	var expected_central_paths := {}
	var vegetation_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/props/vegetation/_source/split_manifest.json"))
	if typeof(vegetation_manifest) != TYPE_DICTIONARY:
		_fail("Vegetation split manifest could not be read")
		return
	for entry: Dictionary in vegetation_manifest["assets"]:
		var category := String(entry["category"])
		var asset_id := String(entry["id"])
		var is_first_row_tropical := category == "tropical_plants" and int(asset_id.get_slice("_", 2)) <= 9
		if category != "rocks" and category != "palms" and not is_first_row_tropical:
			expected_central_paths["res://assets/maps/props/vegetation/" + String(entry["path"])] = true
	var placed_central_paths := {}
	var central_bounds := Rect2(-1750.0, -1400.0, 3500.0, 3100.0)
	for holder: Node in central_vegetation.get_children():
		var sprite := holder.get_node_or_null("Sprite2D") as Sprite2D
		if not holder is Node2D or sprite == null or sprite.texture == null:
			_fail("A central vegetation asset is not independently editable")
			return
		if not central_bounds.has_point((holder as Node2D).position):
			_fail("A central vegetation asset was placed outside the map-center cluster")
			return
		placed_central_paths[sprite.texture.resource_path] = true
	if expected_central_paths.size() != 145 or placed_central_paths.size() != 145:
		_fail("Central vegetation count is incorrect: expected=%d placed=%d" % [expected_central_paths.size(), placed_central_paths.size()])
		return
	for asset_path: String in expected_central_paths:
		if not placed_central_paths.has(asset_path):
			_fail("A non-beach vegetation asset is missing from the map center: " + asset_path)
			return
	if player_sprite.hframes != 16 or player_sprite.vframes != 8:
		_fail("Male player 16-frame eight-direction animation sheet did not load")
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
	ocean_query.position = Vector2(7300.0, 2500.0)
	ocean_query.collision_mask = 2
	if not scene.get_node("World").is_water_position(ocean_query.position):
		_fail("Beach ocean was not detected by the replacement water mask")
		return
	if not scene.get_world_2d().direct_space_state.intersect_point(ocean_query).is_empty():
		_fail("Beach ocean was incorrectly blocked by terrain collision")
		return

	var walkable_query := PhysicsPointQueryParameters2D.new()
	walkable_query.position = Vector2(6500.0, 2500.0)
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

	player.enter_cover(scene)
	await process_frame
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

	player.exit_cover(scene)
	await process_frame
	if not _icon_is_ready(visibility_icon, "公开可见"):
		push_error("Player did not leave concealment")
		quit(1)
		return

	Input.action_press("player_run")
	Input.action_press("ui_right")
	for _frame: int in range(10):
		await physics_frame
	if player.get_movement_state() != player.STATE_RUN:
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
	var grounded_sprite_y: float = player.SHADOW_CENTER.y - (player.CHARACTER_FEET_BASELINE - player.CHARACTER_FRAME_SIZE * 0.5) * player.CHARACTER_SCALE.y
	if player_sprite.frame_coords.y != 0 or not is_equal_approx(player_sprite.position.y, grounded_sprite_y) or player_sprite.scale != Vector2(2.2, 2.2):
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
	if player.get_movement_state() != player.STATE_CROUCH:
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
	if player.get_movement_state() != player.STATE_PRONE:
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
	if player.get_movement_state() != player.STATE_CRAWL:
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
	if player.get_movement_state() != player.STATE_PICKUP or player_sprite.texture.resource_path != "res://assets/characters/player_male_pickup/sheet-transparent.png":
		_fail("F did not trigger the four-direction pickup animation")
		return
	Input.action_release("player_pickup")
	for _frame: int in range(50):
		await physics_frame
	if player.get_movement_state() == player.STATE_PICKUP:
		_fail("Pickup animation did not return to movement control")
		return

	player.attack_duration = 0.25
	Input.action_press("player_attack")
	for _frame: int in range(4):
		await physics_frame
	Input.action_release("player_attack")
	if player.get_movement_state() != player.STATE_ATTACK or player_sprite.texture.resource_path != "res://assets/characters/player_male_attack/sheet-transparent.png" or player_sprite.hframes != 16:
		_fail("Left click did not trigger the eight-direction punch animation")
		return
	for _frame: int in range(20):
		await physics_frame
	player.attack_duration = 0.48
	if player.get_movement_state() == player.STATE_ATTACK:
		_fail("Attack animation did not return to movement control")
		return

	Input.action_press("player_jump")
	for _frame: int in range(10):
		await physics_frame
	if player.get_movement_state() != player.STATE_JUMP:
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
	player._animation_elapsed = 0.125
	if player._animation_frame("idle_relaxed", false) != 1:
		_fail("The replacement idle animation is not playing at its authored 8 FPS")
		return
	player._animation_elapsed = 100.0
	player._active_animation = ""
	await physics_frame
	var portrait: TextureRect = scene.get_node("HUD/PlayerStatus/Margin/Content/PortraitFrame/Portrait")
	if player_sprite.texture.resource_path != "res://assets/characters/player_male_idle_relaxed/sheet-transparent.png" or player_sprite.scale != Vector2(2.2, 2.2) or portrait.texture.resource_path != "res://assets/characters/player_male.png":
		_fail("Extended idle switched away from the standing breathing animation")
		return
	if player_sprite.hframes != 16 or player_sprite.vframes != 8:
		_fail("The male player did not retain the 16-frame eight-direction layout")
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

	scene.skill_tree.add_skill_points(28)
	for branch: Dictionary in scene.skill_tree.BRANCHES:
		for skill: Dictionary in branch["skills"]:
			var skill_id := String(skill["id"])
			if not scene.skill_tree.unlock_skill(skill_id):
				_fail("Skill branch could not unlock: " + skill_id)
				return
	if scene.skill_tree.skill_points != 0 or scene.skill_tree.is_ritual_ready():
		_fail("Ritual ignored the era proof or personally gathered materials")
		return
	for material_id: String in scene.skill_tree.RITUAL_CORE_MATERIALS:
		scene.skill_tree.add_personal_material(material_id, int(scene.skill_tree.RITUAL_CORE_MATERIALS[material_id]))
	scene.skill_tree.add_era_proof("狂暴猿王")
	if not scene.skill_tree.is_ritual_ready():
		_fail("Complete Primitive Era requirements did not activate the ritual")
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
