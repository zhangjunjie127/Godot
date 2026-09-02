@tool
extends Node2D
class_name GroundShadow

const DEFAULT_MATERIAL := preload("res://art/ground_shadow_material.tres")

@export_group("Ground Shadow / 地面阴影")
@export var shadow_enabled := true:
	set(value):
		shadow_enabled = value
		_refresh()
@export var center := Vector2.ZERO:
	set(value):
		center = value
		_refresh()
@export_range(1.0, 256.0, 1.0) var radius := 24.0:
	set(value):
		radius = value
		_refresh()
@export var ellipse_scale := Vector2(1.0, 0.34):
	set(value):
		ellipse_scale = value
		_refresh()
@export_range(0.0, 1.0, 0.01) var strength := 1.0:
	set(value):
		strength = value
		_refresh()
@export var shadow_material: Material = DEFAULT_MATERIAL:
	set(value):
		shadow_material = value
		_refresh()


func _ready() -> void:
	z_index = -1
	show_behind_parent = true
	_refresh()


func configure(new_center: Vector2, new_radius: float, new_scale: Vector2, new_strength: float, enabled: bool) -> void:
	center = new_center
	radius = new_radius
	ellipse_scale = new_scale
	strength = clampf(new_strength, 0.0, 1.0)
	shadow_enabled = enabled
	visible = enabled
	queue_redraw()


func _draw() -> void:
	if not shadow_enabled or radius <= 0.0:
		return
	draw_set_transform(center, 0.0, ellipse_scale)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, strength))
	draw_set_transform(Vector2.ZERO)


func _refresh() -> void:
	visible = shadow_enabled
	material = shadow_material
	if is_inside_tree():
		queue_redraw()
