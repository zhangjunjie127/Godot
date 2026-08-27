extends Node2D

const InventoryDataScript = preload("res://scripts/inventory.gd")
const EraSkillTreeScript = preload("res://scripts/skill_tree.gd")
const STATUS_ICON_ATLAS := preload("res://assets/ui/status_icons/sheet-transparent.png")
const PICKUP_ACTION_ATLAS := preload("res://assets/characters/player_male_pickup/sheet-transparent.png")
const MALE_PORTRAIT := preload("res://assets/characters/player_male.png")
const FEMALE_PORTRAIT := preload("res://assets/characters/player_female.png")
const TORCH_ICON_ATLAS := preload("res://assets/items/torch/sheet-transparent.png")
const STONE_AXE_ICON := preload("res://assets/items/stone_axe/icon.png")
const ICON_CELL_SIZE := 64

const ACTION_ICON_CELLS := {
	"站立": Vector2i(0, 0),
	"行走": Vector2i(1, 0),
	"奔跑": Vector2i(2, 0),
	"跳跃": Vector2i(3, 0),
	"蹲伏": Vector2i(0, 1),
	"趴下": Vector2i(1, 1),
	"爬行": Vector2i(2, 1),
}
const CONDITION_ICON_CELLS := {
	"开心": Vector2i(3, 1),
	"不开心": Vector2i(0, 2),
	"生病": Vector2i(1, 2),
	"濒死": Vector2i(2, 2),
}
const PHASE_ICON_CELLS := {
	"白天": Vector2i(1, 3),
	"黄昏": Vector2i(2, 3),
	"夜晚": Vector2i(3, 3),
}

@onready var player: CharacterBody2D = $World/DepthSorted/Player
@onready var day_night_cycle = $DayNightCycle
@onready var weather = $Weather/Effect
@onready var night_vision = $NightVision/Mask
@onready var era_day_label: Label = $HUD/WorldInfo/Margin/Row/Details/EraDayLabel
@onready var health_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthBar
@onready var health_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthLabel
@onready var stamina_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaBar
@onready var stamina_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaLabel
@onready var hunger_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/HungerGroup/HungerBar
@onready var hunger_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/HungerGroup/HungerLabel
@onready var portrait: TextureRect = $HUD/PlayerStatus/Margin/Content/PortraitFrame/Portrait
@onready var condition_icon: TextureRect = $HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/ConditionIcon
@onready var action_icon: TextureRect = $HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/ActionIcon
@onready var visibility_icon: TextureRect = $HUD/PlayerStatus/Margin/Content/Stats/IndicatorRow/VisibilityIcon
@onready var phase_icon: TextureRect = $HUD/PhasePanel/Margin/PhaseIcon
@onready var inventory_overlay: Control = $HUD/InventoryOverlay
@onready var inventory_grid: GridContainer = $HUD/InventoryOverlay/InventoryPanel/Margin/Content/InventoryGrid
@onready var inventory_capacity_label: Label = $HUD/InventoryOverlay/InventoryPanel/Margin/Content/CapacityLabel
@onready var skill_overlay: Control = $HUD/SkillOverlay
@onready var skill_points_label: Label = $HUD/SkillOverlay/SkillPanel/Margin/Content/Header/SkillPointsLabel
@onready var era_progress_label: Label = $HUD/SkillOverlay/SkillPanel/Margin/Content/EraProgressLabel
@onready var skill_branches: VBoxContainer = $HUD/SkillOverlay/SkillPanel/Margin/Content/TreeRow/Branches
@onready var ritual_row: HBoxContainer = $HUD/SkillOverlay/SkillPanel/Margin/Content/TreeRow/RitualRow
@onready var forecast_popup: PanelContainer = $HUD/ForecastPopup
@onready var forecast_label: Label = $HUD/ForecastPopup/Margin/ForecastLabel
@onready var world_map_overlay: Control = $HUD/WorldMapOverlay
@onready var world_map_coordinate_label: Label = $HUD/WorldMapOverlay/MapPanel/Margin/Content/CoordinateLabel

var inventory
var skill_tree
var _forecast_visible_seconds := 0.0
var _last_forecast_day := 0


