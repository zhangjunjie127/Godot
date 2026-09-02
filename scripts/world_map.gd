@tool
extends Node2D

const MANIFEST_PATH := "res://assets/maps/spawn/spawn_map.json"
const GRASS_PATCH_SCRIPT := preload("res://scripts/grass_patch.gd")
const RESOURCE_NODE_SCRIPT := preload("res://scripts/resource_node.gd")
const RIVER_SURFACE_SHADER := preload("res://shaders/river_surface.gdshader")
const BLOCKER_LAYER := 2
const DEFAULT_CHUNK_SIZE := 2048.0
const STREAM_MARGIN := 64.0

@export_group("Art / Water")
@export var water_surface_shader: Shader = RIVER_SURFACE_SHADER

@export_group("Editor Preview")
@export var show_collision_debug := true:
	set(value):
		show_collision_debug = value
		queue_redraw()

@onready var foundation: Node2D = $Foundation
@onready var collision_root: Node2D = $Collision
@onready var depth_sorted: Node2D = $DepthSorted
@onready var metadata_root: Node = $GameplayMetadata
@onready var player: CharacterBody2D = $DepthSorted/Player

var _content_scale := 1.0
var _water_polygons: Array[PackedVector2Array] = []
var _chunk_size := DEFAULT_CHUNK_SIZE
var _chunk_definitions: Array[Dictionary] = []
var _loaded_chunks: Dictionary = {}
var _active_chunk_bounds := Rect2i(Vector2i(-999, -999), Vector2i.ZERO)
var _water_surface: Dictionary = {}
var _water_weather_strength := 0.0


func _ready() -> void:
	var manifest := _read_manifest()
	if manifest.is_empty():
		return
	_content_scale = float(manifest.get("contentScale", 1.0))
	var show_vegetation := bool(manifest.get("showVegetation", true))
	var show_props := bool(manifest.get("showProps", true))
	_chunk_size = float(manifest.get("chunkSize", DEFAULT_CHUNK_SIZE)) * _content_scale
	_chunk_definitions.assign(manifest.get("chunks", []))
	_water_surface = manifest.get("waterSurface", {})
	_cache_water_polygons()
	if Engine.is_editor_hint():
		_add_all_chunks()
		if show_props:
			_add_props(manifest.get("props", []))
		queue_redraw()
		return

	var map_size := _map_size(manifest)
	player.world_size = map_size
	player.global_position = _scaled_point(manifest.get("spawn", {}))
	_apply_camera_limits(map_size)
	_refresh_streamed_chunks(true)
	if show_props:
		_add_props(manifest.get("props", []))
	if show_vegetation:
		_add_grass_patches(manifest.get("grass", []))
	_add_resource_nodes(manifest.get("resources", []), show_vegetation)
	_add_zone_markers(manifest.get("zones", []))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not visible or not is_instance_valid(player):
		return
	_refresh_streamed_chunks()


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
	return Vector2(float(value.get("width", 2048.0)), float(value.get("height", 2048.0))) * _content_scale


func _apply_camera_limits(map_size: Vector2) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	var viewport_size := get_viewport_rect().size
	var minimum_zoom := maxf(viewport_size.x / map_size.x, viewport_size.y / map_size.y)
	var zoom_value := maxf(camera.zoom.x, minimum_zoom)
	camera.zoom = Vector2.ONE * zoom_value


func _add_all_chunks() -> void:
	for data: Dictionary in _chunk_definitions:
		_load_chunk(data)


func _refresh_streamed_chunks(force := false) -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	var half_view := get_viewport_rect().size / camera.zoom * 0.5 + Vector2.ONE * STREAM_MARGIN
	var minimum := Vector2i(
		floori((player.global_position.x - half_view.x) / _chunk_size),
		floori((player.global_position.y - half_view.y) / _chunk_size)
	)
	var maximum := Vector2i(
		floori((player.global_position.x + half_view.x) / _chunk_size),
		floori((player.global_position.y + half_view.y) / _chunk_size)
	)
	var bounds := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	if not force and bounds == _active_chunk_bounds:
		return
	_active_chunk_bounds = bounds

	var required := {}
	for data: Dictionary in _chunk_definitions:
		var chunk_position := _point(data.get("position", [0, 0])) * _content_scale
		var coordinates := Vector2i(roundi(chunk_position.x / _chunk_size), roundi(chunk_position.y / _chunk_size))
		if bounds.has_point(coordinates):
			var id := String(data.get("id", ""))
			required[id] = true
			if not _loaded_chunks.has(id):
				_load_chunk(data)

	for id: String in _loaded_chunks.keys():
		if required.has(id):
			continue
		var sprite := _loaded_chunks[id] as Sprite2D
		_loaded_chunks.erase(id)
		sprite.queue_free()


