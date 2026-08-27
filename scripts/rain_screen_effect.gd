extends Control

const TRAIL_DIRECTION_Y := -1.0

@export var random_seed := 20260827

var intensity := 0.0
var _spawn_progress := 0.0
var _drops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = random_seed
	visible = false


func set_intensity(value: float) -> void:
	var previous_intensity := intensity
	intensity = clampf(value, 0.0, 1.0)
	if previous_intensity <= 0.001 and intensity > 0.001:
		_spawn_progress = maxf(_spawn_progress, 0.75)
	visible = intensity > 0.001 or not _drops.is_empty()


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	_spawn_progress += delta * intensity * 6.0
	while _spawn_progress >= 1.0 and _drops.size() < 24:
		_spawn_progress -= 1.0
		_drops.append(_new_drop())

	for drop: Dictionary in _drops:
		drop["age"] = float(drop["age"]) + delta
		var position: Vector2 = drop["position"]
		position.y += float(drop["slide_speed"]) * delta
		drop["position"] = position
	for index: int in range(_drops.size() - 1, -1, -1):
		if float(_drops[index]["age"]) >= float(_drops[index]["duration"]):
			_drops.remove_at(index)
	visible = intensity > 0.001 or not _drops.is_empty()
	queue_redraw()


func _new_drop() -> Dictionary:
	var viewport_size := Vector2(maxf(size.x, 640.0), maxf(size.y, 360.0))
	return {
		"position": Vector2(_rng.randf_range(10.0, viewport_size.x - 10.0), _rng.randf_range(8.0, viewport_size.y * 0.82)),
		"radius": _rng.randf_range(1.1, 2.9),
		"age": 0.0,
		"duration": _rng.randf_range(2.5, 5.2),
		"slide_speed": _rng.randf_range(2.0, 8.0),
		"trail": _rng.randf() < 0.62,
		"trail_length": _rng.randf_range(12.0, 28.0),
	}


func _draw() -> void:
	for drop: Dictionary in _drops:
		var progress := clampf(float(drop["age"]) / float(drop["duration"]), 0.0, 1.0)
		var fade := sin(progress * PI)
		var position: Vector2 = drop["position"]
		var radius := float(drop["radius"])
		draw_set_transform(position, 0.0, Vector2(0.72, 1.0))
		draw_circle(Vector2.ZERO, radius, Color(0.58, 0.78, 0.86, 0.065 * fade))
		draw_arc(Vector2.ZERO, radius, PI * 0.12, PI * 1.72, 18, Color(0.76, 0.91, 0.96, 0.44 * fade), 0.7, true)
		draw_circle(Vector2(-radius * 0.28, -radius * 0.32), maxf(radius * 0.16, 0.55), Color(0.94, 0.99, 1.0, 0.68 * fade))
		draw_set_transform(Vector2.ZERO)
		if bool(drop["trail"]):
			var trail_length := float(drop["trail_length"])
			for segment: int in range(3):
				var start_y := TRAIL_DIRECTION_Y * (radius + trail_length * float(segment) / 3.0)
				var end_y := TRAIL_DIRECTION_Y * (radius + trail_length * float(segment + 1) / 3.0)
				draw_line(
					position + Vector2(0.0, start_y),
					position + Vector2(0.0, end_y),
					Color(0.70, 0.88, 0.94, (0.20 - float(segment) * 0.05) * fade),
					0.55,
					true
				)
