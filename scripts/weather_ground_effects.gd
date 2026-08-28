extends Node2D

const MASK_THRESHOLD := 0.48
const ANCHOR_POSITIONS := [
	Vector2(2270, 1850), Vector2(2580, 2440), Vector2(2830, 2350), Vector2(3060, 2520),
	Vector2(1700, 2180), Vector2(1450, 2700), Vector2(3280, 1850), Vector2(1850, 3020),
]

@export var random_seed := 20260828
@export var world_size := Vector2(4096.0, 4096.0)
@export_range(24, 160, 1) var puddle_count := 96
@export var puddle_mask: Texture2D

var raining := false
var rain_strength := 0.0
var _puddles: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _ripple_progress := 0.0
var _elapsed := 0.0
var _mask_image: Image
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	if puddle_mask != null:
		puddle_mask = ArtAssets.texture(puddle_mask.resource_path, puddle_mask)
		_mask_image = puddle_mask.get_image()
	_build_puddles()
	set_process(false)


func set_raining(value: bool) -> void:
	set_rain_strength(1.0 if value else 0.0)


func set_rain_strength(value: float) -> void:
	rain_strength = clampf(value, 0.0, 1.0)
	raining = rain_strength > 0.01
	set_process(raining or not _impacts.is_empty() or not _ripples.is_empty())
	queue_redraw()


func spawn_impact(world_position: Vector2) -> void:
	if not raining or not is_wettable(world_position):
		return
	_impacts.append({
		"position": world_position,
		"age": 0.0,
		"duration": _rng.randf_range(0.40, 0.68),
		"radius": _rng.randf_range(4.5, 8.0),
	})
	if _is_in_puddle(world_position):
		_spawn_ripple(world_position, 0.75)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	_elapsed += delta
	for impact: Dictionary in _impacts:
		impact["age"] = float(impact["age"]) + delta
	for ripple: Dictionary in _ripples:
		ripple["age"] = float(ripple["age"]) + delta
	for index: int in range(_impacts.size() - 1, -1, -1):
		if float(_impacts[index]["age"]) >= float(_impacts[index]["duration"]):
			_impacts.remove_at(index)
	for index: int in range(_ripples.size() - 1, -1, -1):
		if float(_ripples[index]["age"]) >= float(_ripples[index]["duration"]):
			_ripples.remove_at(index)
	if raining and not _puddles.is_empty():
		_ripple_progress += delta * lerpf(0.7, 7.0, rain_strength)
		while _ripple_progress >= 1.0 and _ripples.size() < 36:
			_ripple_progress -= 1.0
			var puddle: Dictionary = _puddles[_rng.randi_range(0, _puddles.size() - 1)]
			var size_value: Vector2 = puddle["size"]
			var offset := Vector2(_rng.randf_range(-0.55, 0.55) * size_value.x, _rng.randf_range(-0.45, 0.45) * size_value.y)
			_spawn_ripple((puddle["position"] as Vector2) + offset.rotated(float(puddle["rotation"])), 0.45)
	set_process(raining or not _impacts.is_empty() or not _ripples.is_empty())
	queue_redraw()


func is_wettable(world_position: Vector2) -> bool:
	if world_position.x < 0.0 or world_position.y < 0.0 or world_position.x >= world_size.x or world_position.y >= world_size.y:
		return false
	if _mask_image == null or _mask_image.is_empty():
		return true
	var pixel := Vector2i(
		clampi(roundi(world_position.x / world_size.x * float(_mask_image.get_width() - 1)), 0, _mask_image.get_width() - 1),
		clampi(roundi(world_position.y / world_size.y * float(_mask_image.get_height() - 1)), 0, _mask_image.get_height() - 1)
	)
	return _mask_image.get_pixelv(pixel).r >= MASK_THRESHOLD


func get_puddle_position(index: int) -> Vector2:
	if index < 0 or index >= _puddles.size():
		return Vector2.INF
	return _puddles[index]["position"]


func _build_puddles() -> void:
	_puddles.clear()
	for anchor: Vector2 in ANCHOR_POSITIONS:
		var position := _nearest_wettable(anchor)
		if position != Vector2.INF:
			_add_puddle(position)
	var attempts := 0
	while _puddles.size() < puddle_count and attempts < puddle_count * 160:
		attempts += 1
		var position := Vector2(_rng.randf_range(180.0, world_size.x - 180.0), _rng.randf_range(180.0, world_size.y - 180.0))
		if not is_wettable(position) or _has_nearby_puddle(position):
			continue
		_add_puddle(position)


