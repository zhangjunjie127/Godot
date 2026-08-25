extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://main.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await physics_frame

	var player: CharacterBody2D = scene.get_node("World/Actors/Player")
	var grass: Area2D = scene.get_node("World/InteractivePlants/EastGrass")
	var status: Label = scene.get_node("HUD/TopBar/Margin/Row/ConcealmentLabel")
	var action: Label = scene.get_node("HUD/TopBar/Margin/Row/ActionLabel")

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
	if action.text != "动作：奔跑":
		_fail("Run state did not activate")
		return
	Input.action_release("ui_right")
	Input.action_release("player_run")

	Input.action_press("player_crouch")
	await physics_frame
	if action.text != "动作：蹲伏":
		_fail("Crouch state did not activate")
		return
	Input.action_release("player_crouch")

	Input.action_press("player_crawl")
	await physics_frame
	if action.text != "动作：爬行":
		_fail("Crawl state did not activate")
		return
	Input.action_release("player_crawl")

	Input.action_press("player_jump")
	await physics_frame
	if action.text != "动作：跳跃":
		_fail("Jump state did not activate")
		return
	Input.action_release("player_jump")

	print("SMOKE_OK: concealment plus run, jump, crouch and crawl states")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
