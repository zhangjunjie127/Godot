extends Control

const TRAIL_DIRECTION_Y := -1.0
const DROP_START_INTENSITY := 0.42
const MAX_SCREEN_DROPS := 8

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
	if previous_intensity <= DROP_START_INTENSITY and intensity > DROP_START_INTENSITY:
		_spawn_progress = maxf(_spawn_progress, 0.75)
	visible = intensity > DROP_START_INTENSITY or not _drops.is_empty()


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	var drop_strength := clampf(inverse_lerp(DROP_START_INTENSITY, 1.0, intensity), 0.0, 1.0)
	_spawn_progress += delta * pow(drop_strength, 1.7) * 2.2
	while _spawn_progress >= 1.0 and _drops.size() < MAX_SCREEN_DROPS:
		_spawn_progress -= 1.0
		_drops.append(_new_drop())

	for drop: Dictionary in _drops:
		drop["age"] = float(drop["age"]) + delta
		if float(drop["age"]) > float(drop["hold"]):
			var velocity := minf(float(drop["velocity"]) + float(drop["acceleration"]) * delta, float(drop["max_speed"]))
			var position: Vector2 = drop["position"]
			position += Vector2(float(drop["drift"]), velocity) * delta
			drop["velocity"] = velocity
			drop["position"] = position
	for index: int in range(_drops.size() - 1, -1, -1):
		if float(_drops[index]["age"]) >= float(_drops[index]["duration"]):
			_drops.remove_at(index)
	visible = intensity > DROP_START_INTENSITY or not _drops.is_empty()
	queue_redraw()


func _new_drop() -> Dictionary:
	var viewport_size := Vector2(maxf(size.x, 640.0), maxf(size.y, 360.0))
	return {
		"position": Vector2(_rng.randf_range(10.0, viewport_size.x - 10.0), _rng.randf_range(8.0, viewport_size.y * 0.82)),
		"radius": _rng.randf_range(0.9, 2.2),
		"age": 0.0,
		"duration": _rng.randf_range(4.0, 7.5),
		"hold": _rng.randf_range(0.35, 2.6),
		"velocity": _rng.randf_range(0.0, 1.2),
		"acceleration": _rng.randf_range(1.6, 4.4),
		"max_speed": _rng.randf_range(5.0, 11.0),
		"drift": _rng.randf_range(-0.18, 0.18),
		"trail": _rng.randf() < 0.54,
		"trail_length": _rng.randf_range(8.0, 18.0),
	}


func _draw() -> void:
	for drop: Dictionary in _drops:
		var progress := clampf(float(drop["age"]) / float(drop["duration"]), 0.0, 1.0)
		var fade := sin(progress * PI)
		var position: Vector2 = drop["position"]
		var radius := float(drop["radius"])
		draw_set_transform(position, 0.0, Vector2(0.72, 1.0))
		draw_circle(Vector2.ZERO, radius, Color(0.58, 0.78, 0.86, 0.045 * fade))
		draw_arc(Vector2.ZERO, radius, PI * 0.12, PI * 1.72, 16, Color(0.76, 0.91, 0.96, 0.34 * fade), 0.55, true)
		draw_circle(Vector2(-radius * 0.28, -radius * 0.32), maxf(radius * 0.14, 0.42), Color(0.94, 0.99, 1.0, 0.52 * fade))
		draw_set_transform(Vector2.ZERO)
		if bool(drop["trail"]):
			var trail_length := float(drop["trail_length"])
			for segment: int in range(3):
				var start_y := TRAIL_DIRECTION_Y * (radius + trail_length * float(segment) / 3.0)
				var end_y := TRAIL_DIRECTION_Y * (radius + trail_length * float(segment + 1) / 3.0)
				draw_line(
					position + Vector2(0.0, start_y),
					position + Vector2(0.0, end_y),
					Color(0.70, 0.88, 0.94, (0.14 - float(segment) * 0.035) * fade),
					0.45,
					true
				)
