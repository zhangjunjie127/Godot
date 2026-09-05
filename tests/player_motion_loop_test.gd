extends SceneTree

const MOTION_ACTIONS := ["walk", "run"]
const FRAME_SIZE := 128
const DIRECTION_ROWS := 8


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")

	if player.move_speed != 170.0 or player.run_speed != 280.0 or player.crouch_speed != 82.0 or player.crawl_speed != 46.0:
		_fail("Normal land movement speeds were not restored")
		return
	if not player.has_method("get_movement_loop_start_frame"):
		_fail("Movement animations do not expose a stable looping range")
		return

	for animation: String in MOTION_ACTIONS:
		var start_frame: int = player.get_movement_loop_start_frame(animation)
		if start_frame != 0:
			_fail("%s does not play all 16 source frames" % animation)
			return
		var texture := player._animation_texture(animation) as Texture2D
		var image := texture.get_image()
		for row: int in range(DIRECTION_ROWS):
			for column: int in range(start_frame, player._animation_frame_count(animation)):
				var bounds := image.get_region(Rect2i(column * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)).get_used_rect()
				if bounds.end.y != 117:
					_fail("%s row %d frame %d lost the shared feet baseline" % [animation, row, column])
					return

	player._set_movement_state(player.STATE_RUN)
	player._active_animation = ""
	var seen_wrap := false
	var previous_frame := -1
	for _sample: int in range(48):
		player._update_sprite(Vector2.RIGHT, 0.125)
		var current_frame: int = player.sprite.frame_coords.x
		if player.sprite.scale != player.CHARACTER_SCALE:
			_fail("Sustained movement changed the character scale")
			return
		if previous_frame > current_frame:
			seen_wrap = true
		previous_frame = current_frame
	if not seen_wrap:
		_fail("Sustained movement did not loop continuously")
		return

	player._set_movement_state(player.STATE_IDLE)
	player._update_sprite(Vector2.ZERO, 0.0)
	if player.sprite.texture.resource_path != "res://assets/characters/player_male_idle_relaxed/sheet-transparent.png":
		_fail("Releasing movement did not return to standing idle")
		return

	print("PLAYER_MOTION_LOOP_OK")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
