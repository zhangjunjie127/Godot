extends Control

@export var map_texture: Texture2D
@export var player_path: NodePath
@export var world_size := Vector2(2048.0, 2048.0)

@onready var player: Node2D = get_node_or_null(player_path) as Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	if map_texture != null:
		draw_texture_rect(map_texture, map_rect, false, Color(0.86, 0.90, 0.82, 1.0))
	draw_rect(map_rect, Color(0.78, 0.83, 0.59, 0.9), false, 2.0)
	if player == null:
		return
	var normalized := Vector2(
		clampf(player.global_position.x / maxf(world_size.x, 1.0), 0.0, 1.0),
		clampf(player.global_position.y / maxf(world_size.y, 1.0), 0.0, 1.0)
	)
	var marker_position := normalized * size
	draw_circle(marker_position, 5.0, Color(0.08, 0.12, 0.07, 0.85))
	draw_circle(marker_position, 3.2, Color(1.0, 0.83, 0.20, 1.0))
