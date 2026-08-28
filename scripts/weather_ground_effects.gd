extends Node2D

const RIPPLE_START_STRENGTH := 0.50
const PUDDLE_START_STRENGTH := 0.45
const PUDDLE_SAMPLE_DIRECTIONS := [
	Vector2i.ZERO,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

@export var random_seed := 20260828
@export var world_size := Vector2(4096.0, 4096.0)
@export var puddle_mask: Texture2D
@export_range(0.0, 1.0, 0.01) var medium_cutoff := 0.72
@export_range(0.0, 1.0, 0.01) var heavy_cutoff := 0.34
@export_range(0.001, 0.2, 0.001) var mask_softness := 0.055
@export_range(0.0, 12.0, 0.5) var medium_spread_pixels := 3.0
@export_range(0.0, 16.0, 0.5) var heavy_spread_pixels := 4.0
@export_range(0.0, 8.0, 0.5) var edge_feather_pixels := 3.0
@export_range(0.5, 8.0, 0.5) var impact_rate_min := 2.0
@export_range(1.0, 40.0, 0.5) var impact_rate_max := 18.0
@export_range(0.5, 24.0, 0.5) var ripple_rate_max := 7.5
@export_range(8, 96, 1) var max_impacts := 48
@export_range(8, 96, 1) var max_ripples := 40

var raining := false
var rain_strength := 0.0
var _impacts: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _impact_progress := 0.0
var _ripple_progress := 0.0
var _rng := RandomNumberGenerator.new()
var _puddle_mask_image: Image


func _ready() -> void:
	_rng.seed = random_seed
	_cache_puddle_mask()
	set_process(false)


func set_raining(value: bool) -> void:
	set_rain_strength(1.0 if value else 0.0)


func set_puddle_mask(value: Texture2D) -> void:
	puddle_mask = value
	_cache_puddle_mask()


func set_rain_strength(value: float) -> void:
	rain_strength = clampf(value, 0.0, 1.0)
	raining = rain_strength > 0.01
	set_process(raining or not _impacts.is_empty() or not _ripples.is_empty())
	queue_redraw()


func spawn_impact(world_position: Vector2) -> void:
	if not raining or not is_feedback_area(world_position):
		return
	_spawn_impact(world_position, 1.0)
	var ripple_strength := get_ripple_strength()
	if ripple_strength > 0.0:
		_spawn_ripple(world_position, lerpf(0.48, 0.90, ripple_strength))


func spawn_step_feedback(world_position: Vector2, movement_strength := 1.0) -> bool:
	if not raining or not is_puddle_position(world_position):
		return false
	var strength := clampf(movement_strength, 0.35, 1.0)
	_spawn_impact(world_position, lerpf(0.82, 1.15, strength))
	_impacts[-1]["radius"] = float(_impacts[-1]["radius"]) * lerpf(1.35, 1.65, strength)
	_impacts[-1]["line_scale"] = lerpf(1.7, 2.2, strength)
	_impacts[-1]["splash_scale"] = lerpf(1.35, 1.65, strength)
	_spawn_ripple(world_position, lerpf(0.72, 1.05, strength))
	_ripples[-1]["radius"] = float(_ripples[-1]["radius"]) * lerpf(1.20, 1.45, strength)
	_ripples[-1]["line_scale"] = float(_ripples[-1]["line_scale"]) * lerpf(1.55, 1.95, strength)
	set_process(true)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	_update_effect_ages(delta)
	if raining and delta > 0.0:
		_spawn_rain_feedback(delta)
	set_process(raining or not _impacts.is_empty() or not _ripples.is_empty())
	queue_redraw()


func is_feedback_area(world_position: Vector2) -> bool:
	return world_position.x >= 0.0 and world_position.y >= 0.0 and world_position.x < world_size.x and world_position.y < world_size.y


func is_puddle_position(world_position: Vector2) -> bool:
	if rain_strength <= PUDDLE_START_STRENGTH or not is_feedback_area(world_position):
		return false
	if _puddle_mask_image == null or _puddle_mask_image.is_empty():
		_cache_puddle_mask()
	if _puddle_mask_image == null or _puddle_mask_image.is_empty():
		return false
	var image_size := _puddle_mask_image.get_size()
	var uv := world_position / world_size
	var pixel := Vector2i(
		clampi(floori(uv.x * image_size.x), 0, image_size.x - 1),
		clampi(floori(uv.y * image_size.y), 0, image_size.y - 1)
	)
	var puddle_level := smoothstep(PUDDLE_START_STRENGTH, 1.0, rain_strength)
	var spread_level := smoothstep(0.75, 1.0, rain_strength)
	var spread_pixels := lerpf(medium_spread_pixels, heavy_spread_pixels, spread_level)
	var sample_radius := maxi(roundi(spread_pixels + edge_feather_pixels * 0.5), 0)
	var authored := _sample_puddle_mask(pixel, sample_radius)
	var cutoff := lerpf(medium_cutoff, heavy_cutoff, puddle_level)
	return authored >= cutoff - mask_softness


func get_visible_feedback_position() -> Vector2:
	return _random_visible_position()


func get_impact_spawn_rate() -> float:
	return lerpf(impact_rate_min, impact_rate_max, pow(rain_strength, 1.3)) if raining else 0.0


func get_ripple_strength() -> float:
	return smoothstep(RIPPLE_START_STRENGTH, 1.0, rain_strength)


func get_ripple_spawn_rate() -> float:
	return ripple_rate_max * pow(get_ripple_strength(), 1.25) if raining else 0.0


func _update_effect_ages(delta: float) -> void:
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


func _spawn_rain_feedback(delta: float) -> void:
	_impact_progress += delta * get_impact_spawn_rate()
	while _impact_progress >= 1.0 and _impacts.size() < max_impacts:
		_impact_progress -= 1.0
		var position := _random_visible_position()
		if position != Vector2.INF:
			_spawn_impact(position, _rng.randf_range(0.55, 1.0))

	var ripple_strength := get_ripple_strength()
	_ripple_progress += delta * get_ripple_spawn_rate()
	while _ripple_progress >= 1.0 and _ripples.size() < max_ripples:
		_ripple_progress -= 1.0
		var position := _random_visible_position()
		if position != Vector2.INF:
			_spawn_ripple(position, _rng.randf_range(0.38, 0.72) * lerpf(0.80, 1.25, ripple_strength))


func _random_visible_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var screen_position := Vector2(
		_rng.randf_range(-18.0, viewport_size.x + 18.0),
		_rng.randf_range(viewport_size.y * 0.18, viewport_size.y + 10.0)
	)
	var world_position := inverse_canvas * screen_position
	return world_position if is_feedback_area(world_position) else Vector2.INF


func _cache_puddle_mask() -> void:
	_puddle_mask_image = puddle_mask.get_image() if puddle_mask != null else null


func _sample_puddle_mask(pixel: Vector2i, radius: int) -> float:
	var image_size := _puddle_mask_image.get_size()
	var sampled := 0.0
	for direction: Vector2i in PUDDLE_SAMPLE_DIRECTIONS:
		var point := pixel + direction * radius
		point.x = clampi(point.x, 0, image_size.x - 1)
		point.y = clampi(point.y, 0, image_size.y - 1)
		sampled = maxf(sampled, _puddle_mask_image.get_pixelv(point).r)
	return sampled


func _spawn_impact(position: Vector2, strength: float) -> void:
	_impacts.append({
		"position": position,
		"age": 0.0,
		"duration": _rng.randf_range(0.34, 0.56),
		"radius": _rng.randf_range(4.0, 7.2),
		"strength": strength,
		"lean": _rng.randf_range(-0.35, 0.35),
		"line_scale": 1.0,
		"splash_scale": 1.0,
	})


func _spawn_ripple(position: Vector2, strength: float) -> void:
	var emphasis := lerpf(0.82, 1.28, get_ripple_strength())
	_ripples.append({
		"position": position,
		"age": 0.0,
		"duration": _rng.randf_range(0.72, 1.22) * lerpf(0.92, 1.12, get_ripple_strength()),
		"radius": _rng.randf_range(6.0, 12.0) * emphasis,
		"strength": strength,
		"phase": _rng.randf_range(-0.22, 0.22),
		"line_scale": emphasis,
	})


func _draw() -> void:
	for ripple: Dictionary in _ripples:
		_draw_ripple(ripple)
	for impact: Dictionary in _impacts:
		_draw_impact(impact)


func _draw_ripple(ripple: Dictionary) -> void:
	var progress := clampf(float(ripple["age"]) / float(ripple["duration"]), 0.0, 1.0)
	var fade := pow(1.0 - progress, 1.55)
	var alpha := fade * float(ripple["strength"]) * rain_strength
	var radius := float(ripple["radius"]) * lerpf(0.28, 1.0, progress)
	var line_scale := float(ripple["line_scale"])
	draw_set_transform(ripple["position"], float(ripple["phase"]), Vector2(1.0, 0.40))
	draw_arc(Vector2.ZERO, radius, 0.18, PI * 0.92, 14, Color(0.70, 0.88, 0.94, alpha * 0.72), 0.65 * line_scale, true)
	draw_arc(Vector2.ZERO, radius, PI * 1.10, TAU * 0.96, 14, Color(0.62, 0.82, 0.90, alpha * 0.52), 0.55 * line_scale, true)
	draw_set_transform(Vector2.ZERO)


func _draw_impact(impact: Dictionary) -> void:
	var progress := clampf(float(impact["age"]) / float(impact["duration"]), 0.0, 1.0)
	var strength := float(impact["strength"]) * lerpf(0.55, 1.0, rain_strength)
	var position: Vector2 = impact["position"]
	var fade := pow(1.0 - progress, 1.7)
	var line_scale := float(impact["line_scale"])
	var splash_scale := float(impact["splash_scale"])
	draw_set_transform(position, float(impact["lean"]), Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, float(impact["radius"]) * progress, 0.0, TAU, 18, Color(0.72, 0.90, 0.96, fade * strength * 0.56), 0.62 * line_scale, true)
	draw_set_transform(Vector2.ZERO)
	if progress < 0.38:
		var splash_progress := progress / 0.38
		var splash_height := sin(splash_progress * PI) * 5.4 * splash_scale
		var alpha := (1.0 - splash_progress) * strength * 0.72
		for direction: Vector2 in [Vector2(-2.8, -0.72), Vector2(0.0, -1.18), Vector2(2.6, -0.82)]:
			draw_line(position, position + Vector2(direction.x * splash_scale, direction.y * splash_height), Color(0.78, 0.94, 0.98, alpha), 0.62 * line_scale, true)
