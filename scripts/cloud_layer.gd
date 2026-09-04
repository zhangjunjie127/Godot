extends Node2D

const CLOUD_SHADOW_SHADER := preload("res://shaders/cloud_shadow.gdshader")

@export_group("Art / Procedural Cloud Shadow")
@export var cloud_shadow_shader: Shader = CLOUD_SHADOW_SHADER

@export_group("Shadow Composition")
@export_range(0.0, 1.0, 0.01) var clear_shadow_coverage := 0.44
@export_range(0.0, 1.0, 0.01) var overcast_shadow_coverage := 0.52
@export var clear_shadow_multiplier := Color(0.60, 0.70, 0.64, 1.0)
@export var overcast_shadow_multiplier := Color(0.66, 0.72, 0.74, 1.0)
@export_range(0.0, 1.0, 0.01) var clear_cloud_density := 0.46
@export_range(0.0, 1.0, 0.01) var overcast_cloud_density := 0.72
@export_range(400.0, 3200.0, 50.0) var cloud_scale := 1450.0
@export_range(0.01, 0.25, 0.01) var edge_softness := 0.08

@export_group("Cloud Motion")
@export var weather_path: NodePath
@export var day_night_cycle_path: NodePath
@export var wind_velocity := Vector2(30.0, 3.0)
@export var shape_velocity := Vector2(11.0, -7.0)
@export var world_size := Vector2(2048.0, 2048.0)

var current_weather := "下雨"
var _primary_offset := Vector2.ZERO
var _shape_offset := Vector2(631.0, 277.0)
var _shadow_material: ShaderMaterial
var _shadow_surface: Polygon2D

@onready var day_night_cycle = get_node_or_null(day_night_cycle_path)


func _ready() -> void:
	var weather := get_node_or_null(weather_path)
	if weather != null:
		weather.weather_changed.connect(set_weather)
		current_weather = weather.current_weather
	if day_night_cycle != null:
		day_night_cycle.time_changed.connect(_on_time_changed)
	_populate_shadow_surface()
	set_weather(current_weather)


func _process(delta: float) -> void:
	advance_clouds(delta)


func set_weather(value: String) -> void:
	current_weather = value
	visible = current_weather in ["晴朗", "阴天"]
	_sync_shadow_material()


func advance_clouds(seconds: float) -> void:
	if not visible:
		return
	var elapsed := maxf(seconds, 0.0)
	_primary_offset += wind_velocity * elapsed
	_shape_offset += shape_velocity * elapsed
	_sync_shadow_offsets()


func get_active_cloud_count() -> int:
	return 1 if visible else 0


func get_cloud_world_position(_index: int) -> Vector2:
	return -_primary_offset


func get_cloud_offset() -> Vector2:
	return _primary_offset


func get_shape_offset() -> Vector2:
	return _shape_offset


func get_shadow_material() -> ShaderMaterial:
	return _shadow_material


func get_cloud_tint() -> Color:
	if day_night_cycle != null and day_night_cycle.environment != null:
		return day_night_cycle.environment.color
	return Color.WHITE


func is_shadow_only() -> bool:
	return true


func get_shadow_coverage() -> float:
	return float(_shadow_material.get_shader_parameter("shadow_coverage")) if _shadow_material != null else 0.0


func _populate_shadow_surface() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = ArtAssets.shader(cloud_shadow_shader.resource_path, cloud_shadow_shader)
	_shadow_surface = Polygon2D.new()
	_shadow_surface.name = "ProceduralCloudShadow"
	_shadow_surface.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(world_size.x, 0.0),
		world_size,
		Vector2(0.0, world_size.y),
	])
	_shadow_surface.color = Color.WHITE
	_shadow_surface.material = _shadow_material
	add_child(_shadow_surface)
	_sync_shadow_material()


func _on_time_changed(_day: int, _hour: int, _minute: int, _phase: String) -> void:
	_sync_shadow_material()


func _sync_shadow_material() -> void:
	if _shadow_material == null:
		return
	var overcast := current_weather == "阴天"
	var coverage := overcast_shadow_coverage if overcast else clear_shadow_coverage
	var multiplier := overcast_shadow_multiplier if overcast else clear_shadow_multiplier
	var density := overcast_cloud_density if overcast else clear_cloud_density
	coverage *= _sunlight_amount()
	_shadow_material.set_shader_parameter("shadow_coverage", coverage)
	_shadow_material.set_shader_parameter("shadow_multiplier", Vector3(multiplier.r, multiplier.g, multiplier.b))
	_shadow_material.set_shader_parameter("cloud_density", density)
	_shadow_material.set_shader_parameter("cloud_scale", cloud_scale)
	_shadow_material.set_shader_parameter("edge_softness", edge_softness)
	_sync_shadow_offsets()


func _sync_shadow_offsets() -> void:
	if _shadow_material == null:
		return
	_shadow_material.set_shader_parameter("primary_offset", _primary_offset)
	_shadow_material.set_shader_parameter("shape_offset", _shape_offset)


func _sunlight_amount() -> float:
	if day_night_cycle == null:
		return 1.0
	var hour := float(day_night_cycle.current_hour)
	if hour < 5.0 or hour >= 21.0:
		return 0.0
	if hour < 6.0:
		return smoothstep(5.0, 6.0, hour)
	if hour < 18.0:
		return 1.0
	return 1.0 - smoothstep(18.0, 21.0, hour)
