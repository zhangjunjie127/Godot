extends Node2D

var item_id := ""
var display_name := ""
var amount := 0

var _sprite: Sprite2D
var _amount_label: Label
var _elapsed := 0.0


func configure(new_item_id: String, new_display_name: String, new_amount: int, icon: Texture2D) -> void:
	item_id = new_item_id
	display_name = new_display_name
	amount = maxi(new_amount, 1)
	add_to_group("interactable")
	add_to_group("dropped_item")

	_sprite = Sprite2D.new()
	_sprite.texture = icon
	_sprite.position = Vector2(0.0, -34.0)
	_sprite.scale = Vector2(0.55, 0.55)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	_amount_label = Label.new()
	_amount_label.position = Vector2(-28.0, 5.0)
	_amount_label.size = Vector2(56.0, 36.0)
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_label.add_theme_font_size_override("font_size", 30)
	_amount_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78))
	_amount_label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.05, 0.95))
	_amount_label.add_theme_constant_override("outline_size", 5)
	add_child(_amount_label)
	_refresh_label()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _sprite != null:
		_sprite.position.y = -34.0 + sin(_elapsed * 2.4) * 3.0


func interact(inventory) -> bool:
	var added: int = inventory.add_item(item_id, display_name, amount, 99)
	if added <= 0:
		return false
	amount -= added
	if amount <= 0:
		visible = false
		remove_from_group("interactable")
		remove_from_group("dropped_item")
		queue_free()
	else:
		_refresh_label()
	return true


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 28.0, Color(0.05, 0.06, 0.055, 0.34))
	draw_set_transform(Vector2.ZERO)


func _refresh_label() -> void:
	_amount_label.text = "×%d" % amount
