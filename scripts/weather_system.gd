extends Control

signal weather_changed(weather: String)
signal weather_event_started(weather: String, duration_mode: String, duration_days: float)
signal weather_event_ended(weather: String)

const WEATHER_CLEAR := "晴朗"
const WEATHER_RAIN := "下雨"
const WEATHER_SNOW := "下雪"
const WEATHER_TYPES := [WEATHER_CLEAR, WEATHER_RAIN, WEATHER_SNOW]

const DURATION_HALF_DAY := "半天"
const DURATION_FULL_DAY := "一天"
const DURATION_SPECIAL := "特殊事件"
const GAME_MINUTES_PER_DAY := 1440

@export_enum("晴朗", "下雨", "下雪") var start_weather := WEATHER_RAIN
@export_enum("半天", "一天") var start_duration_mode := DURATION_HALF_DAY
@export var day_night_cycle_path: NodePath
@export var random_seed := 0

var current_weather := WEATHER_RAIN
var current_duration_mode := DURATION_HALF_DAY
var event_duration_days := 0.5
var remaining_game_minutes := 720

var _rng := RandomNumberGenerator.new()
var _last_calendar_minute := -1
var _rain_particles: Array[Dictionary] = []
var _snow_particles: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	resized.connect(_reset_particles)
	_reset_particles()
	start_weather_event(_normalize_weather(start_weather), start_duration_mode)
	var day_night_cycle := get_node_or_null(day_night_cycle_path)
	if day_night_cycle != null:
		day_night_cycle.time_changed.connect(_on_time_changed)
	queue_redraw()


func _process(delta: float) -> void:
	advance_visual_seconds(delta)


func start_weather_event(weather: String, duration_mode: String) -> bool:
	weather = _normalize_weather(weather)
	if weather not in WEATHER_TYPES:
		return false
	if duration_mode not in [DURATION_HALF_DAY, DURATION_FULL_DAY, DURATION_SPECIAL]:
		return false

	current_weather = weather
	current_duration_mode = duration_mode
	if duration_mode == DURATION_SPECIAL:
		event_duration_days = float(_rng.randi_range(3, 10))
	elif duration_mode == DURATION_FULL_DAY:
		event_duration_days = 1.0
	else:
		event_duration_days = 0.5
	remaining_game_minutes = roundi(event_duration_days * GAME_MINUTES_PER_DAY)
	weather_changed.emit(current_weather)
	weather_event_started.emit(current_weather, current_duration_mode, event_duration_days)
	queue_redraw()
	return true


func trigger_special_weather(weather: String) -> bool:
	return start_weather_event(weather, DURATION_SPECIAL)


func set_weather(weather: String) -> void:
	start_weather_event(weather, DURATION_HALF_DAY)


func advance_game_minutes(minutes: int) -> void:
	var minutes_left := maxi(minutes, 0)
	while minutes_left > 0:
		if minutes_left < remaining_game_minutes:
			remaining_game_minutes -= minutes_left
			return
		minutes_left -= remaining_game_minutes
		_finish_current_event()


