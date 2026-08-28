@tool
extends Resource
class_name ArtCatalog

@export_group("Characters / 角色")
@export var characters: Dictionary[String, Texture2D] = {}

@export_group("Creatures / 生物与怪物")
@export var creatures: Dictionary[String, Texture2D] = {}

@export_group("Maps / 地图与物件")
@export var maps_and_props: Dictionary[String, Texture2D] = {}

@export_group("Items / 道具")
@export var items: Dictionary[String, Texture2D] = {}

@export_group("UI / 界面")
@export var ui: Dictionary[String, Texture2D] = {}

@export_group("Weather / 天气")
@export var weather: Dictionary[String, Texture2D] = {}


func texture(path: String) -> Texture2D:
	var normalized := normalize_path(path)
	for group: Dictionary in _groups():
		var replacement: Variant = group.get(normalized)
		if replacement is Texture2D:
			return replacement as Texture2D
	return null


func has_entry(path: String) -> bool:
	var normalized := normalize_path(path)
	for group: Dictionary in _groups():
		if group.has(normalized):
			return true
	return false


func all_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for group: Dictionary in _groups():
		for path: Variant in group.keys():
			paths.append(String(path))
	paths.sort()
	return paths


func _groups() -> Array[Dictionary]:
	return [characters, creatures, maps_and_props, items, ui, weather]


static func normalize_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	return normalized if normalized.begins_with("res://") else "res://" + normalized.trim_prefix("/")
