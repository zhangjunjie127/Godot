extends SceneTree

const FRAME_DURATION := 0.125
const ACTION_DURATION := 2.0
const PUNCH_DURATION := 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")

	if not is_equal_approx(player.jump_duration, ACTION_DURATION):
		_fail("The 16-frame jump must last two seconds")
		return
	if not is_equal_approx(player.attack_duration, PUNCH_DURATION):
		_fail("Each eight-frame punch must last one second")
		return

	for animation: String in ["idle_relaxed", "walk", "run"]:
		var moving := animation != "idle_relaxed"
		if player.get_movement_loop_start_frame(animation) != 0:
			_fail("%s does not play all 16 frames" % animation)
			return
		player._animation_elapsed = FRAME_DURATION - 0.001
		if player._animation_frame(animation, moving) != 0:
			_fail("%s advances before 0.125 seconds" % animation)
			return
		player._animation_elapsed = FRAME_DURATION
		if player._animation_frame(animation, moving) != 1:
			_fail("%s is not playing at eight frames per second" % animation)
			return
		player._animation_elapsed = ACTION_DURATION - 0.001
		if player._animation_frame(animation, moving) != 15:
			_fail("%s does not use its final frame before the two-second loop" % animation)
			return
		player._animation_elapsed = ACTION_DURATION
		if player._animation_frame(animation, moving) != 0:
			_fail("%s does not loop after two seconds" % animation)
			return

	player.start_attack()
	player._attack_elapsed = FRAME_DURATION
	if player._animation_frame("attack", false) != 1:
		_fail("Attack frames are not playing at eight frames per second")
		return
	player._attack_elapsed = PUNCH_DURATION - 0.001
	if player._animation_frame("attack", false) != 7:
		_fail("One click does not finish all eight frames in one second")
		return

	print("PLAYER_ANIMATION_TIMING_OK: 16 frames / 2 seconds / 8 FPS")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
