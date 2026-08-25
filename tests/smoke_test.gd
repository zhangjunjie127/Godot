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

	player.global_position = grass.global_position
	await physics_frame
	await physics_frame
	if status.text != "状态：草丛隐蔽":
		push_error("Player did not enter concealment")
		quit(1)
		return

	player.global_position = Vector2(2000.0, 2000.0)
	await physics_frame
	await physics_frame
	if status.text != "状态：可见":
		push_error("Player did not leave concealment")
		quit(1)
		return

	print("SMOKE_OK: movement scene, grass concealment and HUD state")
	quit()
