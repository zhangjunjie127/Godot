extends Control

@onready var start_button: Button = $StartButton


func _ready() -> void:
	var background := $Background as TextureRect
	background.texture = ArtAssets.texture(background.texture.resource_path, background.texture)
	start_button.pressed.connect(_start_game)
	start_button.grab_focus()


func _start_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
