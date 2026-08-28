extends Node2D

const MASK_THRESHOLD := 0.48

@export var random_seed := 20260828
@export var world_size := Vector2(4096.0, 4096.0)
@export var puddle_mask: Texture2D
@export_range(1.0, 40.0, 0.5) var impact_rate_max := 18.0
@export_range(0.5, 24.0, 0.5) var ripple_rate_max := 7.5
@export_range(8, 96, 1) var max_impacts := 48
@export_range(8, 96, 1) var max_ripples := 40
@export_range(12, 160, 1) var spawn_attempts := 96

var raining := false
var rain_strength := 0.0
var _impacts: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _impact_progress := 0.0
var _ripple_progress := 0.0
var _mask_image: Image
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	if puddle_mask != null:
		puddle_mask = ArtAssets.texture(puddle_mask.resource_path, puddle_mask)
		_mask_image = puddle_mask.get_image()
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
	_spawn_impact(world_position, 1.0)
	_spawn_ripple(world_position, 0.78)


func _process(delta: float) -> void:
	advance_effects(delta)


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	_update_effect_ages(delta)
	if raining and delta > 0.0:
		_spawn_rain_feedback(delta)
	set_process(raining or not _impacts.is_empty() or not _ripples.is_empty())
	queue_redraw()


func is_wettable(world_position: Vector2) -> bool:
	if world_position.x < 0.0 or world_position.y < 0.0 or world_position.x >= world_size.x or world_position.y >= world_size.y:
		return false
	if _mask_image == null or _mask_image.is_empty():
		return false
	var pixel := Vector2i(
		clampi(roundi(world_position.x / world_size.x * float(_mask_image.get_width() - 1)), 0, _mask_image.get_width() - 1),
		clampi(roundi(world_position.y / world_size.y * float(_mask_image.get_height() - 1)), 0, _mask_image.get_height() - 1)
	)
	return _mask_image.get_pixelv(pixel).r >= MASK_THRESHOLD


func get_visible_wet_position() -> Vector2:
	return _random_visible_wet_position()


func has_wet_mask() -> bool:
	return _mask_image != null and not _mask_image.is_empty()


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
	var shaped_strength := pow(rain_strength, 1.55)
	_impact_progress += delta * lerpf(0.8, impact_rate_max, shaped_strength)
	while _impact_progress >= 1.0 and _impacts.size() < max_impacts:
		_impact_progress -= 1.0
		var position := _random_visible_wet_position()
		if position != Vector2.INF:
			_spawn_impact(position, _rng.randf_range(0.55, 1.0))

	_ripple_progress += delta * lerpf(0.25, ripple_rate_max, shaped_strength)
	while _ripple_progress >= 1.0 and _ripples.size() < max_ripples:
		_ripple_progress -= 1.0
		var position := _random_visible_wet_position()
		if position != Vector2.INF:
			_spawn_ripple(position, _rng.randf_range(0.38, 0.72))


func _random_visible_wet_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	for _attempt: int in range(spawn_attempts):
		var screen_position := Vector2(
			_rng.randf_range(-18.0, viewport_size.x + 18.0),
			_rng.randf_range(viewport_size.y * 0.18, viewport_size.y + 10.0)
		)
		var world_position := inverse_canvas * screen_position
		if is_wettable(world_position):
			return world_position
	return Vector2.INF


func _spawn_impact(position: Vector2, strength: float) -> void:
	_impacts.append({
		"position": position,
		"age": 0.0,
		"duration": _rng.randf_range(0.34, 0.56),
		"radius": _rng.randf_range(4.0, 7.2),
		"strength": strength,
		"lean": _rng.randf_range(-0.35, 0.35),
	})


func _spawn_ripple(position: Vector2, strength: float) -> void:
	_ripples.append({
		"position": position,
		"age": 0.0,
		"duration": _rng.randf_range(0.72, 1.22),
		"radius": _rng.randf_range(6.0, 12.0),
		"strength": strength,
		"phase": _rng.randf_range(-0.22, 0.22),
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
	draw_set_transform(ripple["position"], float(ripple["phase"]), Vector2(1.0, 0.40))
	draw_arc(Vector2.ZERO, radius, 0.18, PI * 0.92, 14, Color(0.70, 0.88, 0.94, alpha * 0.72), 0.65, true)
	draw_arc(Vector2.ZERO, radius, PI * 1.10, TAU * 0.96, 14, Color(0.62, 0.82, 0.90, alpha * 0.52), 0.55, true)
	draw_set_transform(Vector2.ZERO)


func _draw_impact(impact: Dictionary) -> void:
	var progress := clampf(float(impact["age"]) / float(impact["duration"]), 0.0, 1.0)
	var strength := float(impact["strength"]) * rain_strength
	var position: Vector2 = impact["position"]
	var fade := pow(1.0 - progress, 1.7)
	draw_set_transform(position, float(impact["lean"]), Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, float(impact["radius"]) * progress, 0.0, TAU, 18, Color(0.72, 0.90, 0.96, fade * strength * 0.56), 0.62, true)
	draw_set_transform(Vector2.ZERO)
	if progress < 0.38:
		var splash_progress := progress / 0.38
		var splash_height := sin(splash_progress * PI) * 5.4
		var alpha := (1.0 - splash_progress) * strength * 0.72
		for direction: Vector2 in [Vector2(-2.8, -0.72), Vector2(0.0, -1.18), Vector2(2.6, -0.82)]:
			draw_line(position, position + Vector2(direction.x, direction.y * splash_height), Color(0.78, 0.94, 0.98, alpha), 0.62, true)
