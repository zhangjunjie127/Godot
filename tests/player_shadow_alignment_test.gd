extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var directions := [
		Vector2.ZERO,
		Vector2.DOWN,
		Vector2(1.0, 1.0),
		Vector2.RIGHT,
		Vector2(1.0, -1.0),
		Vector2.UP,
		Vector2(-1.0, -1.0),
		Vector2.LEFT,
		Vector2(-1.0, 1.0),
	]

	for direction: Vector2 in directions:
		player._movement_state = "站立" if direction == Vector2.ZERO else "行走"
		player._update_sprite(direction, 0.0)
		if not _feet_touch_shadow(player):
			_fail("Player feet do not touch the shadow for direction %s" % direction)
			return

	for pose: Dictionary in [
		{"state": "蹲伏", "direction": Vector2.ZERO},
		{"state": "趴下", "direction": Vector2.ZERO},
		{"state": "爬行", "direction": Vector2.RIGHT},
	]:
		player._movement_state = String(pose["state"])
		player._update_sprite(pose["direction"], 0.0)
		if not _feet_touch_shadow(player):
			_fail("Player feet do not touch the shadow for state %s" % pose["state"])
			return

	print("PLAYER_SHADOW_ALIGNMENT_OK")
	scene.free()
	await process_frame
	quit()


func _frame_feet(sprite: Sprite2D) -> Vector2:
	var frame_size := Vector2i(sprite.texture.get_width() / sprite.hframes, sprite.texture.get_height() / sprite.vframes)
	var image := sprite.texture.get_image()
	var frame_region := Rect2i(sprite.frame_coords * frame_size, frame_size)
	var bounds := image.get_region(frame_region).get_used_rect()
	var local_feet := Vector2(
		float(bounds.position.x + bounds.end.x - 1) * 0.5 - float(frame_size.x) * 0.5,
		float(bounds.end.y) - float(frame_size.y) * 0.5
	)
	return sprite.position + local_feet * sprite.scale


func _feet_touch_shadow(player: CharacterBody2D) -> bool:
	var feet := _frame_feet(player.sprite)
	var shadow_top: float = player.SHADOW_CENTER.y - player.SHADOW_RADIUS * player.SHADOW_VERTICAL_SCALE
	var shadow_bottom: float = player.SHADOW_CENTER.y + player.SHADOW_RADIUS * player.SHADOW_VERTICAL_SCALE
	return absf(feet.x - player.SHADOW_CENTER.x) <= 4.0 and feet.y >= shadow_top and feet.y <= shadow_bottom


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
