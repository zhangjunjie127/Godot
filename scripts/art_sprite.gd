@tool
extends Sprite2D

const GROUND_SHADOW_MATERIAL := preload("res://art/ground_shadow_material.tres")
const GROUND_SHADOW_SCRIPT := preload("res://scripts/ground_shadow.gd")
const VEGETATION_WIND_SHADER := preload("res://shaders/vegetation_wind.gdshader")
const SHADOW_MODE_AUTO := 0
const SHADOW_MODE_ENABLED := 1
const SHADOW_MODE_DISABLED := 2
const BLOCKER_LAYER := 2
const VEGETATION_DIRECTORIES := [
	"/palms/", "/trees/", "/deadwood/", "/tropical_plants/", "/vines/",
	"/flowering_plants/", "/foliage/", "/grasses/", "/groundcover/",
]
const WIND_DIRECTORIES := ["/palms/", "/trees/", "/tropical_plants/", "/foliage/"]

@export_group("Vegetation Wind / 植被风动")
@export_enum("Auto / 自动", "Enabled / 启用", "Disabled / 禁用") var wind_mode := SHADOW_MODE_AUTO
@export_range(0.0, 2.5, 0.05) var wind_strength_multiplier := 1.0
@export_range(0.1, 8.0, 0.1) var wind_response := 1.4
@export var use_custom_wind_profile := false
@export_range(0.0, 20.0, 0.1) var custom_trunk_sway_pixels := 4.0
@export_range(0.0, 40.0, 0.1) var custom_leaf_sway_pixels := 16.0
@export_range(0.1, 3.0, 0.05) var custom_trunk_speed := 0.6
@export_range(0.1, 4.0, 0.05) var custom_leaf_speed := 1.4
@export_range(0.0, 0.35, 0.01) var custom_root_lock_height := 0.1
@export_range(0.0, 0.85, 0.01) var custom_canopy_start_height := 0.4

@export_group("Ground Shadow / 地面投影")
@export_enum("Auto / 自动", "Enabled / 启用", "Disabled / 禁用") var ground_shadow_mode := SHADOW_MODE_AUTO
@export_range(-180.0, 180.0, 1.0) var ground_shadow_direction_degrees := 140.0
@export_range(0.0, 160.0, 1.0) var ground_shadow_distance := 0.0
@export var ground_shadow_local_offset := Vector2.ZERO
@export var ground_shadow_scale := Vector2(-0.9, 0.8)
@export_range(0.0, 1.0, 0.01) var ground_shadow_strength := 1.0
@export_subgroup("Root Contact / 根部接触")
@export var ground_contact_shadow_enabled := false
@export_range(0.01, 0.25, 0.005) var ground_contact_shadow_width_ratio := 0.07
@export var ground_contact_shadow_scale := Vector2(1.0, 0.30)
@export_range(0.0, 1.0, 0.01) var ground_contact_shadow_strength := 1.0

@export_group("Root Collision / 根部阻挡")
@export_enum("Auto / 自动", "Enabled / 启用", "Disabled / 禁用") var root_collision_mode := SHADOW_MODE_AUTO
@export_range(0.25, 2.0, 0.05) var root_collision_radius_multiplier := 1.0
@export var root_collision_local_offset := Vector2.ZERO

static var _shared_wind_material: ShaderMaterial

var _wind_active := false
var _wind_elapsed := 0.0
var _wind_phase := 0.0
var _speed_variation := 1.0
var _target_wind_strength := 0.4
var _current_wind_strength := 0.4
var _wind_strength_override := -1.0
var _base_material: Material
var _weather: Node
var _ground_shadow: Sprite2D
var _ground_contact_shadow: Node2D
var _vegetation_blocker: StaticBody2D
var _vegetation_collision: CollisionShape2D
var _shadow_signature := ""
var _source_texture_path := ""


