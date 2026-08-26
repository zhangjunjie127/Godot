extends Area2D

@export var patch_size := Vector2(240.0, 180.0)
@export var patch_texture: Texture2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(patch_size.x * 0.82, patch_size.y * 0.48)
	var collision := CollisionShape2D.new()
	collision.position = Vector2(0.0, -patch_size.y * 0.24)
	collision.shape = shape
	add_child(collision)

	if patch_texture != null:
		var sprite := Sprite2D.new()
		var scale_factor := minf(
			patch_size.x / float(patch_texture.get_width()),
			patch_size.y / float(patch_texture.get_height())
		)
		sprite.texture = patch_texture
		sprite.scale = Vector2.ONE * scale_factor
		sprite.position = Vector2(0.0, -float(patch_texture.get_height()) * scale_factor * 0.5)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_cover"):
		body.enter_cover(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("exit_cover"):
		body.exit_cover(self)
