extends Area2D

signal depleted(resource_id: String, amount: int)

var action_type := "采集"
var resource_id := ""
var display_name := ""
var yield_amount := 1
var required_tool := ""
var hits_required := 1
var hits_remaining := 1
var is_depleted := false


func configure(data: Dictionary) -> void:
	action_type = String(data.get("action", "采集"))
	resource_id = String(data.get("resourceId", ""))
	display_name = String(data.get("name", resource_id))
	yield_amount = maxi(int(data.get("yield", 1)), 1)
	required_tool = String(data.get("requiredTool", ""))
	hits_required = maxi(int(data.get("hits", 1)), 1)
	hits_remaining = hits_required
	add_to_group("interactable")
	add_to_group("interactable_resource")

	var texture := ArtAssets.texture(_resource_path(String(data.get("image", ""))))
	if texture != null:
		var rendered_size := Vector2(
			float(data.get("w", texture.get_width())),
			float(data.get("h", texture.get_height()))
		)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = texture
		sprite.position = Vector2(0.0, -rendered_size.y * 0.5)
		sprite.scale = rendered_size / texture.get_size()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = float(data.get("radius", 24.0))
	collision.position = Vector2(0.0, -float(data.get("collisionOffsetY", 12.0)))
	collision.shape = shape
	add_child(collision)


func interact(inventory) -> bool:
	if is_depleted:
		return false
	if not required_tool.is_empty() and inventory.get_item_count(required_tool) <= 0:
		return false
	hits_remaining -= 1
	modulate = Color(1.0, 0.82, 0.62)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	if hits_remaining > 0:
		return true

	var added: int = inventory.add_item(resource_id, display_name, yield_amount, 99)
	if added <= 0:
		hits_remaining = 1
		return false
	is_depleted = true
	visible = false
	monitoring = false
	depleted.emit(resource_id, added)
	return true


func _resource_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	return normalized if normalized.begins_with("res://") else "res://" + normalized
