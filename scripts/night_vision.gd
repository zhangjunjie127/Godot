extends ColorRect

const NO_TORCH_RADIUS := 41.0
const TORCH_RADIUS := 82.0
const NO_TORCH_SOFTNESS := 30.0
const TORCH_SOFTNESS := 56.0
const OUTER_ALPHA := 0.75
const NO_TORCH_INNER_ALPHA := 0.55
const TORCH_INNER_ALPHA := 0.20

@export var player_path: NodePath
@export var environment_path: NodePath

@onready var player: Node2D = get_node_or_null(player_path) as Node2D
@onready var environment: CanvasModulate = get_node_or_null(environment_path) as CanvasModulate

var is_night := false
var torch_equipped := false
var current_radius := NO_TORCH_RADIUS
var current_softness := NO_TORCH_SOFTNESS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_sync_material()


func _process(_delta: float) -> void:
	if not visible or player == null or material == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_position := get_viewport().get_canvas_transform() * player.global_position
	material.set_shader_parameter("center_uv", screen_position / viewport_size)
	material.set_shader_parameter("viewport_size", viewport_size)
	if environment != null:
		material.set_shader_parameter("night_tint", Vector3(environment.color.r, environment.color.g, environment.color.b))


func set_night_state(value: bool, has_torch: bool) -> void:
	is_night = value
	torch_equipped = value and has_torch
	current_radius = TORCH_RADIUS if torch_equipped else NO_TORCH_RADIUS
	current_softness = TORCH_SOFTNESS if torch_equipped else NO_TORCH_SOFTNESS
	visible = is_night
	_sync_material()


func get_visibility_radius(has_torch: bool) -> float:
	return TORCH_RADIUS if has_torch else NO_TORCH_RADIUS


func _sync_material() -> void:
	if material == null:
		return
	material.set_shader_parameter("radius_px", current_radius)
	material.set_shader_parameter("softness_px", current_softness)
	material.set_shader_parameter("outer_alpha", OUTER_ALPHA)
	material.set_shader_parameter("no_torch_inner_alpha", NO_TORCH_INNER_ALPHA)
	material.set_shader_parameter("torch_inner_alpha", TORCH_INNER_ALPHA)
	material.set_shader_parameter("torch_equipped", torch_equipped)