func _load_chunk(data: Dictionary) -> void:
	var id := String(data.get("id", "Chunk"))
	var texture := ArtAssets.texture(_resource_path(String(data.get("image", ""))))
	if texture == null:
		push_error("Missing map chunk: " + String(data.get("image", "")))
		return
	var sprite := Sprite2D.new()
	sprite.name = id.to_pascal_case()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = _scaled_point(data.get("position", [0, 0]))
	sprite.scale = Vector2.ONE * _content_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	foundation.add_child(sprite)
	_add_water_surface(sprite, data, texture)
	_loaded_chunks[id] = sprite


func _add_water_surface(chunk: Sprite2D, data: Dictionary, source_texture: Texture2D) -> void:
	if not bool(_water_surface.get("enabled", true)):
		return
	var water_data: Dictionary = data.get("water", {})
	var mask_texture := ArtAssets.texture(_resource_path(String(water_data.get("image", ""))))
	if mask_texture == null:
		push_error("Missing water mask for map chunk: " + String(data.get("id", "")))
		return
	var depth_resource := String(water_data.get("depth", String(water_data.get("image", "")).replace("_mask.png", "_depth.png")))
	var depth_texture := ArtAssets.texture(_resource_path(depth_resource))
	if depth_texture == null:
		push_error("Missing water depth mask for map chunk: " + String(data.get("id", "")))
		return

	var material := ShaderMaterial.new()
	material.shader = ArtAssets.shader(water_surface_shader.resource_path, water_surface_shader)
	material.set_shader_parameter("water_mask", mask_texture)
	material.set_shader_parameter("water_depth", depth_texture)
	material.set_shader_parameter("chunk_world_origin", chunk.position)
	material.set_shader_parameter("chunk_world_size", source_texture.get_size() * _content_scale)
	material.set_shader_parameter("flow_direction", _point(_water_surface.get("flowDirection", [0.94, 0.34])))
	material.set_shader_parameter("flow_speed", float(_water_surface.get("flowSpeed", 22.0)))
	material.set_shader_parameter("distortion_pixels", float(_water_surface.get("distortionPixels", 4.0)))
	material.set_shader_parameter("tint_strength", float(_water_surface.get("tintStrength", 0.10)))
	material.set_shader_parameter("shallow_strength", float(_water_surface.get("shallowStrength", 0.14)))
	material.set_shader_parameter("highlight_strength", float(_water_surface.get("highlightStrength", 0.018)))
	material.set_shader_parameter("reflection_strength", float(_water_surface.get("reflectionStrength", 0.06)))
	material.set_shader_parameter("shoreline_strength", float(_water_surface.get("shorelineStrength", 0.10)))
	material.set_shader_parameter("weather_strength", _water_weather_strength)
	material.set_shader_parameter("water_tint", _color(_water_surface.get("tint", [0.02, 0.34, 0.52, 1.0])))
	material.set_shader_parameter("shallow_tint", _color(_water_surface.get("shallowTint", [0.08, 0.68, 0.74, 1.0])))
	material.set_shader_parameter("reflection_tint", _color(_water_surface.get("reflectionTint", [0.66, 0.84, 0.90, 1.0])))

	var water := Sprite2D.new()
	water.name = "WaterSurface"
	water.texture = source_texture
	water.centered = false
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	water.material = material
	chunk.add_child(water)


func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func set_water_weather_strength(value: float) -> void:
	var strength := clampf(value, 0.0, 1.0)
	if is_equal_approx(_water_weather_strength, strength):
		return
	_water_weather_strength = strength
	for chunk: Sprite2D in _loaded_chunks.values():
		var water := chunk.get_node_or_null("WaterSurface") as Sprite2D
		if water != null and water.material is ShaderMaterial:
			(water.material as ShaderMaterial).set_shader_parameter("weather_strength", strength)


func _add_props(props: Array) -> void:
	for data: Dictionary in props:
		var texture := ArtAssets.texture(_resource_path(String(data.get("image", ""))))
		if texture == null:
			push_error("Missing map prop: " + String(data.get("image", "")))
			continue

		var prop := Node2D.new()
		prop.name = String(data.get("id", "Prop")).to_pascal_case()
		prop.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))) * _content_scale
		prop.rotation_degrees = float(data.get("rotation", 0.0))
		depth_sorted.add_child(prop)

		var rendered_size := Vector2(float(data.get("w", texture.get_width())), float(data.get("h", texture.get_height()))) * _content_scale
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
		grass.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))) * _content_scale
		grass.set("patch_size", Vector2(float(data.get("w", 240.0)), float(data.get("h", 180.0))) * _content_scale)
		grass.set("patch_texture", ArtAssets.texture(_resource_path(String(data.get("image", "")))))
		depth_sorted.add_child(grass)


