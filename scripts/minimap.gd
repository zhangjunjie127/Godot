extends Control

@export var map_texture: Texture2D
@export var player_path: NodePath
@export var world_size := Vector2(2048.0, 2048.0)
@export var world_mode := false

const WORLD_GRID := Vector2i(3, 3)
const CURRENT_BOARD := Vector2i(0, 1)

@onready var player: Node2D = get_node_or_null(player_path) as Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world_mode:
		_draw_world_map()
		return
	_draw_local_map()


func _draw_local_map() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	if map_texture != null:
		draw_texture_rect(map_texture, map_rect, false, Color(0.92, 0.93, 0.91, 1.0))
	draw_rect(map_rect, Color(0.72, 0.56, 0.28, 0.94), false, 2.0)
	if player == null:
		return
	var normalized := Vector2(
		clampf(player.global_position.x / maxf(world_size.x, 1.0), 0.0, 1.0),
		clampf(player.global_position.y / maxf(world_size.y, 1.0), 0.0, 1.0)
	)
	var marker_position := normalized * size
	draw_circle(marker_position, 5.0, Color(0.035, 0.045, 0.055, 0.9))
	draw_circle(marker_position, 3.2, Color(1.0, 0.83, 0.20, 1.0))


func _draw_world_map() -> void:
	var ocean_rect := Rect2(Vector2.ZERO, size)
	draw_rect(ocean_rect, Color(0.055, 0.20, 0.26, 1.0))
	var margin := minf(size.x, size.y) * 0.09
	var gap := maxf(5.0, minf(size.x, size.y) * 0.012)
	var board_size := (size - Vector2.ONE * margin * 2.0 - Vector2(gap * 2.0, gap * 2.0)) / Vector2(WORLD_GRID)
	var font := ThemeDB.fallback_font
	for row: int in range(WORLD_GRID.y):
		for column: int in range(WORLD_GRID.x):
			var board := Vector2i(column, row)
			var board_position := Vector2.ONE * margin + Vector2(column, row) * (board_size + Vector2.ONE * gap)
			var board_rect := Rect2(board_position, board_size)
			if board == CURRENT_BOARD and map_texture != null:
				draw_texture_rect(map_texture, board_rect, false, Color(0.92, 0.93, 0.91, 1.0))
			else:
				var variation := float((column + row) % 3) * 0.035
				draw_rect(board_rect, Color(0.12 + variation, 0.15 + variation, 0.17 + variation, 1.0))
				draw_circle(board_rect.get_center(), minf(board_size.x, board_size.y) * 0.23, Color(0.20, 0.23, 0.24, 0.72))
			draw_rect(board_rect, Color(0.58, 0.47, 0.29, 0.88), false, 2.0)
			if board == CURRENT_BOARD:
				draw_string(font, board_rect.position + Vector2(8.0, 20.0), "西部台地", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.94, 0.68, 1.0))
			else:
				draw_string(font, board_rect.get_center() + Vector2(-27.0, 5.0), "未探索", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.68, 0.70, 0.72, 0.78))

	for index: int in range(4):
		var offset := margin * (float(index) + 1.0) / 5.0
		draw_line(Vector2(offset, offset), Vector2(size.x - offset, offset), Color(0.55, 0.47, 0.33, 0.26), 1.0)
		draw_line(Vector2(offset, size.y - offset), Vector2(size.x - offset, size.y - offset), Color(0.55, 0.47, 0.33, 0.26), 1.0)

	if player == null:
		return
	var normalized := Vector2(
		clampf(player.global_position.x / maxf(world_size.x, 1.0), 0.0, 1.0),
		clampf(player.global_position.y / maxf(world_size.y, 1.0), 0.0, 1.0)
	)
	var current_position := Vector2.ONE * margin + Vector2(CURRENT_BOARD) * (board_size + Vector2.ONE * gap)
	var marker_position := current_position + normalized * board_size
	draw_circle(marker_position, 8.0, Color(0.025, 0.035, 0.045, 0.9))
	draw_circle(marker_position, 5.0, Color(1.0, 0.80, 0.16, 1.0))


func get_board_count() -> int:
	return WORLD_GRID.x * WORLD_GRID.y if world_mode else 1
