extends ColorRect

const NO_TORCH_RADIUS := 82.0
const TORCH_RADIUS := 164.0

@export var player_path: NodePath

@onready var player: Node2D = get_node_or_null(player_path) as Node2D

var is_night := false
var torch_equipped := false
var current_radius := NO_TORCH_RADIUS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	if not visible or player == null or material == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_position := get_viewport().get_canvas_transform() * player.global_position
	material.set_shader_parameter("center_uv", screen_position / viewport_size)
	material.set_shader_parameter("viewport_size", viewport_size)


func set_night_state(value: bool, has_torch: bool) -> void:
	is_night = value
	torch_equipped = value and has_torch
	current_radius = TORCH_RADIUS if torch_equipped else NO_TORCH_RADIUS
	visible = is_night
	if material != null:
		material.set_shader_parameter("radius_px", current_radius)


func get_visibility_radius(has_torch: bool) -> float:
	return TORCH_RADIUS if has_torch else NO_TORCH_RADIUS
