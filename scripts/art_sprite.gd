@tool
extends Sprite2D

@export_group("Palm Wind / 椰树风动")
@export var palm_wind_enabled := true
@export_range(0.0, 6.0, 0.1) var palm_sway_degrees := 2.2
@export_range(0.1, 3.0, 0.05) var palm_sway_speed := 0.65
@export_range(0.0, 3.0, 0.05) var palm_gust_degrees := 0.9
@export_range(0.1, 8.0, 0.1) var palm_wind_response := 1.4

var _palm_wind_active := false
var _wind_elapsed := 0.0
var _wind_phase := 0.0
var _speed_variation := 1.0
var _target_wind_strength := 0.4
var _current_wind_strength := 0.4
var _wind_strength_override := -1.0
var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _trunk_offset := Vector2.ZERO
var _trunk_anchor := Vector2.ZERO
var _weather: Node


func _ready() -> void:
	if texture != null:
		texture = ArtAssets.texture(texture.resource_path, texture)
	_palm_wind_active = not Engine.is_editor_hint() and palm_wind_enabled and _is_palm_texture()
	set_process(_palm_wind_active)
	if not _palm_wind_active:
		return
	add_to_group("wind_vegetation")
	_base_position = position
	_base_rotation = rotation
	_trunk_offset = Vector2(0.0, float(texture.get_height()) * absf(scale.y) * 0.5)
	_trunk_anchor = _base_position + _trunk_offset.rotated(_base_rotation)
	var phase_seed := float(absi(String(get_path()).hash()) % 10000) / 10000.0
	_wind_phase = phase_seed * TAU
	_speed_variation = 0.9 + fposmod(phase_seed * 7.13, 1.0) * 0.2
	_weather = _find_weather()


func _process(delta: float) -> void:
	advance_wind(delta)


func advance_wind(seconds: float) -> void:
	if not _palm_wind_active:
		return
	if _weather == null:
		_weather = _find_weather()
	_target_wind_strength = _wind_strength_override if _wind_strength_override >= 0.0 else _weather_wind_strength()
	var delta := maxf(seconds, 0.0)
	_current_wind_strength = move_toward(_current_wind_strength, _target_wind_strength, delta * palm_wind_response)
	_wind_elapsed += delta
	var wind_time := _wind_elapsed * palm_sway_speed * _speed_variation
	var primary := sin(wind_time + _wind_phase)
	var secondary := sin(wind_time * 0.47 + _wind_phase * 1.7) * 0.26
	var gust_envelope := pow(maxf(sin(wind_time * 0.23 + _wind_phase * 1.3), 0.0), 4.0)
	var gust := sin(wind_time * 2.4 + _wind_phase * 0.4) * gust_envelope
	var flutter := sin(wind_time * 3.7 + _wind_phase * 2.1) * 0.08
	var sway_degrees := (palm_sway_degrees * (primary * 0.74 + secondary + flutter) + palm_gust_degrees * gust) * _current_wind_strength
	rotation = _base_rotation + deg_to_rad(sway_degrees)
	position = _trunk_anchor - _trunk_offset.rotated(rotation)


func set_wind_strength(strength: float) -> void:
	_wind_strength_override = maxf(strength, 0.0)


func clear_wind_strength_override() -> void:
	_wind_strength_override = -1.0


func get_trunk_anchor_position() -> Vector2:
	return position + _trunk_offset.rotated(rotation)


func get_current_wind_strength() -> float:
	return _current_wind_strength


func _is_palm_texture() -> bool:
	return texture != null and "/vegetation/palms/" in texture.resource_path


func _find_weather() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Weather/Effect") if scene != null else null


func _weather_wind_strength() -> float:
	if _weather == null:
		return 0.4
	match String(_weather.get("current_weather")):
		"阴天":
			return 0.65
		"下雨":
			return lerpf(0.65, 1.35, clampf(float(_weather.get("visual_rain_density")), 0.0, 1.0))
		"下雪":
			return lerpf(0.55, 1.0, clampf(float(_weather.get("visual_snow_density")), 0.0, 1.0))
		_:
			return 0.38
