@tool
extends Node2D

@export var show_collision_debug := true:
	set(value):
		show_collision_debug = value
		queue_redraw()

@onready var map_preview: Sprite2D = $MapPreview


func _ready() -> void:
	map_preview.visible = Engine.is_editor_hint()
	set_process(Engine.is_editor_hint())
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_collision_debug:
		return
	var fill := Color(0.94, 0.12, 0.16, 0.22)
	var line := Color(1.0, 0.22, 0.20, 0.94)
	for child: Node in get_children():
		if not child is StaticBody2D:
			continue
		var body := child as StaticBody2D
		for shape_node: Node in body.get_children():
			var transform_value: Transform2D = body.transform * (shape_node as Node2D).transform
			if shape_node is CollisionPolygon2D:
				var polygon := PackedVector2Array()
				for point: Vector2 in (shape_node as CollisionPolygon2D).polygon:
					polygon.append(transform_value * point)
				if polygon.size() >= 3:
					draw_colored_polygon(polygon, fill)
					var outline := polygon.duplicate()
					outline.append(polygon[0])
					draw_polyline(outline, line, 3.0, true)
			elif shape_node is CollisionShape2D:
				_draw_shape((shape_node as CollisionShape2D).shape, transform_value, fill, line)


func _draw_shape(shape: Shape2D, transform_value: Transform2D, fill: Color, line: Color) -> void:
	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius * transform_value.get_scale().x
		var center := transform_value.origin
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 40, line, 3.0, true)
	elif shape is SegmentShape2D:
		var segment := shape as SegmentShape2D
		draw_line(transform_value * segment.a, transform_value * segment.b, line, 5.0, true)
	elif shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		var rect := Rect2(transform_value.origin - rectangle.size * 0.5, rectangle.size)
		draw_rect(rect, fill, true)
		draw_rect(rect, line, false, 3.0)
