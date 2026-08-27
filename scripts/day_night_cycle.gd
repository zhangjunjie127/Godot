extends Node

signal time_changed(day: int, hour: int, minute: int, phase: String)
signal phase_changed(phase: String)
signal day_changed(day: int)

const MINUTES_PER_DAY := 1440.0
const NIGHT_COLOR := Color(0.52, 0.58, 0.72, 1.0)
const DAWN_COLOR := Color(0.95, 0.80, 0.68, 1.0)
const DAY_COLOR := Color.WHITE
const DUSK_COLOR := Color(0.88, 0.69, 0.58, 1.0)

@export_range(10.0, 3600.0, 1.0) var real_seconds_per_game_day := 120.0
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
	advance_minutes(delta * MINUTES_PER_DAY / maxf(real_seconds_per_game_day, 1.0))


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
	if hour >= 5.0 and hour < 7.0:
		return "清晨"
	if hour >= 7.0 and hour < 18.0:
		return "白天"
	if hour >= 18.0 and hour < 21.0:
		return "黄昏"
	return "夜晚"


func _apply_environment() -> void:
	if environment == null:
		return
	var hour := current_hour
	if hour < 5.0 or hour >= 22.0:
		environment.color = NIGHT_COLOR
	elif hour < 6.0:
		environment.color = NIGHT_COLOR.lerp(DAWN_COLOR, hour - 5.0)
	elif hour < 7.0:
		environment.color = DAWN_COLOR.lerp(DAY_COLOR, hour - 6.0)
	elif hour < 18.0:
		environment.color = DAY_COLOR
	elif hour < 19.0:
		environment.color = DAY_COLOR.lerp(DUSK_COLOR, hour - 18.0)
	elif hour < 21.0:
		environment.color = DUSK_COLOR.lerp(NIGHT_COLOR, (hour - 19.0) / 2.0)
	else:
		environment.color = NIGHT_COLOR
