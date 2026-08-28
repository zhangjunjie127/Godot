extends Node2D

@export_range(0.0, 1.0, 0.05) var demo_intensity := 0.85

@onready var puddle_surface: Sprite2D = $PuddleSurface
@onready var ground_effects: Node2D = $GroundEffects
@onready var wet_grade: ColorRect = $Weather/WetGrade
@onready var rain_visual: Control = $Weather/RainVisuals


func _ready() -> void:
	puddle_surface.visible = true
	wet_grade.visible = true
	puddle_surface.material.set_shader_parameter("rain_intensity", demo_intensity)
	wet_grade.material.set_shader_parameter("rain_intensity", demo_intensity)
	ground_effects.set_rain_strength(demo_intensity)
	rain_visual.set_intensity(demo_intensity)


func _process(delta: float) -> void:
	rain_visual.advance_effects(delta)


func _exit_tree() -> void:
	rain_visual.set_intensity(0.0)