func _ready() -> void:
	_base_material = material
	if texture != null:
		_source_texture_path = texture.resource_path
		texture = ArtAssets.texture(texture.resource_path, texture)
	var phase_seed := float(absi(String(get_path()).hash()) % 10000) / 10000.0
	_wind_phase = phase_seed * TAU
	_speed_variation = 0.9 + fposmod(phase_seed * 7.13, 1.0) * 0.2
	_wind_active = _wind_is_enabled()
	_sync_wind_material()
	_sync_ground_shadow()
	_sync_vegetation_collision()
	_shadow_signature = _ground_shadow_signature()
	set_process(Engine.is_editor_hint() or _wind_active)
	if not _wind_active:
		return
	add_to_group("wind_vegetation")
	_weather = _find_weather()
	advance_wind(0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		var signature := _ground_shadow_signature()
		if signature != _shadow_signature:
			_wind_active = _wind_is_enabled()
			_sync_wind_material()
			_sync_ground_shadow()
			_sync_vegetation_collision()
			_shadow_signature = signature
	advance_wind(delta)


func advance_wind(seconds: float) -> void:
	if not _wind_active:
		return
	if _weather == null:
		_weather = _find_weather()
	_target_wind_strength = (_wind_strength_override if _wind_strength_override >= 0.0 else _weather_wind_strength()) * wind_strength_multiplier
	var delta := maxf(seconds, 0.0)
	_current_wind_strength = move_toward(_current_wind_strength, _target_wind_strength, delta * wind_response)
	_wind_elapsed += delta
	set_instance_shader_parameter("wind_time", _wind_elapsed)
	set_instance_shader_parameter("wind_strength", _current_wind_strength)


func set_wind_strength(strength: float) -> void:
	_wind_strength_override = maxf(strength, 0.0)


func clear_wind_strength_override() -> void:
	_wind_strength_override = -1.0


func get_trunk_anchor_position() -> Vector2:
	return transform * _local_ground_anchor()


func get_current_wind_strength() -> float:
	return _current_wind_strength


func set_ground_shadow_direction(direction_degrees: float, distance: float) -> void:
	ground_shadow_direction_degrees = wrapf(direction_degrees, -180.0, 180.0)
	ground_shadow_distance = maxf(distance, 0.0)
	_sync_ground_shadow()


func get_ground_shadow_cast_direction() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(ground_shadow_direction_degrees))


func _wind_is_enabled() -> bool:
	if wind_mode == SHADOW_MODE_ENABLED:
		return true
	if wind_mode == SHADOW_MODE_DISABLED:
		return false
	var path := _art_path()
	for directory: String in WIND_DIRECTORIES:
		if directory in path:
			return true
	return false


func _sync_wind_material() -> void:
	if not _wind_active or texture == null:
		if material == _shared_wind_material:
			material = _base_material
		return
	material = _wind_material()
	var profile := _wind_profile()
	set_instance_shader_parameter("wind_phase", _wind_phase)
	set_instance_shader_parameter("trunk_amplitude_pixels", float(profile["trunk_amplitude"]))
	set_instance_shader_parameter("leaf_amplitude_pixels", float(profile["leaf_amplitude"]))
	set_instance_shader_parameter("trunk_speed", float(profile["trunk_speed"]) * _speed_variation)
	set_instance_shader_parameter("leaf_speed", float(profile["leaf_speed"]) * _speed_variation)
	set_instance_shader_parameter("root_lock_height", float(profile["root_lock_height"]))
	set_instance_shader_parameter("canopy_start_height", float(profile["canopy_start_height"]))


func _wind_profile() -> Dictionary:
	if use_custom_wind_profile:
		return {
			"trunk_amplitude": custom_trunk_sway_pixels,
			"leaf_amplitude": custom_leaf_sway_pixels,
			"trunk_speed": custom_trunk_speed,
			"leaf_speed": custom_leaf_speed,
			"root_lock_height": custom_root_lock_height,
			"canopy_start_height": custom_canopy_start_height,
		}
	var path := _art_path()
	if "/palms/" in path:
		return _profile(5.0, 22.0, 0.62, 1.55, 0.12, 0.46)
	if "/trees/" in path:
		return _profile(4.0, 18.0, 0.50, 1.30, 0.10, 0.42)
	if "/tropical_plants/" in path:
		return _profile(1.8, 15.0, 0.72, 1.72, 0.10, 0.18)
	return _profile(1.0, 10.0, 0.88, 1.90, 0.10, 0.14)


