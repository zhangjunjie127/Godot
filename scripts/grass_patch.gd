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
	draw_rect(rect, Color(0.16, 0.43, 0.20, 0.42))

	var columns := maxi(1, int(patch_size.x / 8.0))
	var rows := maxi(1, int(patch_size.y / 14.0))
	for row in range(rows):
		for column in range(columns):
			var x := rect.position.x + 4.0 + column * 8.0 + float((row * 5 + column * 3) % 5)
			var y := rect.position.y + 12.0 + row * 14.0 + float((column * 7) % 6)
			var blade_height := 9.0 + float((row * 3 + column * 5) % 8)
			var color := Color(0.25, 0.64, 0.28) if (row + column) % 2 == 0 else Color(0.38, 0.75, 0.32)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 3.0, y),
				Vector2(x, y - blade_height),
				Vector2(x + 3.0, y),
			]), color)


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_cover"):
		body.enter_cover(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_cover"):
		body.exit_cover(self)
