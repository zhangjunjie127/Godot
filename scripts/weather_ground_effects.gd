extends Node2D

const RIPPLE_START_STRENGTH := 0.02
const PUDDLE_START_AMOUNT := 0.01
const POSITION_ATTEMPTS := 16
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
@export var water_query_path: NodePath
@export var puddle_mask: Texture2D
@export_range(0.0, 1.0, 0.01) var small_cutoff := 0.88
@export_range(0.0, 1.0, 0.01) var medium_cutoff := 0.72
@export_range(0.0, 1.0, 0.01) var heavy_cutoff := 0.34
@export_range(0.001, 0.2, 0.001) var mask_softness := 0.055
@export_range(0.0, 12.0, 0.5) var medium_spread_pixels := 3.0
@export_range(0.0, 16.0, 0.5) var heavy_spread_pixels := 4.0
@export_range(0.0, 8.0, 0.5) var edge_feather_pixels := 3.0
@export_range(0.5, 8.0, 0.5) var impact_rate_min := 2.0
@export_range(1.0, 40.0, 0.5) var impact_rate_max := 18.0
@export_range(0.5, 24.0, 0.5) var ripple_rate_max := 7.5
@export_range(0.5, 24.0, 0.5) var water_ripple_rate_max := 11.0
@export_range(8, 96, 1) var max_impacts := 48
@export_range(8, 96, 1) var max_ripples := 40

var raining := false
var rain_strength := 0.0
var puddle_amount := 0.0
var _impacts: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _impact_progress := 0.0
var _ripple_progress := 0.0
var _water_ripple_progress := 0.0
var _rng := RandomNumberGenerator.new()
var _puddle_mask_image: Image
var _water_query: Node


func _ready() -> void:
	_rng.seed = random_seed
	_water_query = get_node_or_null(water_query_path)
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


func set_puddle_amount(value: float) -> void:
	puddle_amount = clampf(value, 0.0, 1.0)


func set_weather_state(rain_value: float, puddle_value: float) -> void:
	set_puddle_amount(puddle_value)
	set_rain_strength(rain_value)


func spawn_impact(world_position: Vector2) -> void:
	if not raining or not is_feedback_area(world_position):
		return
	if is_water_surface_position(world_position):
		_spawn_ripple(world_position, lerpf(0.42, 0.86, get_water_ripple_strength()))
	elif is_puddle_position(world_position):
		_spawn_ripple(world_position, lerpf(0.48, 0.90, get_ripple_strength()))
	else:
		_spawn_impact(world_position, 1.0)


func spawn_step_feedback(world_position: Vector2, movement_strength := 1.0) -> bool:
	if not is_puddle_position(world_position):
		return false
	var strength := clampf(movement_strength, 0.35, 1.0)
	_spawn_impact(world_position, lerpf(0.82, 1.15, strength), true)
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


func is_water_surface_position(world_position: Vector2) -> bool:
	return _water_query != null and _water_query.has_method("is_water_position") and bool(_water_query.call("is_water_position", world_position))


func is_puddle_position(world_position: Vector2) -> bool:
	if puddle_amount <= PUDDLE_START_AMOUNT or not is_feedback_area(world_position):
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
	var medium_progress := smoothstep(0.02, 0.60, puddle_amount)
	var heavy_progress := smoothstep(0.60, 1.0, puddle_amount)
	var spread_pixels := lerpf(0.0, medium_spread_pixels, medium_progress)
	spread_pixels = lerpf(spread_pixels, heavy_spread_pixels, heavy_progress)
	var sample_radius := maxi(roundi(spread_pixels), 0)
	var authored := _sample_puddle_mask(pixel, sample_radius)
	var cutoff := lerpf(small_cutoff, medium_cutoff, medium_progress)
	cutoff = lerpf(cutoff, heavy_cutoff, heavy_progress)
	return authored >= cutoff - mask_softness


func get_visible_feedback_position() -> Vector2:
	return _random_visible_position()


func get_impact_spawn_rate() -> float:
	return lerpf(impact_rate_min, impact_rate_max, pow(rain_strength, 1.3)) if raining else 0.0


func get_ripple_strength() -> float:
	return minf(smoothstep(0.45, 1.0, rain_strength), smoothstep(RIPPLE_START_STRENGTH, 0.60, puddle_amount))


func get_ripple_spawn_rate() -> float:
	return ripple_rate_max * pow(get_ripple_strength(), 1.25) if raining and puddle_amount > PUDDLE_START_AMOUNT else 0.0


func get_water_ripple_strength() -> float:
	return smoothstep(0.08, 1.0, rain_strength) if raining else 0.0


func get_water_ripple_spawn_rate() -> float:
	return water_ripple_rate_max * pow(get_water_ripple_strength(), 1.2) if raining else 0.0


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
		var position := _random_visible_position(false)
		if position != Vector2.INF:
			_spawn_impact(position, _rng.randf_range(0.55, 1.0))

	var ripple_strength := get_ripple_strength()
	_ripple_progress += delta * get_ripple_spawn_rate()
	while _ripple_progress >= 1.0 and _ripples.size() < max_ripples:
		_ripple_progress -= 1.0
		var position := _random_puddle_position()
		if position != Vector2.INF:
			_spawn_ripple(position, _rng.randf_range(0.38, 0.72) * lerpf(0.80, 1.25, ripple_strength))

	var water_ripple_strength := get_water_ripple_strength()
	_water_ripple_progress += delta * get_water_ripple_spawn_rate()
	while _water_ripple_progress >= 1.0 and _ripples.size() < max_ripples:
		_water_ripple_progress -= 1.0
		var position := _random_visible_position(true)
		if position != Vector2.INF:
			_spawn_ripple(position, _rng.randf_range(0.30, 0.68) * lerpf(0.72, 1.18, water_ripple_strength))