func _profile(trunk_amplitude: float, leaf_amplitude: float, trunk_speed: float, leaf_speed: float, root_lock_height: float, canopy_start_height: float) -> Dictionary:
	return {
		"trunk_amplitude": trunk_amplitude,
		"leaf_amplitude": leaf_amplitude,
		"trunk_speed": trunk_speed,
		"leaf_speed": leaf_speed,
		"root_lock_height": root_lock_height,
		"canopy_start_height": canopy_start_height,
	}


func _wind_material() -> ShaderMaterial:
	if _shared_wind_material == null:
		_shared_wind_material = ShaderMaterial.new()
		_shared_wind_material.shader = ArtAssets.shader(VEGETATION_WIND_SHADER.resource_path, VEGETATION_WIND_SHADER)
	return _shared_wind_material


func _sync_ground_shadow() -> void:
	var enabled := _ground_shadow_is_enabled()
	if not enabled or texture == null:
		if _ground_shadow != null:
			_ground_shadow.visible = false
		if _ground_contact_shadow != null:
			_ground_contact_shadow.visible = false
		return
	if _ground_shadow == null:
		_ground_shadow = Sprite2D.new()
		_ground_shadow.name = "GroundShadow"
		_ground_shadow.z_index = -1
		_ground_shadow.show_behind_parent = true
		add_child(_ground_shadow)
	if not is_in_group("ground_shadow_vegetation"):
		add_to_group("ground_shadow_vegetation")

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
	_ground_shadow.rotation = deg_to_rad(ground_shadow_direction_degrees + 90.0)
	_ground_shadow.skew = 0.0
	_ground_shadow.scale = ground_shadow_scale
	_ground_shadow.self_modulate = Color(1.0, 1.0, 1.0, ground_shadow_strength)

	var ground_anchor := _local_ground_anchor()
	var cast_offset := get_ground_shadow_cast_direction() * ground_shadow_distance + ground_shadow_local_offset
	_ground_shadow.position = Vector2.ZERO
	var projected_anchor := _ground_shadow.transform * ground_anchor
	_ground_shadow.position = ground_anchor + cast_offset - projected_anchor
	_sync_ground_contact_shadow(ground_anchor)


func _sync_ground_contact_shadow(ground_anchor: Vector2) -> void:
	if not ground_contact_shadow_enabled:
		if _ground_contact_shadow != null:
			_ground_contact_shadow.visible = false
		return
	if _ground_contact_shadow == null:
		_ground_contact_shadow = GROUND_SHADOW_SCRIPT.new()
		_ground_contact_shadow.name = "GroundContactShadow"
		add_child(_ground_contact_shadow)
	var contact_radius := maxf(_frame_size().x * ground_contact_shadow_width_ratio, 1.0)
	_ground_contact_shadow.configure(
		ground_anchor + ground_shadow_local_offset,
		contact_radius,
		ground_contact_shadow_scale,
		ground_contact_shadow_strength,
		true
	)


func _ground_shadow_is_enabled() -> bool:
	if ground_shadow_mode == SHADOW_MODE_ENABLED:
		return true
	if ground_shadow_mode == SHADOW_MODE_DISABLED:
		return false
	var path := _art_path()
	for directory: String in VEGETATION_DIRECTORIES:
		if directory in path:
			return true
	return false


