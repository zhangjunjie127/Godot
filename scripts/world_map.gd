extends Node2D

const WORLD_SIZE := Vector2(6144.0, 6144.0)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Placeholder only: one continuous drawing proves world scale before final layered art exists.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.47, 0.75, 0.39))

	# Broad regions keep the world readable without committing to final map art.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(1500, 0), Vector2(1280, 2100),
		Vector2(620, 3300), Vector2(0, 3600),
	]), Color(0.25, 0.56, 0.31))
	draw_rect(Rect2(4540, 0, 380, WORLD_SIZE.y), Color(0.86, 0.79, 0.45))
	draw_rect(Rect2(4920, 0, WORLD_SIZE.x - 4920, WORLD_SIZE.y), Color(0.22, 0.67, 0.76))

	# The first playable clearing around the spawn point.
	draw_circle(Vector2(1040, 1190), 470.0, Color(0.58, 0.82, 0.43))
	draw_polyline(PackedVector2Array([
		Vector2(680, 1540), Vector2(900, 1330), Vector2(1080, 1190),
		Vector2(1320, 980), Vector2(1540, 760),
	]), Color(0.76, 0.68, 0.40), 74.0, true)

	var random := RandomNumberGenerator.new()
	random.seed = 20260825
	for index in range(260):
		var point := Vector2(
			random.randf_range(80.0, 4460.0),
			random.randf_range(80.0, WORLD_SIZE.y - 80.0)
		)
		var radius := random.randf_range(2.0, 5.0)
		var color := Color(0.86, 0.91, 0.47, 0.85) if index % 3 == 0 else Color(0.31, 0.64, 0.31, 0.75)
		draw_circle(point, radius, color)
