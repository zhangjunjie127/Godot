extends SceneTree

const ACTION_PATHS := {
	"idle_relaxed": "res://assets/characters/player_male_idle_relaxed/sheet-transparent.png",
	"jump": "res://assets/characters/player_male_jump/sheet-transparent.png",
	"run": "res://assets/characters/player_male_run/sheet-transparent.png",
	"walk": "res://assets/characters/player_male_walk/sheet-transparent.png",
	"attack": "res://assets/characters/player_male_attack/sheet-transparent.png",
}
const FRAME_SIZE := 128
const FRAME_COLUMNS := 16
const DIRECTION_ROWS := 8
const FEET_BASELINE := 117


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for animation: String in ACTION_PATHS:
		var texture := load(ACTION_PATHS[animation]) as Texture2D
		if texture == null or texture.get_size() != Vector2(FRAME_SIZE * FRAME_COLUMNS, FRAME_SIZE * DIRECTION_ROWS):
			_fail("Invalid 16x8 sheet for %s" % animation)
			return
		var image := texture.get_image()
		for row: int in range(DIRECTION_ROWS):
			for column: int in range(FRAME_COLUMNS):
				var bounds := _frame(image, column, row).get_used_rect()
				if bounds.size == Vector2i.ZERO or bounds.end.y != FEET_BASELINE:
					_fail("Invalid frame or feet baseline for %s row %d column %d" % [animation, row, column])
					return
		for pair: Vector2i in [Vector2i(3, 5), Vector2i(2, 6), Vector2i(1, 7)]:
			for column: int in range(FRAME_COLUMNS):
				var source := _frame(image, column, pair.x)
				source.flip_x()
				if source.get_used_rect() != _frame(image, column, pair.y).get_used_rect():
					_fail("Mirrored direction mismatch for %s rows %d/%d" % [animation, pair.x, pair.y])
					return

	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")
	for animation: String in ACTION_PATHS:
		if player._animation_frame_count(animation) != FRAME_COLUMNS or player._animation_texture(animation).resource_path != ACTION_PATHS[animation]:
			_fail("Player runtime mapping is incorrect for %s" % animation)
			return
	if player._animation_frame_count("crawl_move") != 12:
		_fail("Legacy 12-frame actions were changed")
		return

	print("PLAYER_16_FRAME_ANIMATION_OK: five actions, eight directions and editable sheets")
	scene.free()
	await process_frame
	quit()


func _frame(image: Image, column: int, row: int) -> Image:
	return image.get_region(Rect2i(column * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