func _sync_vegetation_collision() -> void:
	var enabled := _root_collision_is_enabled() and not _parent_has_manual_blocker()
	if not enabled or texture == null:
		if _vegetation_collision != null:
			_vegetation_collision.disabled = true
		return
	if _vegetation_blocker == null:
		_vegetation_blocker = StaticBody2D.new()
		_vegetation_blocker.name = "VegetationBlocker"
		_vegetation_blocker.collision_layer = BLOCKER_LAYER
		_vegetation_blocker.collision_mask = 0
		add_child(_vegetation_blocker)
		_vegetation_collision = CollisionShape2D.new()
		_vegetation_collision.name = "CollisionShape2D"
		_vegetation_blocker.add_child(_vegetation_collision)
	_vegetation_collision.disabled = false
	var frame_size := _frame_size()
	var ground_anchor := offset + (Vector2(0.0, frame_size.y * 0.5) if centered else Vector2(frame_size.x * 0.5, frame_size.y))
	var profile := _root_collision_profile()
	var sprite_scale := maxf(absf(scale.x), 0.001)
	var world_radius := clampf(frame_size.x * sprite_scale * profile.x * root_collision_radius_multiplier, 4.0, 30.0)
	var circle := CircleShape2D.new()
	circle.radius = world_radius / sprite_scale
	_vegetation_collision.shape = circle
	_vegetation_collision.position = ground_anchor - Vector2(0.0, frame_size.y * profile.y) + root_collision_local_offset


func _root_collision_is_enabled() -> bool:
	if root_collision_mode == SHADOW_MODE_ENABLED:
		return true
	if root_collision_mode == SHADOW_MODE_DISABLED:
		return false
	var path := _art_path()
	for directory: String in VEGETATION_DIRECTORIES:
		if directory in path:
			return true
	return false


func _parent_has_manual_blocker() -> bool:
	var holder := get_parent()
	return holder != null and holder.get_node_or_null("Blocker") is StaticBody2D


func _root_collision_profile() -> Vector2:
	var path := _art_path()
	if "/palms/" in path or "/trees/" in path:
		return Vector2(0.10, 0.04)
	if "/deadwood/" in path:
		return Vector2(0.18, 0.06)
	if "/tropical_plants/" in path or "/foliage/" in path:
		return Vector2(0.13, 0.06)
	return Vector2(0.10, 0.08)


func _frame_size() -> Vector2:
	if region_enabled:
		return region_rect.size
	return Vector2(
		float(texture.get_width()) / float(maxi(hframes, 1)),
		float(texture.get_height()) / float(maxi(vframes, 1))
	)


func _local_ground_anchor() -> Vector2:
	var frame_size := _frame_size()
	var texture_anchor := Vector2(frame_size.x * 0.5, frame_size.y)
	if texture != null and not region_enabled and hframes == 1 and vframes == 1:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var opaque_bounds := image.get_used_rect()
			if opaque_bounds.has_area():
				texture_anchor = Vector2(
					opaque_bounds.position.x + opaque_bounds.size.x * 0.5,
					opaque_bounds.end.y
				)
	if flip_h:
		texture_anchor.x = frame_size.x - texture_anchor.x
	if flip_v:
		texture_anchor.y = frame_size.y - texture_anchor.y
	return offset + (texture_anchor - frame_size * 0.5 if centered else texture_anchor)


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
		wind_mode,
		wind_strength_multiplier,
		wind_response,
		use_custom_wind_profile,
		custom_trunk_sway_pixels,
		custom_leaf_sway_pixels,
		custom_trunk_speed,
		custom_leaf_speed,
		custom_root_lock_height,
		custom_canopy_start_height,
		ground_shadow_mode,
		ground_shadow_direction_degrees,
		ground_shadow_distance,
		ground_shadow_local_offset,
		ground_shadow_scale,
		ground_shadow_strength,
		ground_contact_shadow_enabled,
		ground_contact_shadow_width_ratio,
		ground_contact_shadow_scale,
		ground_contact_shadow_strength,
		root_collision_mode,
		root_collision_radius_multiplier,
		root_collision_local_offset,
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