func _add_resource_nodes(resources: Array, include_vegetation := true) -> void:
	for data: Dictionary in resources:
		if not include_vegetation and String(data.get("resourceId", "")) != "stone":
			continue
		var resource_node := RESOURCE_NODE_SCRIPT.new()
		resource_node.name = String(data.get("id", "Resource")).to_pascal_case()
		resource_node.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))) * _content_scale
		depth_sorted.add_child(resource_node)
		resource_node.configure(data)


func _add_collision_shape(parent: CollisionObject2D, data: Dictionary) -> void:
	var shape_type := String(data.get("type", "rect"))
	if shape_type == "polygon":
		var polygon := CollisionPolygon2D.new()
		polygon.position = _scaled_point(data.get("offset", [0, 0]))
		var points := PackedVector2Array()
		for value: Variant in data.get("points", []):
			points.append(_scaled_point(value))
		polygon.polygon = points
		parent.add_child(polygon)
		return

	var collision := CollisionShape2D.new()
	collision.position = _scaled_point(data.get("offset", [0, 0]))
	match shape_type:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = float(data.get("radius", 16.0)) * _content_scale
			collision.shape = circle
		"segment":
			var segment := SegmentShape2D.new()
			segment.a = _scaled_point(data.get("a", [0, 0]))
			segment.b = _scaled_point(data.get("b", [0, 0]))
			collision.shape = segment
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = _scaled_point(data.get("size", [32, 32]))
			collision.shape = rectangle
	parent.add_child(collision)


func _add_zone_markers(zones: Array) -> void:
	for data: Dictionary in zones:
		var marker := Marker2D.new()
		marker.name = String(data.get("id", "Zone")).to_pascal_case()
		marker.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))) * _content_scale
		marker.set_meta("zone_type", String(data.get("type", "")))
		marker.set_meta("radius", float(data.get("radius", 0.0)) * _content_scale)
		metadata_root.add_child(marker)


func _resource_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	return normalized if normalized.begins_with("res://") else "res://" + normalized


func is_water_position(world_position: Vector2) -> bool:
	for polygon: PackedVector2Array in _water_polygons:
		if Geometry2D.is_point_in_polygon(world_position, polygon):
			return true
	return false


func _cache_water_polygons() -> void:
	_water_polygons.clear()
	for body: Node in collision_root.get_children():
		if not body.is_in_group("water_collision"):
			continue
		for child: Node in body.get_children():
			if not child is CollisionPolygon2D:
				continue
			var polygon := PackedVector2Array()
			for point: Vector2 in (child as CollisionPolygon2D).polygon:
				polygon.append((child as CollisionPolygon2D).to_global(point))
			if polygon.size() >= 3:
				_water_polygons.append(polygon)


func _point(value: Variant) -> Vector2:
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _scaled_point(value: Variant) -> Vector2:
	return _point(value) * _content_scale


func _color(value: Variant) -> Color:
	if value is Array and value.size() >= 3:
		return Color(
			float(value[0]),
			float(value[1]),
			float(value[2]),
			float(value[3]) if value.size() >= 4 else 1.0
		)
	return Color(0.06, 0.50, 0.66, 1.0)


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_collision_debug:
		return
	var manifest := _read_manifest()
	var debug_scale := float(manifest.get("contentScale", 1.0))
	var fill := Color(0.94, 0.12, 0.16, 0.24)
	var line := Color(1.0, 0.22, 0.20, 0.92)
	for prop_data: Dictionary in manifest.get("props", []):
		var collision_data: Dictionary = prop_data.get("collision", {})
		if collision_data.is_empty():
			continue
		var origin := Vector2(float(prop_data.get("x", 0.0)), float(prop_data.get("y", 0.0))) * debug_scale
		_draw_collision_debug(collision_data, origin, debug_scale, fill, line)


func _draw_collision_debug(data: Dictionary, origin: Vector2, debug_scale: float, fill: Color, line: Color) -> void:
	var shape_type := String(data.get("type", "rect"))
	var offset := _point(data.get("offset", [0, 0])) * debug_scale
	var center := origin + offset
	if shape_type == "polygon":
		var points := PackedVector2Array()
		for value: Variant in data.get("points", []):
			points.append(center + _point(value) * debug_scale)
		if points.size() >= 3:
			draw_colored_polygon(points, fill)
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, line, 3.0, true)
	elif shape_type == "segment":
		draw_line(center + _point(data.get("a", [0, 0])) * debug_scale, center + _point(data.get("b", [0, 0])) * debug_scale, line, 5.0, true)
	elif shape_type == "circle":
		var radius := float(data.get("radius", 16.0)) * debug_scale
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 32, line, 3.0, true)
	else:
		var size := _point(data.get("size", [32, 32])) * debug_scale
		draw_rect(Rect2(center - size * 0.5, size), fill, true)
		draw_rect(Rect2(center - size * 0.5, size), line, false, 3.0)
