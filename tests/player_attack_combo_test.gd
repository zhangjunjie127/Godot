extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")

	var has_left_mouse := false
	for event: InputEvent in InputMap.action_get_events("player_attack"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_left_mouse = true
	if not has_left_mouse:
		_fail("Attack is not bound to the left mouse button")
		return
	if not player.has_method("get_queued_attack_count"):
		_fail("Attack input has no queued combo support")
		return

	player.start_attack()
	player.start_attack()
	if not player._is_attacking or player.get_queued_attack_count() != 1:
		_fail("A repeated click did not queue the next punch")
		return
	player._attack_elapsed = player.attack_duration * 0.5
	var first_punch_frame: int = player._animation_frame("attack", false)
	if first_punch_frame < 0 or first_punch_frame >= 8:
		_fail("One click did not play exactly one eight-frame punch")
		return

	player._update_attack(player.attack_duration)
	if not player._is_attacking or player.get_queued_attack_count() != 0:
		_fail("Queued punch did not start immediately after the first punch")
		return
	player._attack_elapsed = player.attack_duration * 0.5
	var second_punch_frame: int = player._animation_frame("attack", false)
	if second_punch_frame < 8 or second_punch_frame >= 16:
		_fail("Consecutive clicks did not alternate to the other hand")
		return

	player._update_attack(player.attack_duration)
	if player._is_attacking:
		_fail("Attack did not return control after the queued punches ended")
		return

	player.start_attack()
	player.start_attack()
	var move_event := InputEventKey.new()
	move_event.physical_keycode = KEY_W
	move_event.pressed = true
	player._input(move_event)
	if player._is_attacking or player.get_queued_attack_count() != 0:
		_fail("Movement input did not interrupt the attack and clear its queued combo")
		return

	player.start_attack()
	var attack_event := InputEventMouseButton.new()
	attack_event.button_index = MOUSE_BUTTON_LEFT
	attack_event.pressed = true
	player._input(attack_event)
	if not player._is_attacking:
		_fail("Another attack click incorrectly interrupted the combo")
		return

	print("PLAYER_ATTACK_COMBO_OK")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
