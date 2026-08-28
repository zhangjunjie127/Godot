extends Control

signal weather_changed(weather: String)
signal weather_event_started(weather: String, duration_mode: String, duration_days: float)
signal weather_event_ended(weather: String)
signal forecast_changed(forecast: Array)

const WEATHER_CLEAR := "晴朗"
const WEATHER_RAIN := "下雨"
const WEATHER_SNOW := "下雪"
const WEATHER_TYPES := [WEATHER_CLEAR, WEATHER_RAIN, WEATHER_SNOW]

const RAIN_LIGHT := "小雨"
const RAIN_MEDIUM := "中雨"
const RAIN_HEAVY := "大雨"
const RAIN_LEVELS := [RAIN_LIGHT, RAIN_MEDIUM, RAIN_HEAVY]

const SNOW_LIGHT := "小雪"
const SNOW_MEDIUM := "中雪"
const SNOW_HEAVY := "大雪"
const SNOW_LEVELS := [SNOW_LIGHT, SNOW_MEDIUM, SNOW_HEAVY]

const PRECIPITATION_DENSITIES := [0.30, 0.60, 1.0]
const PUDDLE_START_STRENGTH := 0.45
const DURATION_HALF_DAY := "半天"
const DURATION_FULL_DAY := "一天"
const DURATION_SPECIAL := "特殊事件"
const GAME_MINUTES_PER_DAY := 1440

@export_enum("晴朗", "下雨", "下雪") var start_weather := WEATHER_RAIN
@export_enum("半天", "一天") var start_duration_mode := DURATION_HALF_DAY
@export_enum("小雨", "中雨", "大雨") var start_rain_level := RAIN_MEDIUM
@export_enum("小雪", "中雪", "大雪") var start_snow_level := SNOW_MEDIUM
@export_range(0.5, 8.0, 0.1) var rain_fade_seconds := 3.0
@export var day_night_cycle_path: NodePath
@export var ground_effects_path: NodePath
@export var wetness_overlay_path: NodePath
@export var puddle_surface_path: NodePath
@export var rain_visual_effect_path: NodePath
@export var screen_rain_effect_path: NodePath
@export var snow_world_effect_path: NodePath
@export var random_seed := 0

var current_weather := WEATHER_RAIN
var current_duration_mode := DURATION_HALF_DAY
var current_rain_level := RAIN_MEDIUM
var current_snow_level := SNOW_MEDIUM
var event_duration_days := 0.5
var remaining_game_minutes := 720
var visual_rain_density := 0.0
var visual_snow_density := 0.0

var _rng := RandomNumberGenerator.new()
var _last_calendar_minute := -1
var _ground_effects: Node
var _wetness_overlay: CanvasItem
var _puddle_surface: CanvasItem
var _rain_visual_effect: Node
var _screen_rain_effect: Node
var _snow_world_effect: Node
var _target_rain_density := 0.0
var _target_snow_density := 0.0
var _forecast_queue: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_ground_effects = get_node_or_null(ground_effects_path)
	_wetness_overlay = get_node_or_null(wetness_overlay_path) as CanvasItem
	_puddle_surface = get_node_or_null(puddle_surface_path) as CanvasItem
	_rain_visual_effect = get_node_or_null(rain_visual_effect_path)
	_screen_rain_effect = get_node_or_null(screen_rain_effect_path)
	_snow_world_effect = get_node_or_null(snow_world_effect_path)
	if _puddle_surface is Sprite2D:
		var puddle_sprite := _puddle_surface as Sprite2D
		puddle_sprite.texture = ArtAssets.texture(puddle_sprite.texture.resource_path, puddle_sprite.texture)
	current_rain_level = start_rain_level if start_rain_level in RAIN_LEVELS else RAIN_MEDIUM
	current_snow_level = start_snow_level if start_snow_level in SNOW_LEVELS else SNOW_MEDIUM
	start_weather_event(_normalize_weather(start_weather), start_duration_mode)
	var day_night_cycle := get_node_or_null(day_night_cycle_path)
	if day_night_cycle != null:
		day_night_cycle.time_changed.connect(_on_time_changed)
	queue_redraw()


func _process(delta: float) -> void:
	advance_visual_seconds(delta)


func start_weather_event(weather: String, duration_mode: String, precipitation_level: String = "", preserve_forecast: bool = false) -> bool:
	weather = _normalize_weather(weather)
	if weather not in WEATHER_TYPES:
		return false
	if duration_mode not in [DURATION_HALF_DAY, DURATION_FULL_DAY, DURATION_SPECIAL]:
		return false
	if weather == WEATHER_RAIN:
		if not _set_event_level(precipitation_level, RAIN_LEVELS, RAIN_MEDIUM, true):
			return false
	elif weather == WEATHER_SNOW:
		if not _set_event_level(precipitation_level, SNOW_LEVELS, SNOW_MEDIUM, false):
			return false

	if not preserve_forecast:
		_forecast_queue.clear()
	current_weather = weather
	current_duration_mode = duration_mode
	if duration_mode == DURATION_SPECIAL:
		event_duration_days = float(_rng.randi_range(3, 10))
	elif duration_mode == DURATION_FULL_DAY:
		event_duration_days = 1.0
	else:
		event_duration_days = 0.5
	remaining_game_minutes = roundi(event_duration_days * GAME_MINUTES_PER_DAY)
	_apply_weather_visuals()
	_ensure_forecast_horizon()
	weather_changed.emit(current_weather)
	weather_event_started.emit(current_weather, current_duration_mode, event_duration_days)
	forecast_changed.emit(get_forecast(2))
	queue_redraw()
	return true