func advance_visual_seconds(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	if current_weather == WEATHER_RAIN:
		_update_rain(delta)
	elif current_weather == WEATHER_SNOW:
		_update_snow(delta)
	queue_redraw()


func _finish_current_event() -> void:
	var finished_weather := current_weather
	weather_event_ended.emit(finished_weather)
	if finished_weather == WEATHER_CLEAR:
		var next_weather: String = WEATHER_RAIN if _rng.randi_range(0, 1) == 0 else WEATHER_SNOW
		var next_duration: String = DURATION_HALF_DAY if _rng.randi_range(0, 1) == 0 else DURATION_FULL_DAY
		start_weather_event(next_weather, next_duration)
	else:
		start_weather_event(WEATHER_CLEAR, DURATION_HALF_DAY)


func _on_time_changed(day: int, hour: int, minute: int, _phase: String) -> void:
	var calendar_minute := (day - 1) * GAME_MINUTES_PER_DAY + hour * 60 + minute
	if _last_calendar_minute >= 0 and calendar_minute > _last_calendar_minute:
		advance_game_minutes(calendar_minute - _last_calendar_minute)
	_last_calendar_minute = calendar_minute


func _reset_particles() -> void:
	_rain_particles.clear()
	_snow_particles.clear()
	for _index: int in range(96):
		_rain_particles.append(_new_rain_particle(false))
	for _index: int in range(72):
		_snow_particles.append(_new_snow_particle(false))


func _new_rain_particle(spawn_above: bool) -> Dictionary:
	var viewport_size := _effect_size()
	var speed := _rng.randf_range(320.0, 620.0)
	return {
		"position": Vector2(
			_rng.randf_range(0.0, viewport_size.x + 100.0),
			_rng.randf_range(-90.0, -8.0) if spawn_above else _rng.randf_range(-40.0, viewport_size.y)
		),
		"velocity": Vector2(_rng.randf_range(-120.0, -55.0), speed),
		"length": _rng.randf_range(8.0, 20.0),
		"alpha": _rng.randf_range(0.28, 0.72),
		"width": _rng.randf_range(0.7, 1.35),
	}


func _new_snow_particle(spawn_above: bool) -> Dictionary:
	var viewport_size := _effect_size()
	return {
		"position": Vector2(
			_rng.randf_range(0.0, viewport_size.x),
			_rng.randf_range(-30.0, -5.0) if spawn_above else _rng.randf_range(-20.0, viewport_size.y)
		),
		"speed": _rng.randf_range(20.0, 62.0),
		"radius": _rng.randf_range(0.8, 2.2),
		"alpha": _rng.randf_range(0.48, 0.9),
		"phase": _rng.randf_range(0.0, TAU),
		"drift_speed": _rng.randf_range(0.7, 1.8),
		"drift": _rng.randf_range(7.0, 20.0),
	}


func _update_rain(delta: float) -> void:
	var viewport_size := _effect_size()
	for particle: Dictionary in _rain_particles:
		var position: Vector2 = particle["position"]
		position += (particle["velocity"] as Vector2) * delta
		if position.y > viewport_size.y + 24.0 or position.x < -30.0:
			particle.assign(_new_rain_particle(true))
		else:
			particle["position"] = position


func _update_snow(delta: float) -> void:
	var viewport_size := _effect_size()
	for particle: Dictionary in _snow_particles:
		var phase: float = float(particle["phase"]) + float(particle["drift_speed"]) * delta
		var position: Vector2 = particle["position"]
		position.x += sin(phase) * float(particle["drift"]) * delta
		position.y += float(particle["speed"]) * delta
		particle["phase"] = phase
		if position.y > viewport_size.y + 8.0 or position.x < -16.0 or position.x > viewport_size.x + 16.0:
			particle.assign(_new_snow_particle(true))
		else:
			particle["position"] = position


func _draw() -> void:
	if current_weather == WEATHER_RAIN:
		_draw_rain()
	elif current_weather == WEATHER_SNOW:
		_draw_snow()


func _draw_rain() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.17, 0.24, 0.12))
	for particle: Dictionary in _rain_particles:
		var head: Vector2 = particle["position"]
		var velocity: Vector2 = particle["velocity"]
		var tail := head - velocity.normalized() * float(particle["length"])
		draw_line(tail, head, Color(0.68, 0.84, 0.94, float(particle["alpha"])), float(particle["width"]), true)


func _draw_snow() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.66, 0.79, 0.88, 0.14))
	for particle: Dictionary in _snow_particles:
		draw_circle(
			particle["position"],
			float(particle["radius"]),
			Color(0.94, 0.98, 1.0, float(particle["alpha"]))
		)


func _effect_size() -> Vector2:
	return Vector2(maxf(size.x, 640.0), maxf(size.y, 360.0))


func _normalize_weather(weather: String) -> String:
	return WEATHER_SNOW if weather == "寒冬" else weather
