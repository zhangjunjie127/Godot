extends Node2D

var player: CharacterBody2D

var _bubbles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _trail_seconds := 0.0
var _mouth_seconds := 0.0
var _last_direction := Vector2.RIGHT


func _ready() -> void:
	_rng.seed = 20260828
	_mouth_seconds = _rng.randf_range(2.4, 5.2)


func set_player(value: CharacterBody2D) -> void:
	player = value
	if player == null:
		_bubbles.clear()
		queue_redraw()


func get_bubble_count() -> int:
	return _bubbles.size()


func record_swim(direction: Vector2, delta: float) -> void:
	if player == null or direction.length_squared() <= 0.01:
		return
	_last_direction = direction.normalized()
	_trail_seconds += delta
	while _trail_seconds >= 0.14:
		_trail_seconds -= 0.14
		_spawn_trail(_last_direction)


func _process(delta: float) -> void:
	_update_bubbles(delta)
	if player == null or not player.water_mode or player.is_dead:
		queue_redraw()
		return

	_mouth_seconds -= delta
	if _mouth_seconds <= 0.0:
		_spawn_mouth(_last_direction)
		_mouth_seconds = _rng.randf_range(2.4, 5.2)
	queue_redraw()


func _spawn_trail(direction: Vector2) -> void:
	var base := to_local(player.global_position) - direction * 17.0 + Vector2(0.0, -20.0)
	_spawn_bubble(base + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0)), 1.4, 1.2)


func _spawn_mouth(direction: Vector2) -> void:
	var base := to_local(player.global_position) + direction * 12.0 + Vector2(0.0, -31.0)
	for _index: int in range(_rng.randi_range(2, 4)):
		_spawn_bubble(base + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)), _rng.randf_range(1.4, 2.6), _rng.randf_range(1.5, 2.4))


func _spawn_bubble(position_value: Vector2, radius: float, lifetime: float) -> void:
	_bubbles.append({
		"position": position_value,
		"radius": radius,
		"age": 0.0,
		"lifetime": lifetime,
		"rise": _rng.randf_range(16.0, 28.0),
		"drift": _rng.randf_range(-4.0, 4.0),
	})


func _update_bubbles(delta: float) -> void:
	for index: int in range(_bubbles.size() - 1, -1, -1):
		var bubble: Dictionary = _bubbles[index]
		bubble["age"] = float(bubble["age"]) + delta
		if float(bubble["age"]) >= float(bubble["lifetime"]):
			_bubbles.remove_at(index)
			continue
		bubble["position"] = (bubble["position"] as Vector2) + Vector2(float(bubble["drift"]), -float(bubble["rise"])) * delta
		_bubbles[index] = bubble


func _draw() -> void:
	for bubble: Dictionary in _bubbles:
		var progress := float(bubble["age"]) / float(bubble["lifetime"])
		var alpha := 0.74 * (1.0 - progress)
		var bubble_position := bubble["position"] as Vector2
		var radius := float(bubble["radius"]) * (1.0 + progress * 0.35)
		draw_circle(bubble_position, radius, Color(0.70, 0.96, 1.0, alpha))
		draw_circle(bubble_position + Vector2(-radius * 0.28, -radius * 0.30), radius * 0.30, Color(1.0, 1.0, 1.0, alpha * 0.9))