func _random_visible_position(required_water: Variant = null) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	for _attempt: int in range(POSITION_ATTEMPTS):
		var screen_position := Vector2(
			_rng.randf_range(-18.0, viewport_size.x + 18.0),
			_rng.randf_range(viewport_size.y * 0.18, viewport_size.y + 10.0)
		)
		var world_position := inverse_canvas * screen_position
		if not is_feedback_area(world_position):
			continue
		if required_water != null and is_water_surface_position(world_position) != bool(required_water):
			continue
		return world_position
	return Vector2.INF


func _random_puddle_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	for _attempt: int in range(POSITION_ATTEMPTS):
		var screen_position := Vector2(
			_rng.randf_range(-18.0, viewport_size.x + 18.0),
			_rng.randf_range(viewport_size.y * 0.18, viewport_size.y + 10.0)
		)
		var world_position := inverse_canvas * screen_position
		if is_puddle_position(world_position):
			return world_position
	return Vector2.INF


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


func _spawn_impact(position: Vector2, strength: float, contact_ring := false) -> void:
	_impacts.append({
		"position": position,
		"age": 0.0,
		"duration": _rng.randf_range(0.34, 0.56),
		"radius": _rng.randf_range(4.0, 7.2),
		"strength": strength,
		"lean": _rng.randf_range(-0.35, 0.35),
		"line_scale": 1.0,
		"splash_scale": 1.0,
		"contact_ring": contact_ring,
		"camera_scale": _camera_effect_scale(),
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
		"camera_scale": _camera_effect_scale(),
	})


func _camera_effect_scale() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return 1.0
	return clampf(1.0 / maxf(minf(camera.zoom.x, camera.zoom.y), 0.15), 1.0, 4.5)


func _draw() -> void:
	for ripple: Dictionary in _ripples:
		_draw_ripple(ripple)
	for impact: Dictionary in _impacts:
		_draw_impact(impact)


func _draw_ripple(ripple: Dictionary) -> void:
	var progress := clampf(float(ripple["age"]) / float(ripple["duration"]), 0.0, 1.0)
	var fade := pow(1.0 - progress, 1.55)
	var alpha := fade * float(ripple["strength"])
	var radius := float(ripple["radius"]) * lerpf(0.28, 1.0, progress)
	var camera_scale := float(ripple["camera_scale"])
	radius *= camera_scale
	var line_scale := float(ripple["line_scale"]) * camera_scale
	draw_set_transform(ripple["position"], float(ripple["phase"]), Vector2(1.0, 0.40))
	draw_arc(Vector2.ZERO, radius + 0.8 * line_scale, 0.0, TAU, 22, Color(0.30, 0.52, 0.60, alpha * 0.14), 1.5 * line_scale, true)
	draw_arc(Vector2.ZERO, radius, PI * 1.05, TAU * 0.98, 16, Color(0.76, 0.93, 0.96, alpha * 0.78), 0.62 * line_scale, true)
	draw_arc(Vector2.ZERO, radius, 0.05, PI * 0.95, 16, Color(0.16, 0.39, 0.47, alpha * 0.55), 0.54 * line_scale, true)
	draw_set_transform(Vector2.ZERO)


func _draw_impact(impact: Dictionary) -> void:
	var progress := clampf(float(impact["age"]) / float(impact["duration"]), 0.0, 1.0)
	var strength := float(impact["strength"])
	var position: Vector2 = impact["position"]
	var fade := pow(1.0 - progress, 1.7)
	var line_scale := float(impact["line_scale"])
	var camera_scale := float(impact["camera_scale"])
	line_scale *= camera_scale
	var splash_scale := float(impact["splash_scale"]) * camera_scale
	draw_set_transform(position, float(impact["lean"]), Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, float(impact["radius"]) * camera_scale * 0.42, 0.0, TAU, 14, Color(0.08, 0.25, 0.31, fade * strength * 0.24), 1.25 * line_scale, true)
	if bool(impact["contact_ring"]):
		draw_arc(Vector2.ZERO, float(impact["radius"]) * camera_scale * progress, 0.0, TAU, 18, Color(0.72, 0.90, 0.96, fade * strength * 0.56), 0.62 * line_scale, true)
	draw_set_transform(Vector2.ZERO)
	if progress < 0.38:
		var splash_progress := progress / 0.38
		var splash_height := sin(splash_progress * PI) * 5.4 * splash_scale
		var alpha := (1.0 - splash_progress) * strength * 0.72
		for direction: Vector2 in [Vector2(-2.8, -0.72), Vector2(0.0, -1.18), Vector2(2.6, -0.82)]:
			draw_line(position, position + Vector2(direction.x * splash_scale, direction.y * splash_height), Color(0.78, 0.94, 0.98, alpha), 0.62 * line_scale, true)
