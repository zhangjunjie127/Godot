extends Node2D

const CLOUD_TEXTURE := preload("res://assets/weather/clouds/sheet-transparent.png")
const ORDERED_SHADOW_SHADER := preload("res://shaders/ordered_shadow.gdshader")
const CELL_SIZE := 192
const CLEAR_CLOUD_COUNT := 8
const OVERCAST_CLOUD_COUNT := 14
const BLOCK_CLOUD_CELLS := [1, 3, 4, 5, 8]

@export_group("Art / Cloud Shadow Sheet")
@export var cloud_texture: Texture2D = CLOUD_TEXTURE
@export var cloud_shadow_shader: Shader = ORDERED_SHADOW_SHADER

@export_group("Shadow Composition")
@export_range(0.0, 1.0, 0.01) var clear_shadow_coverage := 0.40
@export_range(0.0, 1.0, 0.01) var overcast_shadow_coverage := 0.54
@export var clear_shadow_multiplier := Color(0.60, 0.70, 0.64, 1.0)
@export var overcast_shadow_multiplier := Color(0.66, 0.72, 0.74, 1.0)

@export_group("Cloud Motion")
@export var weather_path: NodePath
@export var day_night_cycle_path: NodePath
@export var random_seed := 20260827
@export var world_size := Vector2(2048.0, 2048.0)

var current_weather := "下雨"
var clouds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _shadow_material: ShaderMaterial

@onready var day_night_cycle = get_node_or_null(day_night_cycle_path)


func _ready() -> void:
	_rng.seed = random_seed
	var weather := get_node_or_null(weather_path)
	if weather != null:
		weather.weather_changed.connect(set_weather)
		current_weather = weather.current_weather
	if day_night_cycle != null:
		day_night_cycle.time_changed.connect(_on_time_changed)
	_populate_clouds()
	set_weather(current_weather)


func _process(delta: float) -> void:
	advance_clouds(delta)


func set_weather(value: String) -> void:
	current_weather = value
	visible = current_weather in ["晴朗", "阴天"]
	var active_count := OVERCAST_CLOUD_COUNT if current_weather == "阴天" else CLEAR_CLOUD_COUNT
	for index: int in range(clouds.size()):
		var sprite := clouds[index]["sprite"] as Sprite2D
		sprite.visible = index < active_count
		sprite.self_modulate = Color.WHITE
		sprite.scale = Vector2.ONE * float(clouds[index]["scale"]) * (10.0 if current_weather == "阴天" else 7.5)
	_sync_shadow_material()


func advance_clouds(seconds: float) -> void:
	if not visible:
		return
	for cloud: Dictionary in clouds:
		var sprite := cloud["sprite"] as Sprite2D
		var position: Vector2 = sprite.position
		var drift_phase := float(cloud["drift_phase"]) + float(cloud["drift_speed"]) * maxf(seconds, 0.0)
		position.x -= float(cloud["speed"]) * maxf(seconds, 0.0)
		position.y += sin(drift_phase) * float(cloud["drift_amount"]) * maxf(seconds, 0.0)
		if position.x < -float(CELL_SIZE) * sprite.scale.x:
			position.x = world_size.x + _rng.randf_range(40.0, 220.0)
			position.y = _rng.randf_range(180.0, world_size.y * 0.72)
			cloud["cell"] = _random_cloud_cell()
			sprite.frame = int(cloud["cell"])
		sprite.position = position
		cloud["position"] = position
		cloud["drift_phase"] = drift_phase


func get_active_cloud_count() -> int:
	if not visible:
		return 0
	return OVERCAST_CLOUD_COUNT if current_weather == "阴天" else CLEAR_CLOUD_COUNT


func get_cloud_world_position(index: int) -> Vector2:
	if index < 0 or index >= clouds.size():
		return Vector2.ZERO
	return (clouds[index]["sprite"] as Sprite2D).global_position


func get_cloud_tint() -> Color:
	if day_night_cycle != null and day_night_cycle.environment != null:
		return day_night_cycle.environment.color
	return Color.WHITE


func is_shadow_only() -> bool:
	return true


func get_shadow_coverage() -> float:
	return float(_shadow_material.get_shader_parameter("shadow_coverage")) if _shadow_material != null else 0.0


func _populate_clouds() -> void:
	for child: Node in get_children():
		child.queue_free()
	clouds.clear()
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = ArtAssets.shader(cloud_shadow_shader.resource_path, cloud_shadow_shader)
	for index: int in range(OVERCAST_CLOUD_COUNT):
		var cell := _random_cloud_cell()
		var cloud_scale := _rng.randf_range(0.42, 0.62)
		var sprite := Sprite2D.new()
		sprite.name = "CloudShadow%d" % (index + 1)
		sprite.texture = ArtAssets.texture(cloud_texture.resource_path, cloud_texture)
		sprite.hframes = 3
		sprite.vframes = 3
		sprite.frame = cell
		sprite.scale = Vector2.ONE * cloud_scale
		sprite.self_modulate = Color.WHITE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.material = _shadow_material
		sprite.position = _initial_cloud_position(index)
		add_child(sprite)
		clouds.append({
			"sprite": sprite,
			"position": sprite.position,
			"speed": _rng.randf_range(26.0, 34.0),
			"drift_speed": _rng.randf_range(0.45, 0.85),
			"drift_amount": _rng.randf_range(1.8, 3.6),
			"drift_phase": _rng.randf_range(0.0, TAU),
			"scale": cloud_scale,
			"cell": cell,
		})
	_sync_shadow_material()


func _initial_cloud_position(index: int) -> Vector2:
	if index < CLEAR_CLOUD_COUNT:
		var columns := 4
		var rows := ceili(float(CLEAR_CLOUD_COUNT) / float(columns))
		return Vector2(
			world_size.x * (float(index % columns) + 0.5) / float(columns),
			world_size.y * (float(floori(float(index) / float(columns))) + 0.5) / float(rows)
		)
	var extra_index := index - CLEAR_CLOUD_COUNT
	var extra_count := OVERCAST_CLOUD_COUNT - CLEAR_CLOUD_COUNT
	var extra_columns := 3
	var extra_rows := ceili(float(extra_count) / float(extra_columns))
	return Vector2(
		world_size.x * (float(extra_index % extra_columns) + 0.5) / float(extra_columns),
		fposmod(world_size.y * (float(floori(float(extra_index) / float(extra_columns))) + 0.75) / float(extra_rows), world_size.y)
	)


func _on_time_changed(_day: int, _hour: int, _minute: int, _phase: String) -> void:
	_sync_shadow_material()


func _sync_shadow_material() -> void:
	if _shadow_material == null:
		return
	var overcast := current_weather == "阴天"
	var coverage := overcast_shadow_coverage if overcast else clear_shadow_coverage
	var multiplier := overcast_shadow_multiplier if overcast else clear_shadow_multiplier
	coverage *= _sunlight_amount()
	_shadow_material.set_shader_parameter("shadow_coverage", coverage)
	_shadow_material.set_shader_parameter("shadow_multiplier", Vector3(multiplier.r, multiplier.g, multiplier.b))


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


func _random_cloud_cell() -> int:
	return BLOCK_CLOUD_CELLS[_rng.randi_range(0, BLOCK_CLOUD_CELLS.size() - 1)]
