extends Node2D

@export var player_path: NodePath
@export var ripple_spacing := 34.0
@export var ripple_lifetime := 1.15
@export var ripple_radius := 48.0
@export var max_ripples := 18

@onready var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D

var _ripples: Array[Dictionary] = []
var _last_player_position := Vector2.INF
var _distance_since_ripple := 0.0
var _was_surface_swimming := false


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(delta: float) -> void:
	for index: int in range(_ripples.size() - 1, -1, -1):
		var ripple: Dictionary = _ripples[index]
		ripple["age"] = float(ripple["age"]) + delta
		if float(ripple["age"]) >= ripple_lifetime:
			_ripples.remove_at(index)

	if not is_instance_valid(player):
		queue_redraw()
		return

	var swimming := bool(player.get("surface_swimming")) and not bool(player.get("is_dead"))
	if not swimming:
		_last_player_position = Vector2.INF
		_distance_since_ripple = 0.0
		_was_surface_swimming = false
		queue_redraw()
		return

	if not _was_surface_swimming:
		_spawn_ripple(player.global_position, 1.15)
		_last_player_position = player.global_position
		_was_surface_swimming = true

	var travelled := 0.0 if _last_player_position == Vector2.INF else player.global_position.distance_to(_last_player_position)
	_last_player_position = player.global_position
	if player.velocity.length_squared() > 4.0:
		_distance_since_ripple += travelled
		while _distance_since_ripple >= ripple_spacing:
			_distance_since_ripple -= ripple_spacing
			_spawn_ripple(player.global_position - player.velocity.normalized() * 18.0)
	queue_redraw()


func get_ripple_count() -> int:
	return _ripples.size()


func _spawn_ripple(world_position: Vector2, scale := 1.0) -> void:
	_ripples.append({"position": world_position, "age": 0.0, "scale": scale})
	if _ripples.size() > max_ripples:
		_ripples.pop_front()


func _draw() -> void:
	for ripple: Dictionary in _ripples:
		var progress := clampf(float(ripple["age"]) / maxf(ripple_lifetime, 0.01), 0.0, 1.0)
		var scale := float(ripple["scale"])
		var radius := lerpf(7.0, ripple_radius * scale, progress)
		var alpha := sin(progress * PI) * (1.0 - progress) * 0.70
		_draw_ellipse(to_local(Vector2(ripple["position"])), radius, radius * 0.38, Color(0.70, 0.96, 1.0, alpha), 5.0)


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in range(33):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)