func _ready() -> void:
	inventory = InventoryDataScript.new()
	skill_tree = EraSkillTreeScript.new()
	player.concealment_changed.connect(_on_concealment_changed)
	player.movement_state_changed.connect(_on_movement_state_changed)
	player.health_changed.connect(_on_health_changed)
	player.health_condition_changed.connect(_on_health_condition_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.hunger_changed.connect(_on_hunger_changed)
	player.gender_changed.connect(_on_gender_changed)
	day_night_cycle.time_changed.connect(_on_time_changed)
	inventory.inventory_changed.connect(_on_inventory_changed)
	skill_tree.tree_changed.connect(_refresh_skill_tree)
	skill_tree.era_changed.connect(_on_era_changed)
	weather.forecast_changed.connect(_show_weather_forecast)
	$HUD/BottomActions/BackpackButton.pressed.connect(_toggle_inventory)
	$HUD/BottomActions/SkillTreeButton.pressed.connect(_toggle_skill_tree)
	$HUD/InventoryOverlay/InventoryPanel/Margin/Content/Header/CloseButton.pressed.connect(_hide_overlays)
	$HUD/SkillOverlay/SkillPanel/Margin/Content/Header/CloseButton.pressed.connect(_hide_overlays)
	$HUD/WorldMapOverlay/MapPanel/Margin/Content/Header/CloseButton.pressed.connect(_hide_overlays)
	_ensure_action("toggle_inventory", KEY_B)
	_ensure_action("toggle_skill_tree", KEY_K)
	_ensure_action("toggle_world_map", KEY_M)
	_on_concealment_changed(false)
	_on_movement_state_changed("站立")
	_on_health_changed(player.health, player.max_health)
	_on_health_condition_changed(player.health_condition)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_on_hunger_changed(player.hunger, player.max_hunger)
	_on_gender_changed(player.gender)
	_on_time_changed(
		day_night_cycle.current_day,
		floori(day_night_cycle.current_hour),
		floori(fposmod(day_night_cycle.current_hour, 1.0) * 60.0),
		day_night_cycle.current_phase
	)
	_refresh_inventory()
	_refresh_skill_tree()


func _process(delta: float) -> void:
	if _forecast_visible_seconds > 0.0:
		_forecast_visible_seconds = maxf(_forecast_visible_seconds - delta, 0.0)
		forecast_popup.visible = _forecast_visible_seconds > 0.0
	if world_map_overlay.visible:
		world_map_coordinate_label.text = "坐标  %d, %d" % [roundi(player.global_position.x), roundi(player.global_position.y)]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_skill_tree"):
		_toggle_skill_tree()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_world_map"):
		_toggle_world_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and (inventory_overlay.visible or skill_overlay.visible or world_map_overlay.visible):
		_hide_overlays()
		get_viewport().set_input_as_handled()


func _on_concealment_changed(is_concealed: bool) -> void:
	_set_atlas_icon(visibility_icon, Vector2i(0, 3) if is_concealed else Vector2i(3, 2), 48)
	visibility_icon.tooltip_text = "草丛隐蔽" if is_concealed else "公开可见"


func _on_movement_state_changed(state_label: String) -> void:
	if state_label == "拾取":
		var texture := AtlasTexture.new()
		texture.atlas = PICKUP_ACTION_ATLAS
		texture.region = Rect2(256.0, 0.0, 128.0, 128.0)
		action_icon.texture = texture
	else:
		_set_atlas_icon(action_icon, ACTION_ICON_CELLS.get(state_label, Vector2i.ZERO), 48)
	action_icon.tooltip_text = state_label


func _on_health_condition_changed(condition: String) -> void:
	_set_atlas_icon(condition_icon, CONDITION_ICON_CELLS.get(condition, Vector2i(3, 1)), 48)
	condition_icon.tooltip_text = condition


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "生命 %d / %d" % [roundi(current), roundi(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "体力 %d / %d" % [roundi(current), roundi(maximum)]


func _on_hunger_changed(current: float, maximum: float) -> void:
	hunger_bar.max_value = maximum
	hunger_bar.value = current
	hunger_label.text = "饥饿 %d / %d" % [roundi(current), roundi(maximum)]
	var ratio := current / maxf(maximum, 1.0)
	var green := Color(0.22, 0.78, 0.24)
	var yellow := Color(0.94, 0.72, 0.12)
	var red := Color(0.88, 0.16, 0.11)
	var fill_color := yellow.lerp(green, (ratio - 0.5) * 2.0) if ratio >= 0.5 else red.lerp(yellow, ratio * 2.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(4)
	hunger_bar.add_theme_stylebox_override("fill", fill_style)


func _on_gender_changed(gender: String) -> void:
	portrait.texture = FEMALE_PORTRAIT if gender == "female" else MALE_PORTRAIT


func _on_time_changed(day: int, _hour: int, _minute: int, phase: String) -> void:
	era_day_label.text = "%s · 第 %d 日" % [skill_tree.current_era, day]
	_set_atlas_icon(phase_icon, PHASE_ICON_CELLS.get(phase, Vector2i(1, 3)), 40)
	phase_icon.tooltip_text = phase
	_sync_night_state(phase)
	if day != _last_forecast_day:
		_last_forecast_day = day
		_show_weather_forecast(weather.get_forecast(2))


func _on_era_changed(_era_name: String) -> void:
	_on_time_changed(
		day_night_cycle.current_day,
		floori(day_night_cycle.current_hour),
		floori(fposmod(day_night_cycle.current_hour, 1.0) * 60.0),
		day_night_cycle.current_phase
	)


func _toggle_inventory() -> void:
	_dismiss_forecast()
	inventory_overlay.visible = not inventory_overlay.visible
	skill_overlay.visible = false
	world_map_overlay.visible = false
	if inventory_overlay.visible:
		_refresh_inventory()


func _toggle_skill_tree() -> void:
	_dismiss_forecast()
	skill_overlay.visible = not skill_overlay.visible
	inventory_overlay.visible = false
	world_map_overlay.visible = false
	if skill_overlay.visible:
		_refresh_skill_tree()


func _hide_overlays() -> void:
	inventory_overlay.visible = false
	skill_overlay.visible = false
	world_map_overlay.visible = false


func _toggle_world_map() -> void:
	_dismiss_forecast()
	world_map_overlay.visible = not world_map_overlay.visible
	inventory_overlay.visible = false
	skill_overlay.visible = false


func _on_inventory_changed() -> void:
	_refresh_inventory()
	_sync_night_state(day_night_cycle.current_phase)


func _sync_night_state(phase: String) -> void:
	var is_night := phase == "夜晚"
	var has_torch: bool = inventory.get_item_count("torch") > 0
	player.set_torch_equipped(is_night and has_torch)
	night_vision.set_night_state(is_night, has_torch)


func _show_weather_forecast(forecast: Array) -> void:
	var lines: Array[String] = ["天气预报"]
	for entry: Dictionary in forecast:
		var weather_name := String(entry["weather"])
		if weather_name == "下雨":
			weather_name = String(entry.get("rain_level", "中雨"))
		elif weather_name == "下雪":
			weather_name = String(entry.get("snow_level", "中雪"))
		lines.append("未来 %d 日  %s" % [int(entry["day_offset"]), weather_name])
	forecast_label.text = "\n".join(lines)
	forecast_popup.visible = true
	_forecast_visible_seconds = 6.0


func _dismiss_forecast() -> void:
	forecast_popup.visible = false
	_forecast_visible_seconds = 0.0


func _refresh_inventory() -> void:
	_clear_children(inventory_grid)
	var used_slots := 0
	for slot: Dictionary in inventory.slots:
		var button := Button.new()
		button.custom_minimum_size = Vector2(54.0, 40.0)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", Color(0.93, 0.95, 0.86))
		button.add_theme_stylebox_override("normal", _style_box(Color(0.07, 0.11, 0.085, 0.98), Color(0.32, 0.42, 0.28)))
		button.add_theme_stylebox_override("hover", _style_box(Color(0.09, 0.15, 0.11, 1.0), Color(0.54, 0.66, 0.36)))
		if slot.is_empty():
			button.text = "空"
			button.add_theme_color_override("font_color", Color(0.43, 0.49, 0.40))
		else:
			used_slots += 1
			button.icon = _item_icon(String(slot["id"]))
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 24)
			button.text = "x%d" % int(slot["count"])
			button.tooltip_text = "%s  %d/%d" % [String(slot["name"]), int(slot["count"]), int(slot["max_stack"])]
		inventory_grid.add_child(button)
	inventory_capacity_label.text = "容量  %d / %d" % [used_slots, inventory.slots.size()]


func _refresh_skill_tree() -> void:
	_clear_children(skill_branches)
	_clear_children(ritual_row)
	skill_points_label.text = "技能点  %d" % skill_tree.skill_points
	era_progress_label.text = "已进化至 青铜时代" if skill_tree.current_era == "青铜时代" else "原始时代 → 青铜时代"
	for branch: Dictionary in skill_tree.BRANCHES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var category := Label.new()
		category.custom_minimum_size = Vector2(62.0, 42.0)
		category.text = String(branch["name"])
		category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		category.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		category.add_theme_font_size_override("font_size", 11)
		category.add_theme_color_override("font_color", _branch_color(String(branch["id"])))
		row.add_child(category)
		var skills: Array = branch["skills"]
		for index: int in range(skills.size()):
			if index > 0:
				var arrow := Label.new()
				arrow.custom_minimum_size = Vector2(10.0, 42.0)
				arrow.text = ">"
				arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				arrow.add_theme_color_override("font_color", Color(0.48, 0.55, 0.42))
				row.add_child(arrow)
			row.add_child(_create_skill_button(skills[index], String(branch["id"])))
		skill_branches.add_child(row)

	var ritual_available: bool = skill_tree.can_unlock(skill_tree.RITUAL_ID)
	var ritual_unlocked: bool = skill_tree.is_unlocked(skill_tree.RITUAL_ID)
	var ritual_button := Button.new()
	ritual_button.custom_minimum_size = Vector2(150.0, 42.0)
	ritual_button.focus_mode = Control.FOCUS_NONE
	ritual_button.disabled = not ritual_available
	ritual_button.add_theme_font_size_override("font_size", 11)
	ritual_button.pressed.connect(_on_skill_pressed.bind(skill_tree.RITUAL_ID))
	if ritual_unlocked:
		ritual_button.text = "◆ 升维仪式已完成"
		ritual_button.add_theme_stylebox_override("disabled", _style_box(Color(0.12, 0.28, 0.17), Color(0.48, 0.78, 0.42), 2))
	elif ritual_available:
		ritual_button.text = "◆ 点亮升维仪式"
		ritual_button.add_theme_stylebox_override("normal", _style_box(Color(0.28, 0.21, 0.06), Color(1.0, 0.78, 0.22), 2))
		ritual_button.add_theme_stylebox_override("hover", _style_box(Color(0.36, 0.28, 0.08), Color(1.0, 0.9, 0.4), 2))
	else:
		ritual_button.text = "◇ 升维仪式"
		ritual_button.add_theme_stylebox_override("disabled", _style_box(Color(0.055, 0.075, 0.06), Color(0.22, 0.28, 0.20)))
	ritual_row.add_child(ritual_button)


func _create_skill_button(skill: Dictionary, branch_id: String) -> Button:
	var skill_id := String(skill["id"])
	var unlocked: bool = skill_tree.is_unlocked(skill_id)
	var available: bool = skill_tree.can_unlock(skill_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(108.0, 42.0)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not available
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.88))
	button.add_theme_color_override("font_disabled_color", Color(0.57, 0.62, 0.53))
	button.pressed.connect(_on_skill_pressed.bind(skill_id))
	if unlocked:
		var color := _branch_color(branch_id)
		button.text = "◆ " + String(skill["name"])
		button.add_theme_stylebox_override("disabled", _style_box(Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 1.0), color, 2))
	elif available:
		button.text = "◇ " + String(skill["name"])
		button.add_theme_stylebox_override("normal", _style_box(Color(0.23, 0.20, 0.07), Color(0.98, 0.76, 0.22), 2))
		button.add_theme_stylebox_override("hover", _style_box(Color(0.31, 0.27, 0.08), Color(1.0, 0.86, 0.34), 2))
	else:
		button.text = "· " + String(skill["name"])
		button.add_theme_stylebox_override("disabled", _style_box(Color(0.055, 0.075, 0.06), Color(0.22, 0.28, 0.20)))
	button.tooltip_text = String(skill["name"])
	return button


func _branch_color(branch_id: String) -> Color:
	match branch_id:
		"technology":
			return Color(0.95, 0.57, 0.24)
		"learning":
			return Color(0.40, 0.70, 0.92)
		_:
			return Color(0.48, 0.82, 0.42)


func _set_atlas_icon(target: TextureRect, cell: Vector2i, region_size: int = ICON_CELL_SIZE) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = STATUS_ICON_ATLAS
	var inset := float(ICON_CELL_SIZE - region_size) * 0.5
	texture.region = Rect2(Vector2(cell * ICON_CELL_SIZE) + Vector2.ONE * inset, Vector2.ONE * region_size)
	target.texture = texture


func _item_icon(item_id: String) -> Texture2D:
	if item_id == "stone_axe":
		return STONE_AXE_ICON
	if item_id == "torch":
		var texture := AtlasTexture.new()
		texture.atlas = TORCH_ICON_ATLAS
		texture.region = Rect2(0.0, 0.0, 128.0, 128.0)
		return texture
	return null


func _on_skill_pressed(skill_id: String) -> void:
	skill_tree.unlock_skill(skill_id)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _style_box(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style


func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
