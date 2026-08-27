extends Node2D

const InventoryDataScript = preload("res://scripts/inventory.gd")
const EraSkillTreeScript = preload("res://scripts/skill_tree.gd")
const STATUS_ICON_ATLAS := preload("res://assets/ui/status_icons/sheet-transparent.png")
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
@onready var era_day_label: Label = $HUD/WorldInfo/Margin/Row/Details/EraDayLabel
@onready var time_label: Label = $HUD/WorldInfo/Margin/Row/TimeLabel
@onready var phase_label: Label = $HUD/WorldInfo/Margin/Row/PhaseLabel
@onready var area_label: Label = $HUD/WorldInfo/Margin/Row/Details/AreaLabel
@onready var health_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthBar
@onready var health_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthLabel
@onready var stamina_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaBar
@onready var stamina_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaLabel
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
@onready var skill_branches: VBoxContainer = $HUD/SkillOverlay/SkillPanel/Margin/Content/Branches
@onready var ritual_row: HBoxContainer = $HUD/SkillOverlay/SkillPanel/Margin/Content/RitualRow

var inventory
var skill_tree


func _ready() -> void:
	inventory = InventoryDataScript.new()
	skill_tree = EraSkillTreeScript.new()
	player.concealment_changed.connect(_on_concealment_changed)
	player.movement_state_changed.connect(_on_movement_state_changed)
	player.health_changed.connect(_on_health_changed)
	player.health_condition_changed.connect(_on_health_condition_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	day_night_cycle.time_changed.connect(_on_time_changed)
	inventory.inventory_changed.connect(_refresh_inventory)
	skill_tree.tree_changed.connect(_refresh_skill_tree)
	skill_tree.era_changed.connect(_on_era_changed)
	$HUD/BottomActions/BackpackButton.pressed.connect(_toggle_inventory)
	$HUD/BottomActions/SkillTreeButton.pressed.connect(_toggle_skill_tree)
	$HUD/InventoryOverlay/InventoryPanel/Margin/Content/Header/CloseButton.pressed.connect(_hide_overlays)
	$HUD/SkillOverlay/SkillPanel/Margin/Content/Header/CloseButton.pressed.connect(_hide_overlays)
	_ensure_action("toggle_inventory", KEY_B)
	_ensure_action("toggle_skill_tree", KEY_K)
	_on_concealment_changed(false)
	_on_movement_state_changed("站立")
	_on_health_changed(player.health, player.max_health)
	_on_health_condition_changed(player.health_condition)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_on_time_changed(
		day_night_cycle.current_day,
		floori(day_night_cycle.current_hour),
		floori(fposmod(day_night_cycle.current_hour, 1.0) * 60.0),
		day_night_cycle.current_phase
	)
	_refresh_inventory()
	_refresh_skill_tree()


func _process(_delta: float) -> void:
	var area_name := _get_area_name(player.global_position)
	if area_label.text != area_name:
		area_label.text = area_name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_skill_tree"):
		_toggle_skill_tree()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and (inventory_overlay.visible or skill_overlay.visible):
		_hide_overlays()
		get_viewport().set_input_as_handled()


func _on_concealment_changed(is_concealed: bool) -> void:
	_set_atlas_icon(visibility_icon, Vector2i(0, 3) if is_concealed else Vector2i(3, 2))
	visibility_icon.tooltip_text = "草丛隐蔽" if is_concealed else "公开可见"


func _on_movement_state_changed(state_label: String) -> void:
	_set_atlas_icon(action_icon, ACTION_ICON_CELLS.get(state_label, Vector2i.ZERO))
	action_icon.tooltip_text = state_label


func _on_health_condition_changed(condition: String) -> void:
	_set_atlas_icon(condition_icon, CONDITION_ICON_CELLS.get(condition, Vector2i(3, 1)))
	condition_icon.tooltip_text = condition


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "生命 %d / %d" % [roundi(current), roundi(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "体力 %d / %d" % [roundi(current), roundi(maximum)]


func _on_time_changed(day: int, hour: int, minute: int, phase: String) -> void:
	era_day_label.text = "%s · 第 %d 日" % [skill_tree.current_era, day]
	time_label.text = "%02d:%02d" % [hour, minute]
	phase_label.text = phase
	_set_atlas_icon(phase_icon, PHASE_ICON_CELLS.get(phase, Vector2i(1, 3)))
	phase_icon.tooltip_text = phase
	var phase_color := Color(0.98, 0.86, 0.34)
	if phase == "黄昏":
		phase_color = Color(1.0, 0.62, 0.31)
	elif phase == "夜晚":
		phase_color = Color(0.66, 0.78, 1.0)
	phase_label.add_theme_color_override("font_color", phase_color)


func _on_era_changed(_era_name: String) -> void:
	_on_time_changed(
		day_night_cycle.current_day,
		floori(day_night_cycle.current_hour),
		floori(fposmod(day_night_cycle.current_hour, 1.0) * 60.0),
		day_night_cycle.current_phase
	)


func _toggle_inventory() -> void:
	inventory_overlay.visible = not inventory_overlay.visible
	skill_overlay.visible = false
	if inventory_overlay.visible:
		_refresh_inventory()


func _toggle_skill_tree() -> void:
	skill_overlay.visible = not skill_overlay.visible
	inventory_overlay.visible = false
	if skill_overlay.visible:
		_refresh_skill_tree()


func _hide_overlays() -> void:
	inventory_overlay.visible = false
	skill_overlay.visible = false


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
			button.text = "%s\nx%d" % [String(slot["name"]), int(slot["count"])]
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


func _set_atlas_icon(target: TextureRect, cell: Vector2i) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = STATUS_ICON_ATLAS
	texture.region = Rect2(Vector2(cell * ICON_CELL_SIZE), Vector2.ONE * ICON_CELL_SIZE)
	target.texture = texture


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


func _get_area_name(position: Vector2) -> String:
	if position.y < 500.0:
		return "北部巨像山脉"
	if position.x > 1200.0 and position.y < 950.0:
		return "东部荒漠"
	if position.y > 1450.0:
		return "南部碧湾"
	if position.x < 950.0:
		return "西部台地"
	return "中央河谷"
