extends Control

signal weather_changed(weather: String)

const WEATHER_CLEAR := "晴朗"
const WEATHER_RAIN := "下雨"
const WEATHER_WINTER := "寒冬"
const WEATHER_ORDER := [WEATHER_CLEAR, WEATHER_RAIN, WEATHER_WINTER]

@export_enum("晴朗", "下雨", "寒冬") var start_weather := WEATHER_RAIN
@export_range(5.0, 600.0, 1.0) var weather_duration_seconds := 30.0

var current_weather := WEATHER_RAIN
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_weather = start_weather if start_weather in WEATHER_ORDER else WEATHER_CLEAR
	queue_redraw()


func _process(delta: float) -> void:
	advance_real_seconds(delta)
	queue_redraw()


func advance_real_seconds(seconds: float) -> void:
	_elapsed += maxf(seconds, 0.0)
	while _elapsed >= weather_duration_seconds:
		_elapsed -= weather_duration_seconds
		var next_index := (WEATHER_ORDER.find(current_weather) + 1) % WEATHER_ORDER.size()
		set_weather(WEATHER_ORDER[next_index])


func set_weather(weather: String) -> void:
	if weather not in WEATHER_ORDER or weather == current_weather:
		return
	current_weather = weather
	_elapsed = 0.0
	weather_changed.emit(weather)
	queue_redraw()


func _draw() -> void:
	match current_weather:
		WEATHER_RAIN:
			_draw_rain()
		WEATHER_WINTER:
			_draw_winter()


func _draw_rain() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.20, 0.28, 0.15))
	for index: int in range(72):
		var x := fposmod(float(index * 83) + _elapsed * 260.0, size.x + 40.0) - 20.0
		var y := fposmod(float(index * 47) + _elapsed * 430.0, size.y + 50.0) - 25.0
		draw_line(Vector2(x, y), Vector2(x - 5.0, y + 15.0), Color(0.68, 0.84, 0.94, 0.58), 1.0)


func _draw_winter() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.68, 0.82, 0.92, 0.18))
	for index: int in range(58):
		var drift := sin(_elapsed * 0.9 + float(index)) * 12.0
		var x := fposmod(float(index * 97) + drift, size.x + 20.0) - 10.0
		var speed := 22.0 + float(index % 5) * 4.0
		var y := fposmod(float(index * 53) + _elapsed * speed, size.y + 20.0) - 10.0
		draw_circle(Vector2(x, y), 1.0 + float(index % 3) * 0.5, Color(0.94, 0.98, 1.0, 0.82))
