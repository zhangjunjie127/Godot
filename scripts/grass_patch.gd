extends Area2D

@export var patch_size := Vector2(180.0, 96.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = patch_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-patch_size * 0.5, patch_size)
	_draw_ellipse(Vector2(3.0, 7.0), patch_size * Vector2(0.52, 0.34), Color(0.08, 0.24, 0.12, 0.24))
	_draw_ellipse(Vector2.ZERO, patch_size * Vector2(0.5, 0.32), Color(0.16, 0.43, 0.20, 0.42))

	var columns := maxi(1, int(patch_size.x / 8.0))
	var rows := maxi(1, int(patch_size.y / 14.0))
	for row in range(rows):
		var depth := float(row) / float(maxi(rows - 1, 1))
		var row_width := lerpf(patch_size.x * 0.72, patch_size.x, depth)
		for column in range(columns):
			var x := -row_width * 0.5 + 4.0 + column * row_width / float(columns) + float((row * 5 + column * 3) % 5)
			var y := rect.position.y + 18.0 + row * 12.0 + float((column * 7) % 5)
			var blade_height := 9.0 + float((row * 3 + column * 5) % 8)
			var color := Color(0.25, 0.64, 0.28) if (row + column) % 2 == 0 else Color(0.38, 0.75, 0.32)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 3.0, y),
				Vector2(x, y - blade_height),
				Vector2(x + 3.0, y),
			]), color)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_cover"):
		body.enter_cover(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_cover"):
		body.exit_cover(self)
