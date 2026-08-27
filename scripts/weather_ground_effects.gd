extends Node2D

const PUDDLE_POSITIONS := [
	Vector2(620, 720), Vector2(780, 790), Vector2(940, 840), Vector2(1110, 820),
	Vector2(1270, 900), Vector2(1450, 870), Vector2(690, 980), Vector2(850, 1040),
	Vector2(1040, 1010), Vector2(1210, 1090), Vector2(1390, 1140), Vector2(580, 1210),
	Vector2(760, 1280), Vector2(960, 1320), Vector2(1160, 1280), Vector2(1320, 1390),
	Vector2(1510, 1280), Vector2(880, 620), Vector2(1180, 650), Vector2(1530, 1040),
]

@export var random_seed := 20260827

var raining := false
var rain_strength := 0.0
var _puddles: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	for position: Vector2 in PUDDLE_POSITIONS:
		_puddles.append({
			"position": position,
			"size": Vector2(_rng.randf_range(12.0, 24.0), _rng.randf_range(4.0, 8.0)),
			"rotation": _rng.randf_range(-0.18, 0.18),
		})
	set_process(false)


func set_raining(value: bool) -> void:
	set_rain_strength(1.0 if value else 0.0)


func set_rain_strength(value: float) -> void:
	rain_strength = clampf(value, 0.0, 1.0)
	raining = rain_strength > 0.01
	set_process(raining or not _impacts.is_empty())
	queue_redraw()


func spawn_impact(world_position: Vector2) -> void:
	if not raining:
		return
	_impacts.append({
		"position": world_position,
		"age": 0.0,
		"duration": _rng.randf_range(0.45, 0.72),
		"radius": _rng.randf_range(5.0, 9.0),
	})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(seconds: float) -> void:
	for impact: Dictionary in _impacts:
		impact["age"] = float(impact["age"]) + maxf(seconds, 0.0)
	for index: int in range(_impacts.size() - 1, -1, -1):
		if float(_impacts[index]["age"]) >= float(_impacts[index]["duration"]):
			_impacts.remove_at(index)
	set_process(raining or not _impacts.is_empty())
	queue_redraw()


func _draw() -> void:
	if raining:
		_draw_puddles()
	for impact: Dictionary in _impacts:
		_draw_impact(impact)


func _draw_puddles() -> void:
	for puddle: Dictionary in _puddles:
		draw_set_transform(puddle["position"], float(puddle["rotation"]), puddle["size"])
		draw_circle(Vector2.ZERO, 1.0, Color(0.08, 0.20, 0.24, 0.13 * rain_strength))
		draw_circle(Vector2(-0.08, -0.14), 0.70, Color(0.48, 0.68, 0.73, 0.09 * rain_strength))
		draw_arc(Vector2.ZERO, 0.84, PI * 1.08, PI * 1.78, 12, Color(0.70, 0.90, 0.94, 0.38 * rain_strength), 0.06, true)
	draw_set_transform(Vector2.ZERO)


func _draw_impact(impact: Dictionary) -> void:
	var age := float(impact["age"])
	var duration := float(impact["duration"])
	var progress := clampf(age / duration, 0.0, 1.0)
	var position: Vector2 = impact["position"]
	var alpha := (1.0 - progress) * 0.65
	draw_set_transform(position, 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, float(impact["radius"]) * progress, 0.0, TAU, 20, Color(0.65, 0.88, 0.94, alpha), 0.9, true)
	draw_set_transform(Vector2.ZERO)
	if progress < 0.34:
		var splash_height := sin(progress / 0.34 * PI) * 5.0
		draw_line(position, position + Vector2(-3.0, -splash_height), Color(0.72, 0.92, 0.97, alpha), 0.8, true)
		draw_line(position, position + Vector2(0.0, -splash_height * 1.25), Color(0.78, 0.95, 1.0, alpha), 0.8, true)
		draw_line(position, position + Vector2(3.0, -splash_height * 0.8), Color(0.72, 0.92, 0.97, alpha), 0.8, true)
