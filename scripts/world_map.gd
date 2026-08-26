extends Node2D

const MANIFEST_PATH := "res://assets/maps/spawn/spawn_map.json"
const GRASS_PATCH_SCRIPT := preload("res://scripts/grass_patch.gd")
const BLOCKER_LAYER := 2

@onready var foundation: Node2D = $Foundation
@onready var collision_root: Node2D = $Collision
@onready var depth_sorted: Node2D = $DepthSorted
@onready var metadata_root: Node = $GameplayMetadata
@onready var player: CharacterBody2D = $DepthSorted/Player


func _ready() -> void:
	var manifest := _read_manifest()
	if manifest.is_empty():
		return

	var map_size := _map_size(manifest)
	player.world_size = map_size
	player.global_position = _point(manifest.get("spawn", {}))
	_apply_camera_limits(map_size)
	_add_chunks(manifest.get("chunks", []))
	_add_props(manifest.get("props", []))
	_add_grass_patches(manifest.get("grass", []))
	_add_world_blockers(manifest.get("blockers", []))
	_add_zone_markers(manifest.get("zones", []))


func _read_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open spawn map manifest: " + MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Spawn map manifest is not a JSON object")
		return {}
	return parsed


func _map_size(manifest: Dictionary) -> Vector2:
	var value: Dictionary = manifest.get("mapSize", {})
	return Vector2(float(value.get("width", 2048.0)), float(value.get("height", 2048.0)))


func _apply_camera_limits(map_size: Vector2) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)


func _add_chunks(chunks: Array) -> void:
	for data: Dictionary in chunks:
		var texture := load(_resource_path(String(data.get("image", "")))) as Texture2D
		if texture == null:
			push_error("Missing map chunk: " + String(data.get("image", "")))
			continue
		var sprite := Sprite2D.new()
		sprite.name = String(data.get("id", "Chunk")).to_pascal_case()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = _point(data.get("position", [0, 0]))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		foundation.add_child(sprite)


func _add_props(props: Array) -> void:
	for data: Dictionary in props:
		var texture := load(_resource_path(String(data.get("image", "")))) as Texture2D
		if texture == null:
			push_error("Missing map prop: " + String(data.get("image", "")))
			continue

		var prop := Node2D.new()
		prop.name = String(data.get("id", "Prop")).to_pascal_case()
		prop.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		prop.rotation_degrees = float(data.get("rotation", 0.0))
		depth_sorted.add_child(prop)

		var rendered_size := Vector2(float(data.get("w", texture.get_width())), float(data.get("h", texture.get_height())))
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = texture
		sprite.scale = rendered_size / texture.get_size()
		sprite.position = Vector2(0.0, -rendered_size.y * 0.5)
		sprite.flip_h = bool(data.get("flipH", false))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		prop.add_child(sprite)

		var collision_data: Dictionary = data.get("collision", {})
		if not collision_data.is_empty():
			var body := StaticBody2D.new()
			body.name = "Blocker"
			body.collision_layer = BLOCKER_LAYER
			body.collision_mask = 0
			prop.add_child(body)
			_add_collision_shape(body, collision_data)


func _add_grass_patches(patches: Array) -> void:
	for data: Dictionary in patches:
		var grass := GRASS_PATCH_SCRIPT.new() as Area2D
		grass.name = String(data.get("id", "Grass")).to_pascal_case()
		grass.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		grass.set("patch_size", Vector2(float(data.get("w", 240.0)), float(data.get("h", 180.0))))
		grass.set("patch_texture", load(_resource_path(String(data.get("image", "")))) as Texture2D)
		depth_sorted.add_child(grass)


func _add_world_blockers(blockers: Array) -> void:
	for data: Dictionary in blockers:
		var body := StaticBody2D.new()
		body.name = String(data.get("id", "Blocker")).to_pascal_case()
		body.collision_layer = BLOCKER_LAYER
		body.collision_mask = 0
		collision_root.add_child(body)
		_add_collision_shape(body, data)


func _add_collision_shape(parent: CollisionObject2D, data: Dictionary) -> void:
	var collision := CollisionShape2D.new()
	collision.position = _point(data.get("offset", [0, 0]))
	var shape_type := String(data.get("type", "rect"))
	match shape_type:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = float(data.get("radius", 16.0))
			collision.shape = circle
		"polygon":
			var polygon := ConvexPolygonShape2D.new()
			var points := PackedVector2Array()
			for value: Variant in data.get("points", []):
				points.append(_point(value))
			polygon.points = points
			collision.shape = polygon
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = _point(data.get("size", [32, 32]))
			collision.shape = rectangle
	parent.add_child(collision)


func _add_zone_markers(zones: Array) -> void:
	for data: Dictionary in zones:
		var marker := Marker2D.new()
		marker.name = String(data.get("id", "Zone")).to_pascal_case()
		marker.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		marker.set_meta("zone_type", String(data.get("type", "")))
		marker.set_meta("radius", float(data.get("radius", 0.0)))
		metadata_root.add_child(marker)


func _resource_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	return normalized if normalized.begins_with("res://") else "res://" + normalized


func _point(value: Variant) -> Vector2:
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
