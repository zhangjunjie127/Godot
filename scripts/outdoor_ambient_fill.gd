extends ColorRect

@export_group("Scene Links")
@export var day_night_cycle_path: NodePath
@export var world_path: NodePath

@export_group("Outdoor Fill")
@export_range(0.0, 0.3, 0.005) var daytime_strength := 0.10
@export_range(0.5, 1.5, 0.05) var overcast_multiplier := 1.15
@export var clear_fill_color := Color(0.52, 0.66, 0.60, 1.0)
@export var overcast_fill_color := Color(0.56, 0.64, 0.70, 1.0)
@export_range(0.0, 23.0, 0.25) var dawn_start_hour := 5.0
@export_range(0.0, 23.0, 0.25) var daylight_hour := 6.0
@export_range(0.0, 23.0, 0.25) var dusk_start_hour := 18.0
@export_range(0.0, 24.0, 0.25) var night_hour := 21.0

@export_group("Shadow Range")
@export_range(0.0, 0.5, 0.01) var shadow_start := 0.04
@export_range(0.1, 1.0, 0.01) var shadow_end := 0.58
@export_range(0.0, 0.2, 0.005) var outline_guard := 0.075

@onready var day_night_cycle: Node = get_node_or_null(day_night_cycle_path)
@onready var world: CanvasItem = get_node_or_null(world_path) as CanvasItem

var current_strength := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_fill()


func _process(_delta: float) -> void:
	_sync_fill()


func get_current_strength() -> float:
	return current_strength


func _sync_fill() -> void:
	if world != null:
		visible = world.visible
	if material == null or day_night_cycle == null:
		return

	var hour := float(day_night_cycle.get("current_hour"))
	var cloudiness := clampf(float(day_night_cycle.get("weather_cloudiness")), 0.0, 1.0)
	var daylight := _daylight_amount(hour)
	current_strength = daytime_strength * daylight * lerpf(1.0, overcast_multiplier, cloudiness)
	var fill_color := clear_fill_color.lerp(overcast_fill_color, cloudiness)
	material.set_shader_parameter("fill_color", Vector3(fill_color.r, fill_color.g, fill_color.b))
	material.set_shader_parameter("fill_strength", current_strength)
	material.set_shader_parameter("shadow_start", shadow_start)
	material.set_shader_parameter("shadow_end", shadow_end)
	material.set_shader_parameter("outline_guard", outline_guard)


func _daylight_amount(hour: float) -> float:
	if hour < dawn_start_hour or hour >= night_hour:
		return 0.0
	if hour < daylight_hour:
		return smoothstep(dawn_start_hour, daylight_hour, hour)
	if hour < dusk_start_hour:
		return 1.0
	return 1.0 - smoothstep(dusk_start_hour, night_hour, hour)
