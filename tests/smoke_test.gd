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
	var status: Label = scene.get_node("HUD/TopBar/Margin/Row/ConcealmentLabel")
	var action: Label = scene.get_node("HUD/TopBar/Margin/Row/ActionLabel")
	var health_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthBar")
	var health_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthLabel")
	var stamina_bar: ProgressBar = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaBar")
	var stamina_label: Label = scene.get_node("HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaLabel")
	var foundation: Node2D = scene.get_node("World/Foundation")
	var blockers: Node2D = scene.get_node("World/Collision")
	var camera: Camera2D = player.get_node("Camera2D")
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
	if scene.get_node_or_null("World/DepthSorted/EastGrass") == null:
		_fail("Interactive vegetation did not load")
		return

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
	await physics_frame
	await physics_frame
	if status.text != "状态：草丛隐蔽":
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
	await physics_frame
	await physics_frame
	if status.text != "状态：可见":
		push_error("Player did not leave concealment")
		quit(1)
		return

	Input.action_press("player_run")
	Input.action_press("ui_right")
	await physics_frame
	await physics_frame
	if action.text != "动作：奔跑":
		_fail("Run state did not activate")
		return
	if stamina_bar.value >= stamina_bar.max_value:
		_fail("Running did not consume stamina")
		return
	Input.action_release("ui_right")
	Input.action_release("player_run")

	player.take_damage(25.0)
	await process_frame
	if not is_equal_approx(health_bar.value, 75.0) or health_label.text != "生命 75 / 100":
		_fail("Health HUD did not track player damage")
		return

	Input.action_press("player_crouch")
	await physics_frame
	await physics_frame
	if action.text != "动作：蹲伏":
		_fail("Crouch state did not activate")
		return
	Input.action_release("player_crouch")

	Input.action_press("player_crawl")
	await physics_frame
	await physics_frame
	if action.text != "动作：爬行":
		_fail("Crawl state did not activate")
		return
	Input.action_release("player_crawl")

	Input.action_press("player_jump")
	await physics_frame
	await physics_frame
	if action.text != "动作：跳跃":
		_fail("Jump state did not activate")
		return
	Input.action_release("player_jump")

	print("SMOKE_OK: player status HUD, stamina, concealment and movement states")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
