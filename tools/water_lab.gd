extends Control

const MAP_TEXTURE := preload("res://assets/maps/spawn/spawn_reference_chunk_0_2.png")
const WATER_MASK := preload("res://assets/maps/spawn/spawn_reference_chunk_0_2_water_mask.png")
const WATER_SHADER := preload("res://shaders/water_comparison.gdshader")
const SAMPLE_REGION := Rect2(0.0, 0.0, 1200.0, 1200.0)
const PRESET_NAMES := ["A  清爽透明", "B  风格浪纹", "C  自然折射"]

@export_group("Art / Water Comparison")
@export var map_texture: Texture2D = MAP_TEXTURE
@export var water_mask: Texture2D = WATER_MASK
@export var water_shader: Shader = WATER_SHADER


func _ready() -> void:
	DisplayServer.window_set_title("水面效果对比")
	_build_comparison()


func _build_comparison() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.04, 0.055)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := Label.new()
	title.text = "水面效果对比"
	title.position = Vector2(0.0, 10.0)
	title.size = Vector2(640.0, 28.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	add_child(title)

	var comparison := HBoxContainer.new()
	comparison.position = Vector2(8.0, 44.0)
	comparison.size = Vector2(624.0, 308.0)
	comparison.add_theme_constant_override("separation", 8)
	add_child(comparison)

	for preset: int in range(PRESET_NAMES.size()):
		comparison.add_child(_build_card(preset))


func _build_card(preset: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200.0, 308.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var label := Label.new()
	label.text = PRESET_NAMES[preset]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	content.add_child(label)

	var preview := Control.new()
	preview.clip_contents = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(preview)

	var editable_map := ArtAssets.texture(map_texture.resource_path, map_texture)
	var editable_mask := ArtAssets.texture(water_mask.resource_path, water_mask)
	var map_crop := _crop(editable_map)
	var base := TextureRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.texture = map_crop
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(base)

	var material := ShaderMaterial.new()
	material.shader = ArtAssets.shader(water_shader.resource_path, water_shader)
	material.set_shader_parameter("water_mask", _crop(editable_mask))
	material.set_shader_parameter("preset", preset)

	var water := TextureRect.new()
	water.name = "WaterPreset%d" % preset
	water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	water.texture = map_crop
	water.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	water.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.material = material
	water.set_meta("preset", preset)
	water.add_to_group("water_comparison_preview")
	preview.add_child(water)
	return card


func _crop(texture: Texture2D) -> AtlasTexture:
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = SAMPLE_REGION
	return crop


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.085)
	style.border_color = Color(0.20, 0.42, 0.52)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
