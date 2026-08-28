extends Control

@onready var start_button: Button = $StartButton
@onready var gender_panel: Control = $GenderPanel
@onready var male_button: Button = $GenderPanel/Panel/Margin/Content/Choices/MaleButton
@onready var female_button: Button = $GenderPanel/Panel/Margin/Content/Choices/FemaleButton


func _ready() -> void:
	var background := $Background as TextureRect
	background.texture = ArtAssets.texture(background.texture.resource_path, background.texture)
	male_button.icon = ArtAssets.texture(male_button.icon.resource_path, male_button.icon)
	female_button.icon = ArtAssets.texture(female_button.icon.resource_path, female_button.icon)
	start_button.pressed.connect(_show_gender_selection)
	male_button.pressed.connect(_start_game.bind("male"))
	female_button.pressed.connect(_start_game.bind("female"))
	start_button.grab_focus()


func _show_gender_selection() -> void:
	start_button.visible = false
	gender_panel.visible = true
	male_button.grab_focus()


func _start_game(gender: String) -> void:
	GameSession.select_gender(gender)
	get_tree().change_scene_to_file("res://main.tscn")