func _nearest_wettable(origin: Vector2) -> Vector2:
	if is_wettable(origin):
		return origin
	for radius: int in range(24, 265, 24):
		for step: int in range(16):
			var candidate := origin + Vector2.RIGHT.rotated(TAU * float(step) / 16.0) * float(radius)
			if is_wettable(candidate):
				return candidate
	return Vector2.INF


func _has_nearby_puddle(position: Vector2) -> bool:
	for puddle: Dictionary in _puddles:
		if (puddle["position"] as Vector2).distance_squared_to(position) < 52.0 * 52.0:
			return true
	return false


func _add_puddle(position: Vector2) -> void:
	_puddles.append({
		"position": position,
		"size": Vector2(_rng.randf_range(22.0, 58.0), _rng.randf_range(7.0, 17.0)),
		"rotation": _rng.randf_range(-0.28, 0.28),
		"phase": _rng.randf_range(0.0, TAU),
	})


func _spawn_ripple(position: Vector2, strength: float) -> void:
	_ripples.append({
		"position": position,
		"age": 0.0,
		"duration": _rng.randf_range(0.65, 1.15),
		"radius": _rng.randf_range(5.0, 11.0),
		"strength": strength,
	})


func _is_in_puddle(world_position: Vector2) -> bool:
	for puddle: Dictionary in _puddles:
		var local := (world_position - (puddle["position"] as Vector2)).rotated(-float(puddle["rotation"]))
		var size_value: Vector2 = puddle["size"]
		if Vector2(local.x / size_value.x, local.y / size_value.y).length_squared() <= 1.0:
			return true
	return false


func _draw() -> void:
	if raining:
		for puddle: Dictionary in _puddles:
			_draw_puddle(puddle)
	for ripple: Dictionary in _ripples:
		_draw_ripple(ripple)
	for impact: Dictionary in _impacts:
		_draw_impact(impact)


func _draw_puddle(puddle: Dictionary) -> void:
	var shimmer := 0.55 + sin(_elapsed * 0.55 + float(puddle["phase"])) * 0.12
	draw_set_transform(puddle["position"], float(puddle["rotation"]), puddle["size"])
	draw_circle(Vector2.ZERO, 1.0, Color(0.055, 0.14, 0.17, 0.10 * rain_strength))
	draw_circle(Vector2(-0.24, -0.05), 0.68, Color(0.22, 0.40, 0.46, 0.055 * rain_strength))
	draw_circle(Vector2(0.38, 0.08), 0.40, Color(0.10, 0.25, 0.30, 0.055 * rain_strength))
	draw_arc(Vector2(-0.05, -0.05), 0.76, PI * 1.04, PI * 1.72, 18, Color(0.70, 0.90, 0.95, shimmer * 0.38 * rain_strength), 0.045, true)
	draw_set_transform(Vector2.ZERO)


func _draw_ripple(ripple: Dictionary) -> void:
	var progress := clampf(float(ripple["age"]) / float(ripple["duration"]), 0.0, 1.0)
	var alpha := (1.0 - progress) * float(ripple["strength"]) * rain_strength
	draw_set_transform(ripple["position"], 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, float(ripple["radius"]) * (0.35 + progress), 0.0, TAU, 24, Color(0.66, 0.89, 0.96, alpha), 0.75, true)
	draw_set_transform(Vector2.ZERO)


func _draw_impact(impact: Dictionary) -> void:
	var progress := clampf(float(impact["age"]) / float(impact["duration"]), 0.0, 1.0)
	var position: Vector2 = impact["position"]
	var alpha := (1.0 - progress) * 0.70 * rain_strength
	if progress < 0.42:
		var splash_height := sin(progress / 0.42 * PI) * 6.0
		for direction: Vector2 in [Vector2(-3.2, -1.0), Vector2(0.0, -1.25), Vector2(3.0, -0.85)]:
			draw_line(position, position + Vector2(direction.x, direction.y * splash_height), Color(0.76, 0.94, 1.0, alpha), 0.75, true)