func trigger_special_weather(weather: String) -> bool:
	weather = _normalize_weather(weather)
	var level := RAIN_HEAVY if weather == WEATHER_RAIN else SNOW_HEAVY if weather == WEATHER_SNOW else ""
	return start_weather_event(weather, DURATION_SPECIAL, level)


func set_weather(weather: String) -> void:
	start_weather_event(weather, DURATION_HALF_DAY)


func set_rain_level(level: String) -> bool:
	if level not in RAIN_LEVELS:
		return false
	current_rain_level = level
	if current_weather == WEATHER_RAIN:
		_target_rain_density = _density_for_level(level, RAIN_LEVELS)
	return true


func set_snow_level(level: String) -> bool:
	if level not in SNOW_LEVELS:
		return false
	current_snow_level = level
	if current_weather == WEATHER_SNOW:
		_target_snow_density = _density_for_level(level, SNOW_LEVELS)
	return true


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
	var fade_step := delta / maxf(rain_fade_seconds, 0.1)
	visual_rain_density = move_toward(visual_rain_density, _target_rain_density, fade_step)
	visual_snow_density = move_toward(visual_snow_density, _target_snow_density, fade_step)
	_sync_rain_visual_layers()
	_sync_snow_visual_layer(delta)
	if _rain_visual_effect != null and _rain_visual_effect.has_method("advance_effects"):
		_rain_visual_effect.advance_effects(delta)


func _set_event_level(level: String, valid_levels: Array, fallback: String, is_rain: bool) -> bool:
	var selected := level
	if selected.is_empty():
		selected = current_rain_level if is_rain else current_snow_level
	if selected not in valid_levels:
		selected = fallback if level.is_empty() else ""
	if selected.is_empty():
		return false
	if is_rain:
		current_rain_level = selected
	else:
		current_snow_level = selected
	return true


func _finish_current_event() -> void:
	var finished_weather := current_weather
	weather_event_ended.emit(finished_weather)
	_ensure_forecast_horizon()
	var next_event: Dictionary = _forecast_queue.pop_front()
	var next_weather := String(next_event["weather"])
	var next_level := String(next_event.get("rain_level", "")) if next_weather == WEATHER_RAIN else String(next_event.get("snow_level", ""))
	start_weather_event(next_weather, String(next_event["duration_mode"]), next_level, true)


func _on_time_changed(day: int, hour: int, minute: int, _phase: String) -> void:
	var calendar_minute := (day - 1) * GAME_MINUTES_PER_DAY + hour * 60 + minute
	if _last_calendar_minute >= 0 and calendar_minute > _last_calendar_minute:
		advance_game_minutes(calendar_minute - _last_calendar_minute)
	_last_calendar_minute = calendar_minute


func _apply_weather_visuals() -> void:
	_target_rain_density = _density_for_level(current_rain_level, RAIN_LEVELS) if current_weather == WEATHER_RAIN else 0.0
	_target_snow_density = _density_for_level(current_snow_level, SNOW_LEVELS) if current_weather == WEATHER_SNOW else 0.0
	_sync_rain_visual_layers()
	_sync_snow_visual_layer(0.0)


func get_active_rain_particle_count() -> int:
	if _rain_visual_effect == null or not _rain_visual_effect.has_method("get_active_particle_count"):
		return 0
	return int(_rain_visual_effect.get_active_particle_count())


func get_active_snow_particle_count() -> int:
	if _snow_world_effect == null or not _snow_world_effect.has_method("get_active_particle_count"):
		return 0
	return int(_snow_world_effect.get_active_particle_count())


