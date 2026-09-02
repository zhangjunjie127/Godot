@tool
extends Sprite2D

const GROUND_SHADOW_MATERIAL := preload("res://art/ground_shadow_material.tres")
const SHADOW_MODE_AUTO := 0
const SHADOW_MODE_ENABLED := 1
const SHADOW_MODE_DISABLED := 2
const TALL_PROP_DIRECTORIES := ["/palms/", "/trees/", "/deadwood/", "/tropical_plants/"]

@export_group("Palm Wind / 椰树风动")
@export var palm_wind_enabled := true
@export_range(0.0, 6.0, 0.1) var palm_sway_degrees := 2.2
@export_range(0.1, 3.0, 0.05) var palm_sway_speed := 0.65
@export_range(0.0, 3.0, 0.05) var palm_gust_degrees := 0.9
@export_range(0.1, 8.0, 0.1) var palm_wind_response := 1.4

@export_group("Ground Shadow / 地面投影")
@export_enum("Auto / 自动", "Enabled / 启用", "Disabled / 禁用") var ground_shadow_mode := SHADOW_MODE_AUTO
@export var ground_shadow_offset := Vector2(34.0, -8.0)
@export var ground_shadow_scale := Vector2(0.52, 0.22)
@export_range(-60.0, 60.0, 1.0) var ground_shadow_skew_degrees := -28.0
@export_range(0.0, 1.0, 0.01) var ground_shadow_strength := 0.92

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
var _ground_shadow: Sprite2D
var _shadow_signature := ""
var _source_texture_path := ""


func _ready() -> void:
	if texture != null:
		_source_texture_path = texture.resource_path
		texture = ArtAssets.texture(texture.resource_path, texture)
	_palm_wind_active = not Engine.is_editor_hint() and palm_wind_enabled and _is_palm_texture()
	_sync_ground_shadow()
	_shadow_signature = _ground_shadow_signature()
	set_process(Engine.is_editor_hint() or _palm_wind_active)
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
	if Engine.is_editor_hint():
		var signature := _ground_shadow_signature()
		if signature != _shadow_signature:
			_sync_ground_shadow()
			_shadow_signature = signature
		return
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
	return "/vegetation/palms/" in _art_path()


func _sync_ground_shadow() -> void:
	var enabled := _ground_shadow_is_enabled()
	if not enabled or texture == null:
		if _ground_shadow != null:
			_ground_shadow.visible = false
		return
	if _ground_shadow == null:
		_ground_shadow = Sprite2D.new()
		_ground_shadow.name = "GroundShadow"
		_ground_shadow.z_index = -1
		_ground_shadow.show_behind_parent = true
		add_child(_ground_shadow)

	_ground_shadow.visible = true
	_ground_shadow.material = GROUND_SHADOW_MATERIAL
	_ground_shadow.texture = texture
	_ground_shadow.texture_filter = texture_filter
	_ground_shadow.centered = centered
	_ground_shadow.offset = offset
	_ground_shadow.region_enabled = region_enabled
	_ground_shadow.region_rect = region_rect
	_ground_shadow.hframes = hframes
	_ground_shadow.vframes = vframes
	_ground_shadow.frame = frame
	_ground_shadow.flip_h = flip_h
	_ground_shadow.flip_v = flip_v
	_ground_shadow.rotation = 0.0
	_ground_shadow.skew = deg_to_rad(ground_shadow_skew_degrees)
	_ground_shadow.scale = ground_shadow_scale
	_ground_shadow.self_modulate = Color(1.0, 1.0, 1.0, ground_shadow_strength)

	var frame_size := _frame_size()
	var ground_anchor := offset + (Vector2(0.0, frame_size.y * 0.5) if centered else Vector2(frame_size.x * 0.5, frame_size.y))
	_ground_shadow.position = Vector2.ZERO
	var projected_anchor := _ground_shadow.transform * ground_anchor
	_ground_shadow.position = ground_anchor + ground_shadow_offset - projected_anchor


func _ground_shadow_is_enabled() -> bool:
	if ground_shadow_mode == SHADOW_MODE_ENABLED:
		return true
	if ground_shadow_mode == SHADOW_MODE_DISABLED:
		return false
	var path := _art_path()
	for directory: String in TALL_PROP_DIRECTORIES:
		if directory in path:
			return true
	return false


func _frame_size() -> Vector2:
	if region_enabled:
		return region_rect.size
	return Vector2(
		float(texture.get_width()) / float(maxi(hframes, 1)),
		float(texture.get_height()) / float(maxi(vframes, 1))
	)


func _art_path() -> String:
	if not _source_texture_path.is_empty():
		return _source_texture_path
	return texture.resource_path if texture != null else ""


func _ground_shadow_signature() -> String:
	return str([
		_art_path(),
		texture.resource_path if texture != null else "",
		texture_filter,
		centered,
		offset,
		region_enabled,
		region_rect,
		ground_shadow_mode,
		ground_shadow_offset,
		ground_shadow_scale,
		ground_shadow_skew_degrees,
		ground_shadow_strength,
		hframes,
		vframes,
		frame,
		flip_h,
		flip_v,
	])


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
