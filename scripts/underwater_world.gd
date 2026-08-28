extends Node2D

const ResourceNodeScript = preload("res://scripts/resource_node.gd")
const MAP_SIZE := Vector2(1672.0, 941.0)
const WATER_SURFACE_Y := 145.0
const ENTRY_POSITION := Vector2(150.0, WATER_SURFACE_Y + 4.0)

@onready var depth_sorted: Node2D = $DepthSorted


func _ready() -> void:
	_build_resources()


func _build_resources() -> void:
	var resources := [
		{
			"id": "reef_fish",
			"action": "采集",
			"resourceId": "meat_fish",
			"name": "鲜鱼肉",
			"image": "assets/items/resources/meat/fish.png",
			"x": 620.0,
			"y": 420.0,
			"w": 56.0,
			"h": 56.0,
			"radius": 28.0,
			"yield": 2,
		},
		{
			"id": "giant_shellfish",
			"action": "采集",
			"resourceId": "meat_shellfish",
			"name": "甲壳肉",
			"image": "assets/items/resources/meat/shellfish.png",
			"x": 1110.0,
			"y": 760.0,
			"w": 58.0,
			"h": 58.0,
			"radius": 30.0,
			"yield": 2,
		},
	]
	for data: Dictionary in resources:
		var node := ResourceNodeScript.new()
		node.name = String(data["id"]).to_pascal_case()
		node.position = Vector2(float(data["x"]), float(data["y"]))
		depth_sorted.add_child(node)
		node.configure(data)