func get_forecast(days: int = 2) -> Array[Dictionary]:
	var day_count := clampi(days, 1, 2)
	var timeline: Array[Dictionary] = [{
		"weather": current_weather,
		"rain_level": current_rain_level if current_weather == WEATHER_RAIN else "",
		"snow_level": current_snow_level if current_weather == WEATHER_SNOW else "",
		"minutes": remaining_game_minutes,
	}]
	for event: Dictionary in _forecast_queue:
		timeline.append({
			"weather": String(event["weather"]),
			"rain_level": String(event.get("rain_level", "")),
			"snow_level": String(event.get("snow_level", "")),
			"minutes": int(event["minutes"]),
		})

	var result: Array[Dictionary] = []
	for day_index: int in range(day_count):
		var window_start := day_index * GAME_MINUTES_PER_DAY
		var window_end := window_start + GAME_MINUTES_PER_DAY
		var cursor := 0
		var weather_minutes: Dictionary = {}
		var rain_minutes: Dictionary = {}
		var snow_minutes: Dictionary = {}
		for event: Dictionary in timeline:
			var event_end := cursor + int(event["minutes"])
			var overlap := maxi(0, mini(window_end, event_end) - maxi(window_start, cursor))
			if overlap > 0:
				var weather := String(event["weather"])
				weather_minutes[weather] = int(weather_minutes.get(weather, 0)) + overlap
				var rain_level := String(event.get("rain_level", ""))
				var snow_level := String(event.get("snow_level", ""))
				if weather == WEATHER_RAIN and not rain_level.is_empty():
					rain_minutes[rain_level] = int(rain_minutes.get(rain_level, 0)) + overlap
				elif weather == WEATHER_SNOW and not snow_level.is_empty():
					snow_minutes[snow_level] = int(snow_minutes.get(snow_level, 0)) + overlap
			cursor = event_end
			if cursor >= window_end:
				break
		var dominant_weather := _largest_bucket(weather_minutes, WEATHER_CLEAR)
		result.append({
			"day_offset": day_index + 1,
			"weather": dominant_weather,
			"rain_level": _largest_bucket(rain_minutes, RAIN_MEDIUM) if dominant_weather == WEATHER_RAIN else "",
			"snow_level": _largest_bucket(snow_minutes, SNOW_MEDIUM) if dominant_weather == WEATHER_SNOW else "",
		})
	return result


func get_scheduled_events() -> Array[Dictionary]:
	return _forecast_queue.duplicate(true)


func _sync_rain_visual_layers() -> void:
	var wet_strength := clampf(visual_rain_density * 1.25, 0.0, 1.0)
	if _rain_visual_effect != null and _rain_visual_effect.has_method("set_intensity"):
		_rain_visual_effect.set_intensity(visual_rain_density)
	if _wetness_overlay != null:
		_wetness_overlay.visible = wet_strength > 0.001
		_wetness_overlay.modulate.a = 1.0
		if _wetness_overlay.material != null:
			_wetness_overlay.material.set_shader_parameter("rain_intensity", wet_strength)
	if _puddle_surface != null:
		_puddle_surface.visible = wet_strength > PUDDLE_START_STRENGTH
		if _puddle_surface.material != null:
			_puddle_surface.material.set_shader_parameter("rain_intensity", wet_strength)
	if _ground_effects != null and _ground_effects.has_method("set_rain_strength"):
		_ground_effects.set_rain_strength(wet_strength)
	if _screen_rain_effect != null and _screen_rain_effect.has_method("set_intensity"):
		_screen_rain_effect.set_intensity(visual_rain_density)


func _sync_snow_visual_layer(delta: float) -> void:
	if _snow_world_effect == null:
		return
	if _snow_world_effect.has_method("set_intensity"):
		_snow_world_effect.set_intensity(visual_snow_density)
	if visual_snow_density > 0.001 and delta > 0.0 and _snow_world_effect.has_method("advance_effects"):
		_snow_world_effect.advance_effects(delta)


func _density_for_level(level: String, levels: Array) -> float:
	var index := levels.find(level)
	return PRECIPITATION_DENSITIES[index] if index >= 0 else PRECIPITATION_DENSITIES[1]


func _random_rain_level() -> String:
	return RAIN_LEVELS[_rng.randi_range(0, RAIN_LEVELS.size() - 1)]


func _random_snow_level() -> String:
	return SNOW_LEVELS[_rng.randi_range(0, SNOW_LEVELS.size() - 1)]


func _ensure_forecast_horizon() -> void:
	var queued_minutes := 0
	for event: Dictionary in _forecast_queue:
		queued_minutes += int(event["minutes"])
	var previous_weather := current_weather if _forecast_queue.is_empty() else String(_forecast_queue.back()["weather"])
	while queued_minutes < GAME_MINUTES_PER_DAY * 2:
		var event := _random_event_after(previous_weather)
		_forecast_queue.append(event)
		queued_minutes += int(event["minutes"])
		previous_weather = String(event["weather"])


func _random_event_after(previous_weather: String) -> Dictionary:
	var weather := WEATHER_CLEAR
	var duration_mode := DURATION_HALF_DAY
	var rain_level := ""
	var snow_level := ""
	if previous_weather == WEATHER_CLEAR:
		weather = WEATHER_RAIN if _rng.randi_range(0, 1) == 0 else WEATHER_SNOW
		duration_mode = DURATION_HALF_DAY if _rng.randi_range(0, 1) == 0 else DURATION_FULL_DAY
		if weather == WEATHER_RAIN:
			rain_level = _random_rain_level()
		else:
			snow_level = _random_snow_level()
	return {
		"weather": weather,
		"duration_mode": duration_mode,
		"rain_level": rain_level,
		"snow_level": snow_level,
		"minutes": 720 if duration_mode == DURATION_HALF_DAY else 1440,
	}


func _largest_bucket(buckets: Dictionary, fallback: String) -> String:
	var result := fallback
	var largest := -1
	for key: Variant in buckets:
		var value := int(buckets[key])
		if value > largest:
			largest = value
			result = String(key)
	return result


func _normalize_weather(weather: String) -> String:
	return WEATHER_SNOW if weather == "寒冬" else weather
