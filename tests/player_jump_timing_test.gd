extends SceneTree

const TAKEOFF_PROGRESS := 4.0 / 14.0
const LANDING_PROGRESS := 11.0 / 14.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")

	if player.jump_duration < 0.75:
		_fail("The 16-frame jump is compressed into an unreadably short duration")
		return

	player._start_jump()
	player._update_jump(player.jump_duration * (TAKEOFF_PROGRESS - 0.05))
	if not is_zero_approx(player._jump_offset):
		_fail("Jump anticipation frames leave the ground before takeoff")
		return

	player._start_jump()
	var airborne_midpoint := (TAKEOFF_PROGRESS + LANDING_PROGRESS) * 0.5
	player._update_jump(player.jump_duration * airborne_midpoint)
	if player._jump_offset < player.jump_height * 0.98:
		_fail("Jump airborne frames do not reach the visual apex")
		return

	player._start_jump()
	player._update_jump(player.jump_duration * (LANDING_PROGRESS + 0.05))
	if not is_zero_approx(player._jump_offset):
		_fail("Jump landing frames remain suspended above the ground")
		return

	print("PLAYER_JUMP_TIMING_OK")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
