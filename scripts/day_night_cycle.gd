extends Node

signal time_changed(day: int, hour: int, minute: int, phase: String)
signal phase_changed(phase: String)
signal day_changed(day: int)

const DAY_START_HOUR := 6.0
const DUSK_START_HOUR := 18.0
const NIGHT_START_HOUR := 21.0
const NIGHT_COLOR := Color(0.10, 0.12, 0.18, 1.0)
const DAY_COLOR := Color.WHITE
const DUSK_COLOR := Color(0.88, 0.69, 0.58, 1.0)

@export_range(1.0, 3600.0, 1.0) var day_duration_seconds := 900.0
@export_range(1.0, 3600.0, 1.0) var dusk_duration_seconds := 300.0
@export_range(1.0, 3600.0, 1.0) var night_duration_seconds := 600.0
@export_range(0.0, 23.99, 0.25) var start_hour := 7.0
@export var start_day := 1
@export var environment_path: NodePath

var current_day := 1
var current_hour := 7.0
var current_phase := "白天"

@onready var environment: CanvasModulate = get_node_or_null(environment_path) as CanvasModulate

var _last_display_minute := -1


func _ready() -> void:
	current_day = maxi(start_day, 1)
	current_hour = fposmod(start_hour, 24.0)
	current_phase = _get_phase(current_hour)
	_apply_environment()
	_emit_time_changed()


func _process(delta: float) -> void:
	advance_real_seconds(delta)


func advance_real_seconds(seconds: float) -> void:
	var remaining := maxf(seconds, 0.0)
	while remaining > 0.0001:
		var speed := _phase_game_minutes_per_real_second(current_phase)
		var boundary_minutes := _minutes_until_phase_boundary()
		var real_seconds_to_boundary := boundary_minutes / speed
		var step := minf(remaining, real_seconds_to_boundary)
		advance_minutes(step * speed)
		remaining -= step
		if is_equal_approx(step, real_seconds_to_boundary):
			_snap_to_phase_boundary()


func advance_minutes(minutes: float) -> void:
	var previous_day := current_day
	var previous_phase := current_phase
	current_hour += minutes / 60.0
	while current_hour >= 24.0:
		current_hour -= 24.0
		current_day += 1
	while current_hour < 0.0:
		current_hour += 24.0
		current_day = maxi(current_day - 1, 1)

	current_phase = _get_phase(current_hour)
	_apply_environment()
	if current_day != previous_day:
		day_changed.emit(current_day)
	if current_phase != previous_phase:
		phase_changed.emit(current_phase)
	var display_minute := floori(current_hour * 60.0)
	if display_minute != _last_display_minute or current_day != previous_day or current_phase != previous_phase:
		_emit_time_changed()


func set_game_time(day: int, hour: float) -> void:
	var previous_day := current_day
	var previous_phase := current_phase
	current_day = maxi(day, 1)
	current_hour = fposmod(hour, 24.0)
	current_phase = _get_phase(current_hour)
	_apply_environment()
	if current_day != previous_day:
		day_changed.emit(current_day)
	if current_phase != previous_phase:
		phase_changed.emit(current_phase)
	_emit_time_changed()


func _emit_time_changed() -> void:
	var total_minutes := floori(current_hour * 60.0)
	_last_display_minute = total_minutes
	time_changed.emit(current_day, floori(total_minutes / 60.0), total_minutes % 60, current_phase)


func _get_phase(hour: float) -> String:
	if hour >= DAY_START_HOUR and hour < DUSK_START_HOUR:
		return "白天"
	if hour >= DUSK_START_HOUR and hour < NIGHT_START_HOUR:
		return "黄昏"
	return "夜晚"


func _phase_game_minutes_per_real_second(phase: String) -> float:
	match phase:
		"白天":
			return (DUSK_START_HOUR - DAY_START_HOUR) * 60.0 / maxf(day_duration_seconds, 1.0)
		"黄昏":
			return (NIGHT_START_HOUR - DUSK_START_HOUR) * 60.0 / maxf(dusk_duration_seconds, 1.0)
		_:
			return (24.0 - NIGHT_START_HOUR + DAY_START_HOUR) * 60.0 / maxf(night_duration_seconds, 1.0)


func _minutes_until_phase_boundary() -> float:
	if current_hour >= DAY_START_HOUR and current_hour < DUSK_START_HOUR:
		return (DUSK_START_HOUR - current_hour) * 60.0
	if current_hour >= DUSK_START_HOUR and current_hour < NIGHT_START_HOUR:
		return (NIGHT_START_HOUR - current_hour) * 60.0
	if current_hour >= NIGHT_START_HOUR:
		return (24.0 - current_hour) * 60.0
	return (DAY_START_HOUR - current_hour) * 60.0


func _snap_to_phase_boundary() -> void:
	if current_hour < 0.001:
		current_hour = 0.0
	elif absf(current_hour - DAY_START_HOUR) < 0.001:
		current_hour = DAY_START_HOUR
	elif absf(current_hour - DUSK_START_HOUR) < 0.001:
		current_hour = DUSK_START_HOUR
	elif absf(current_hour - NIGHT_START_HOUR) < 0.001:
		current_hour = NIGHT_START_HOUR
	current_phase = _get_phase(current_hour)


func _apply_environment() -> void:
	if environment == null:
		return
	var hour := current_hour
	if hour < 5.0 or hour >= NIGHT_START_HOUR:
		environment.color = NIGHT_COLOR
	elif hour < DAY_START_HOUR:
		environment.color = NIGHT_COLOR.lerp(DAY_COLOR, hour - 5.0)
	elif hour < DUSK_START_HOUR:
		environment.color = DAY_COLOR
	elif hour < 19.0:
		environment.color = DAY_COLOR.lerp(DUSK_COLOR, hour - DUSK_START_HOUR)
	elif hour < NIGHT_START_HOUR:
		environment.color = DUSK_COLOR.lerp(NIGHT_COLOR, (hour - 19.0) / 2.0)
	else:
		environment.color = NIGHT_COLOR
