extends SceneTree

const FRAME_DURATION := 0.125
const ACTION_DURATION := 2.0
const MOTION_START_FRAME := 2
const MOTION_DURATION := 1.75
const PUNCH_DURATION := 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")

	if not is_equal_approx(player.jump_duration, MOTION_DURATION):
		_fail("The jump must play frames 2-15 at eight frames per second")
		return
	if not is_equal_approx(player.attack_duration, PUNCH_DURATION):
		_fail("Each eight-frame punch must last one second")
		return

	if player.get_movement_loop_start_frame("idle_relaxed") != 0:
		_fail("Idle must retain all 16 frames")
		return
	player._animation_elapsed = ACTION_DURATION - 0.001
	if player._animation_frame("idle_relaxed", false) != 15:
		_fail("Idle does not use its final frame before the two-second loop")
		return
	player._animation_elapsed = ACTION_DURATION
	if player._animation_frame("idle_relaxed", false) != 0:
		_fail("Idle does not loop after two seconds")
		return

	for animation: String in ["walk", "run"]:
		if player.get_movement_loop_start_frame(animation) != MOTION_START_FRAME:
			_fail("%s does not skip its two standing setup frames" % animation)
			return
		player._animation_elapsed = FRAME_DURATION - 0.001
		if player._animation_frame(animation, true) != MOTION_START_FRAME:
			_fail("%s advances before 0.125 seconds" % animation)
			return
		player._animation_elapsed = FRAME_DURATION
		if player._animation_frame(animation, true) != MOTION_START_FRAME + 1:
			_fail("%s is not playing at eight frames per second" % animation)
			return
		player._animation_elapsed = MOTION_DURATION - 0.001
		if player._animation_frame(animation, true) != 15:
			_fail("%s does not use its final movement frame" % animation)
			return
		player._animation_elapsed = MOTION_DURATION
		if player._animation_frame(animation, true) != MOTION_START_FRAME:
			_fail("%s does not loop continuously after 1.75 seconds" % animation)
			return

	player._jump_elapsed = 0.0
	if player._animation_frame("jump", false) != MOTION_START_FRAME:
		_fail("Jump starts on a standing setup frame")
		return
	player._jump_elapsed = FRAME_DURATION
	if player._animation_frame("jump", false) != MOTION_START_FRAME + 1:
		_fail("Jump is not playing at eight frames per second")
		return
	player._jump_elapsed = MOTION_DURATION - 0.001
	if player._animation_frame("jump", false) != 15:
		_fail("Jump does not reach its final frame")
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

	print("PLAYER_ANIMATION_TIMING_OK: idle 16 frames; motion 14 frames; 8 FPS")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
