extends Control

const MAX_PARTICLES := 260

@export var random_seed := 20260828
@export var ground_effects_path: NodePath
@export var audio_player_path: NodePath

var intensity := 0.0
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _ground_effects: Node
var _rain_loop: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = random_seed
	_ground_effects = get_node_or_null(ground_effects_path)
	_rain_loop = get_node_or_null(audio_player_path) as AudioStreamPlayer
	_setup_audio_loop()
	resized.connect(_reset_particles)
	_reset_particles()
	set_process(false)
	visible = false


func _exit_tree() -> void:
	if _rain_loop != null:
		_rain_loop.stop()
		_rain_loop.stream = null


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	visible = intensity > 0.001
	_sync_audio()
	queue_redraw()


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	_sync_audio()
	if intensity > 0.001 and delta > 0.0:
		_update_particles(delta, get_active_particle_count())
	queue_redraw()


func get_active_particle_count() -> int:
	return clampi(roundi(float(_particles.size()) * intensity), 0, _particles.size())


func get_audio_volume_db() -> float:
	return _rain_loop.volume_db if _rain_loop != null else -80.0


func is_audio_playing() -> bool:
	return _rain_loop != null and _rain_loop.playing


func _reset_particles() -> void:
	_particles.clear()
	for _index: int in range(MAX_PARTICLES):
		_particles.append(_new_particle(false))


func _new_particle(spawn_above: bool) -> Dictionary:
	var viewport_size := _effect_size()
	var depth := _rng.randf()
	var speed := lerpf(360.0, 720.0, depth) * _rng.randf_range(0.88, 1.12)
	var velocity := Vector2(_rng.randf_range(-145.0, -70.0), speed)
	var start_y := _rng.randf_range(-110.0, -8.0) if spawn_above else _rng.randf_range(-40.0, viewport_size.y)
	var impact_min := clampf(start_y + 40.0, 18.0, viewport_size.y)
	return {
		"position": Vector2(_rng.randf_range(0.0, viewport_size.x + 120.0), start_y),
		"velocity": velocity,
		"impact_y": _rng.randf_range(impact_min, viewport_size.y + 10.0),
		"splash": _rng.randf() < lerpf(0.34, 0.72, depth),
		"length": _rng.randf_range(3.8, 10.5) * lerpf(0.78, 1.0, depth),
		"alpha": _rng.randf_range(0.17, 0.48) * lerpf(0.72, 1.0, depth),
		"width": _rng.randf_range(0.28, 0.78) * lerpf(0.82, 1.0, depth),
		"depth": depth,
	}


func _update_particles(delta: float, active_count: int) -> void:
	var viewport_size := _effect_size()
	for index: int in range(active_count):
		var particle: Dictionary = _particles[index]
		var position: Vector2 = particle["position"]
		position += (particle["velocity"] as Vector2) * delta
		if position.y >= float(particle["impact_y"]):
			if bool(particle["splash"]):
				_spawn_ground_impact(position)
			particle.assign(_new_particle(true))
		elif position.y > viewport_size.y + 24.0 or position.x < -32.0:
			particle.assign(_new_particle(true))
		else:
			particle["position"] = position


func _spawn_ground_impact(screen_position: Vector2) -> void:
	if _ground_effects == null or not _ground_effects.has_method("spawn_impact"):
		return
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	_ground_effects.spawn_impact(world_position)


func _draw() -> void:
	if intensity <= 0.001:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.15, 0.20, 0.018 + intensity * 0.035))
	for index: int in range(get_active_particle_count()):
		var particle: Dictionary = _particles[index]
		var head: Vector2 = particle["position"]
		var velocity: Vector2 = particle["velocity"]
		var tail := head - velocity.normalized() * float(particle["length"])
		var depth := float(particle["depth"])
		var color := Color(0.64 + depth * 0.10, 0.79 + depth * 0.10, 0.90 + depth * 0.08, float(particle["alpha"]) * intensity)
		draw_line(tail, head, color, float(particle["width"]), true)
		if depth > 0.82:
			draw_circle(head, 0.55, Color(0.88, 0.96, 1.0, 0.18 * intensity))


func _effect_size() -> Vector2:
	return Vector2(maxf(size.x, 640.0), maxf(size.y, 360.0))


func _setup_audio_loop() -> void:
	if _rain_loop == null or not (_rain_loop.stream is AudioStreamWAV):
		return
	var loop_stream := _rain_loop.stream as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = roundi(loop_stream.get_length() * float(loop_stream.mix_rate))


func _sync_audio() -> void:
	if _rain_loop == null:
		return
	var audible_intensity := intensity if is_visible_in_tree() else 0.0
	if audible_intensity > 0.001:
		_rain_loop.volume_db = lerpf(-42.0, -8.0, sqrt(audible_intensity))
		if DisplayServer.get_name() == "headless":
			return
		if not _rain_loop.playing:
			_rain_loop.play()
	elif _rain_loop.playing:
		_rain_loop.stop()
