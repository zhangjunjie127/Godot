extends Node2D

const WORLD_SIZE := Vector2(6144.0, 6144.0)

@export var details_only := false


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if details_only:
		_draw_details()
		return

	# Placeholder only: one continuous drawing proves world scale before final layered art exists.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.47, 0.75, 0.39))

	# Broad regions keep the world readable without committing to final map art.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(1500, 0), Vector2(1280, 2100),
		Vector2(620, 3300), Vector2(0, 3600),
	]), Color(0.25, 0.56, 0.31))
	draw_rect(Rect2(4540, 0, 380, WORLD_SIZE.y), Color(0.86, 0.79, 0.45))
	draw_rect(Rect2(4920, 0, WORLD_SIZE.x - 4920, WORLD_SIZE.y), Color(0.22, 0.67, 0.76))

	# Offset lower edges and compressed ellipses create a 3/4 view without rotating 2D sprites.
	_draw_ellipse(Vector2(1040, 1206), Vector2(520, 300), Color(0.38, 0.66, 0.33))
	_draw_ellipse(Vector2(1040, 1190), Vector2(520, 284), Color(0.58, 0.82, 0.43))
	draw_polyline(PackedVector2Array([
		Vector2(680, 1548), Vector2(900, 1338), Vector2(1080, 1198),
		Vector2(1320, 988), Vector2(1540, 768),
	]), Color(0.48, 0.46, 0.28, 0.55), 84.0, true)
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


func _draw_details() -> void:
	for tree in [
		[Vector2(690, 910), 1.0], [Vector2(820, 820), 0.82],
		[Vector2(1370, 850), 0.9], [Vector2(1510, 1040), 1.1],
		[Vector2(720, 1360), 0.88], [Vector2(1440, 1390), 0.78],
	]:
		_draw_tree(tree[0], tree[1])
	for rock_position in [Vector2(780, 1190), Vector2(1310, 1280), Vector2(1190, 820)]:
		_draw_rock(rock_position)


func _draw_tree(position: Vector2, scale_factor: float) -> void:
	draw_set_transform(position + Vector2(10.0, 4.0) * scale_factor, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 28.0 * scale_factor, Color(0.08, 0.20, 0.11, 0.24))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(position + Vector2(-4.0, -29.0) * scale_factor, Vector2(8.0, 30.0) * scale_factor), Color(0.43, 0.30, 0.16))
	draw_circle(position + Vector2(0.0, -45.0) * scale_factor, 25.0 * scale_factor, Color(0.19, 0.49, 0.24))
	draw_circle(position + Vector2(-13.0, -39.0) * scale_factor, 19.0 * scale_factor, Color(0.25, 0.61, 0.28))
	draw_circle(position + Vector2(14.0, -38.0) * scale_factor, 20.0 * scale_factor, Color(0.31, 0.68, 0.31))


func _draw_rock(position: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		position + Vector2(-18, 0), position + Vector2(15, 0),
		position + Vector2(11, 10), position + Vector2(-13, 10),
	]), Color(0.34, 0.40, 0.34))
	draw_colored_polygon(PackedVector2Array([
		position + Vector2(-18, 0), position + Vector2(-9, -13),
		position + Vector2(10, -11), position + Vector2(15, 0),
	]), Color(0.60, 0.66, 0.53))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
