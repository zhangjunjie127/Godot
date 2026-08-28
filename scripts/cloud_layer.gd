extends Node2D

const CLOUD_TEXTURE := preload("res://assets/weather/clouds/sheet-transparent.png")
const CELL_SIZE := 192
const CLOUD_COUNT := 4
const BLOCK_CLOUD_CELLS := [1, 3, 4, 5, 8]

@export var weather_path: NodePath
@export var day_night_cycle_path: NodePath
@export var random_seed := 20260827
@export var world_size := Vector2(2048.0, 2048.0)

var current_weather := "下雨"
var clouds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

@onready var day_night_cycle = get_node_or_null(day_night_cycle_path)


func _ready() -> void:
	_rng.seed = random_seed
	var weather := get_node_or_null(weather_path)
	if weather != null:
		weather.weather_changed.connect(set_weather)
		current_weather = weather.current_weather
	_populate_clouds()
	set_weather(current_weather)


func _process(delta: float) -> void:
	advance_clouds(delta)


func set_weather(value: String) -> void:
	current_weather = value
	visible = current_weather == "晴朗"


func advance_clouds(seconds: float) -> void:
	if not visible:
		return
	for cloud: Dictionary in clouds:
		var sprite := cloud["sprite"] as Sprite2D
		var position: Vector2 = sprite.position
		position.x -= float(cloud["speed"]) * maxf(seconds, 0.0)
		if position.x < -float(CELL_SIZE) * float(cloud["scale"]):
			position.x = world_size.x + _rng.randf_range(40.0, 220.0)
			position.y = _rng.randf_range(180.0, world_size.y * 0.72)
			cloud["cell"] = _random_cloud_cell()
			sprite.frame = int(cloud["cell"])
		sprite.position = position
		cloud["position"] = position


func get_active_cloud_count() -> int:
	return clouds.size() if visible else 0


func get_cloud_world_position(index: int) -> Vector2:
	if index < 0 or index >= clouds.size():
		return Vector2.ZERO
	return (clouds[index]["sprite"] as Sprite2D).global_position


func get_cloud_tint() -> Color:
	if day_night_cycle != null and day_night_cycle.environment != null:
		return day_night_cycle.environment.color
	return Color.WHITE


func _populate_clouds() -> void:
	for child: Node in get_children():
		child.queue_free()
	clouds.clear()
	for index: int in range(CLOUD_COUNT):
		var cell := _random_cloud_cell()
		var cloud_scale := _rng.randf_range(0.42, 0.62)
		var sprite := Sprite2D.new()
		sprite.name = "Cloud%d" % (index + 1)
		sprite.texture = CLOUD_TEXTURE
		sprite.hframes = 3
		sprite.vframes = 3
		sprite.frame = cell
		sprite.scale = Vector2.ONE * cloud_scale
		sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.70)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2(
			world_size.x * (float(index) + 0.35) / float(CLOUD_COUNT),
			_rng.randf_range(180.0, world_size.y * 0.72)
		)
		add_child(sprite)
		clouds.append({
			"sprite": sprite,
			"position": sprite.position,
			"speed": _rng.randf_range(5.0, 12.0),
			"scale": cloud_scale,
			"cell": cell,
		})


func _random_cloud_cell() -> int:
	return BLOCK_CLOUD_CELLS[_rng.randi_range(0, BLOCK_CLOUD_CELLS.size() - 1)]
