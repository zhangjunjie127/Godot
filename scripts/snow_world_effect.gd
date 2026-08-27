extends Node2D

@export var world_size := Vector2(2048.0, 2048.0)
@export var particle_capacity := 180
@export var random_seed := 7701

var intensity := 0.0
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	for _index: int in range(particle_capacity):
		_particles.append(_new_particle(false))
	queue_redraw()


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	queue_redraw()


func advance_effects(delta: float) -> void:
	var active_count := get_active_particle_count()
	for index: int in range(active_count):
		var particle: Dictionary = _particles[index]
		var phase := float(particle["phase"]) + float(particle["drift_speed"]) * delta
		var position: Vector2 = particle["position"]
		position.x += sin(phase) * float(particle["drift"]) * delta
		position.y += float(particle["speed"]) * delta
		particle["phase"] = phase
		if position.y > world_size.y + 12.0:
			particle.assign(_new_particle(true))
		else:
			position.x = fposmod(position.x, world_size.x)
			particle["position"] = position
	queue_redraw()


func get_active_particle_count() -> int:
	return clampi(roundi(_particles.size() * intensity), 0, _particles.size())


func get_particle_world_position(index: int) -> Vector2:
	if index < 0 or index >= _particles.size():
		return Vector2.INF
	return global_transform * (_particles[index]["position"] as Vector2)


func _new_particle(spawn_at_top: bool) -> Dictionary:
	return {
		"position": Vector2(
			_rng.randf_range(0.0, world_size.x),
			_rng.randf_range(-24.0, 0.0) if spawn_at_top else _rng.randf_range(0.0, world_size.y)
		),
		"speed": _rng.randf_range(18.0, 58.0),
		"radius": _rng.randf_range(1.2, 3.0),
		"alpha": _rng.randf_range(0.48, 0.90),
		"phase": _rng.randf_range(0.0, TAU),
		"drift_speed": _rng.randf_range(0.7, 1.8),
		"drift": _rng.randf_range(7.0, 20.0),
	}


func _draw() -> void:
	for index: int in range(get_active_particle_count()):
		var particle: Dictionary = _particles[index]
		draw_circle(
			particle["position"],
			float(particle["radius"]),
			Color(0.94, 0.98, 1.0, float(particle["alpha"]) * intensity)
		)
