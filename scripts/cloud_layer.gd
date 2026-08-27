extends Control

const CLOUD_TEXTURE := preload("res://assets/weather/clouds/sheet-transparent.png")
const CELL_SIZE := 192
const CLOUD_COUNT := 4

@export var weather_path: NodePath
@export var random_seed := 20260827

var current_weather := "下雨"
var clouds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = random_seed
	resized.connect(_populate_clouds)
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
	queue_redraw()


func advance_clouds(seconds: float) -> void:
	if not visible:
		return
	var viewport_size := _effect_size()
	for cloud: Dictionary in clouds:
		var position: Vector2 = cloud["position"]
		position.x -= float(cloud["speed"]) * maxf(seconds, 0.0)
		if position.x < -float(CELL_SIZE) * float(cloud["scale"]):
			position.x = viewport_size.x + _rng.randf_range(20.0, 180.0)
			position.y = _rng.randf_range(10.0, viewport_size.y * 0.58)
			cloud["cell"] = _rng.randi_range(0, 8)
		cloud["position"] = position
	queue_redraw()


func get_active_cloud_count() -> int:
	return clouds.size() if visible else 0


func _populate_clouds() -> void:
	clouds.clear()
	var viewport_size := _effect_size()
	for index: int in range(CLOUD_COUNT):
		clouds.append({
			"position": Vector2(
				viewport_size.x * (float(index) + 0.25) / float(CLOUD_COUNT),
				_rng.randf_range(10.0, viewport_size.y * 0.58)
			),
			"speed": _rng.randf_range(5.0, 12.0),
			"scale": _rng.randf_range(0.28, 0.48),
			"cell": _rng.randi_range(0, 8),
		})
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	for cloud: Dictionary in clouds:
		var cell := int(cloud["cell"])
		var source := Rect2(Vector2(cell % 3, floori(float(cell) / 3.0)) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		var draw_size := Vector2.ONE * CELL_SIZE * float(cloud["scale"])
		draw_texture_rect_region(
			CLOUD_TEXTURE,
			Rect2((cloud["position"] as Vector2) - draw_size * 0.5, draw_size),
			source,
			Color(1.0, 1.0, 1.0, 0.70)
		)


func _effect_size() -> Vector2:
	return Vector2(maxf(size.x, 640.0), maxf(size.y, 360.0))
