@tool
extends Sprite2D


func _ready() -> void:
	if texture != null:
		texture = ArtAssets.texture(texture.resource_path, texture)
