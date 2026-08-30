extends SceneTree

const IDLE_TEXTURE := preload("res://assets/characters/player_male_idle_relaxed/sheet-transparent.png")
const WALK_TEXTURE := preload("res://assets/characters/player_male_walk/sheet-transparent.png")
const FRAME_COLUMNS := 12
const DIRECTION_ROWS := 8
const CELL_SIZE := 128
const FEET_BASELINE := 117


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var idle_image := IDLE_TEXTURE.get_image()
	var walk_image := WALK_TEXTURE.get_image()
	var idle_height_total := 0.0
	var walk_height_total := 0.0
	for row: int in range(DIRECTION_ROWS):
		var minimum_height := CELL_SIZE
		var maximum_height := 0
		for column: int in range(FRAME_COLUMNS):
			var idle_rect := _frame_bounds(idle_image, column, row)
			var walk_rect := _frame_bounds(walk_image, column, row)
			if idle_rect.size == Vector2i.ZERO:
				_fail("Idle frame is empty at row %d column %d" % [row, column])
				return
			if idle_rect.end.y != FEET_BASELINE:
				_fail("Idle feet baseline drifted to %d at row %d column %d" % [idle_rect.end.y, row, column])
				return
			minimum_height = mini(minimum_height, idle_rect.size.y)
			maximum_height = maxi(maximum_height, idle_rect.size.y)
			idle_height_total += idle_rect.size.y
			walk_height_total += walk_rect.size.y
		if maximum_height - minimum_height > 2:
			_fail("Idle body scale changes within direction row %d: %d to %d pixels" % [row, minimum_height, maximum_height])
			return

	var idle_mean_height := idle_height_total / float(FRAME_COLUMNS * DIRECTION_ROWS)
	var walk_mean_height := walk_height_total / float(FRAME_COLUMNS * DIRECTION_ROWS)
	var height_ratio := idle_mean_height / walk_mean_height
	if height_ratio < 0.96 or height_ratio > 1.04:
		_fail("Idle and walk body scales differ: %.3f" % height_ratio)
		return

	print("IDLE_ANIMATION_OK: complete lower body, stable scale and shared feet baseline")
	quit()


func _frame_bounds(image: Image, column: int, row: int) -> Rect2i:
	return image.get_region(Rect2i(column * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)).get_used_rect()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
