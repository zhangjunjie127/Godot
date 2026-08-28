extends Node2D

const FishScript = preload("res://scripts/underwater_fish.gd")
const BubbleScript = preload("res://scripts/underwater_bubbles.gd")
const FISH_TEXTURES := [
	preload("res://assets/creatures/fish_turquoise/sheet-transparent.png"),
	preload("res://assets/creatures/fish_golden/sheet-transparent.png"),
	preload("res://assets/creatures/fish_violet/sheet-transparent.png"),
]
const MAP_SIZE := Vector2(1672.0, 941.0)
const WATER_SURFACE_Y := 145.0
const ENTRY_POSITION := Vector2(320.0, WATER_SURFACE_Y + 4.0)
const FISH_BOUNDS := Rect2(140.0, WATER_SURFACE_Y + 80.0, MAP_SIZE.x - 280.0, MAP_SIZE.y - WATER_SURFACE_Y - 180.0)

@onready var depth_sorted: Node2D = $DepthSorted

var bubble_effect: Node2D


func _ready() -> void:
	var background := $Background as Sprite2D
	background.texture = ArtAssets.texture(background.texture.resource_path, background.texture)
	_build_fish()
	bubble_effect = BubbleScript.new()
	bubble_effect.name = "BubbleEffect"
	depth_sorted.add_child(bubble_effect)


func set_player(player: CharacterBody2D) -> void:
	bubble_effect.set_player(player)


func _build_fish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260828
	for index: int in range(FISH_TEXTURES.size()):
		var fish := FishScript.new()
		fish.name = "FishSpecies%d" % (index + 1)
		fish.position = Vector2(
			rng.randf_range(FISH_BOUNDS.position.x, FISH_BOUNDS.end.x),
			rng.randf_range(FISH_BOUNDS.position.y, FISH_BOUNDS.end.y)
		)
		depth_sorted.add_child(fish)
		var fallback := FISH_TEXTURES[index] as Texture2D
		fish.configure(ArtAssets.texture(fallback.resource_path, fallback), FISH_BOUNDS, 20260828 + index * 97, rng.randf_range(0.34, 0.44))
