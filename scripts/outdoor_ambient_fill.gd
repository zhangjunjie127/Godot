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

@export_group("Clear Day Grade")
@export_range(-0.5, 0.5, 0.01) var clear_exposure := -0.02
@export_range(0.5, 1.5, 0.01) var clear_contrast := 1.01
@export_range(0.0, 1.5, 0.01) var clear_saturation := 0.88
@export var clear_grade_tint := Color(1.0, 0.995, 0.98, 1.0)

@export_group("Overcast Grade")
@export_range(-0.5, 0.5, 0.01) var overcast_exposure := -0.07
@export_range(0.5, 1.5, 0.01) var overcast_contrast := 0.97
@export_range(0.0, 1.5, 0.01) var overcast_saturation := 0.78
@export var overcast_grade_tint := Color(0.95, 0.99, 1.04, 1.0)

@export_group("Dusk Grade")
@export_range(-0.5, 0.5, 0.01) var dusk_exposure := -0.05
@export_range(0.5, 1.5, 0.01) var dusk_contrast := 1.01
@export_range(0.0, 1.5, 0.01) var dusk_saturation := 0.84
@export var dusk_grade_tint := Color(1.0, 1.0, 0.98, 1.0)

@export_group("Night Grade")
@export_range(-0.5, 0.5, 0.01) var night_exposure := 0.0
@export_range(0.5, 1.5, 0.01) var night_contrast := 1.0
@export_range(0.0, 1.5, 0.01) var night_saturation := 0.86
@export var night_grade_tint := Color(0.97, 1.0, 1.03, 1.0)
@export_range(0.0, 1.0, 0.01) var highlight_protection := 0.65

@onready var day_night_cycle: Node = get_node_or_null(day_night_cycle_path)
@onready var world: CanvasItem = get_node_or_null(world_path) as CanvasItem

var current_strength := 0.0
var current_grade := Vector3(0.0, 1.0, 1.0)


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
	current_grade = _time_grade(hour)
	var grade_tint := _time_grade_tint(hour)
	var weather_blend := cloudiness * daylight
	current_grade = current_grade.lerp(
		Vector3(overcast_exposure, overcast_contrast, overcast_saturation),
		weather_blend
	)
	grade_tint = grade_tint.lerp(overcast_grade_tint, weather_blend)
	material.set_shader_parameter("fill_color", Vector3(fill_color.r, fill_color.g, fill_color.b))
	material.set_shader_parameter("fill_strength", current_strength)
	material.set_shader_parameter("shadow_start", shadow_start)
	material.set_shader_parameter("shadow_end", shadow_end)
	material.set_shader_parameter("outline_guard", outline_guard)
	material.set_shader_parameter("exposure", current_grade.x)
	material.set_shader_parameter("contrast", current_grade.y)
	material.set_shader_parameter("saturation", current_grade.z)
	material.set_shader_parameter("grade_tint", Vector3(grade_tint.r, grade_tint.g, grade_tint.b))
	material.set_shader_parameter("highlight_protection", highlight_protection)


func _daylight_amount(hour: float) -> float:
	if hour < dawn_start_hour or hour >= night_hour:
		return 0.0
	if hour < daylight_hour:
		return smoothstep(dawn_start_hour, daylight_hour, hour)
	if hour < dusk_start_hour:
		return 1.0
	return 1.0 - smoothstep(dusk_start_hour, night_hour, hour)


func _time_grade(hour: float) -> Vector3:
	var clear_grade := Vector3(clear_exposure, clear_contrast, clear_saturation)
	var dusk_grade := Vector3(dusk_exposure, dusk_contrast, dusk_saturation)
	var night_grade := Vector3(night_exposure, night_contrast, night_saturation)
	if hour < dawn_start_hour or hour >= night_hour:
		return night_grade
	if hour < daylight_hour:
		return night_grade.lerp(clear_grade, smoothstep(dawn_start_hour, daylight_hour, hour))
	if hour < dusk_start_hour - 1.0:
		return clear_grade
	if hour < dusk_start_hour + 1.0:
		return clear_grade.lerp(dusk_grade, smoothstep(dusk_start_hour - 1.0, dusk_start_hour + 1.0, hour))
	return dusk_grade.lerp(night_grade, smoothstep(dusk_start_hour + 1.0, night_hour, hour))


func _time_grade_tint(hour: float) -> Color:
	if hour < dawn_start_hour or hour >= night_hour:
		return night_grade_tint
	if hour < daylight_hour:
		return night_grade_tint.lerp(clear_grade_tint, smoothstep(dawn_start_hour, daylight_hour, hour))
	if hour < dusk_start_hour - 1.0:
		return clear_grade_tint
	if hour < dusk_start_hour + 1.0:
		return clear_grade_tint.lerp(dusk_grade_tint, smoothstep(dusk_start_hour - 1.0, dusk_start_hour + 1.0, hour))
	return dusk_grade_tint.lerp(night_grade_tint, smoothstep(dusk_start_hour + 1.0, night_hour, hour))
