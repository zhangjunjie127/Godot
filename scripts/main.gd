extends Node2D

const InventoryDataScript = preload("res://scripts/inventory.gd")
const EraSkillTreeScript = preload("res://scripts/skill_tree.gd")

@onready var player: CharacterBody2D = $World/DepthSorted/Player
@onready var day_night_cycle = $DayNightCycle
@onready var era_day_label: Label = $HUD/WorldInfo/Margin/Row/Details/EraDayLabel
@onready var time_label: Label = $HUD/WorldInfo/Margin/Row/TimeLabel
@onready var phase_label: Label = $HUD/WorldInfo/Margin/Row/PhaseLabel
@onready var area_label: Label = $HUD/WorldInfo/Margin/Row/Details/AreaLabel
@onready var action_label: Label = $HUD/StatusTray/Margin/Row/ActionLabel
@onready var concealment_label: Label = $HUD/StatusTray/Margin/Row/ConcealmentLabel
@onready var health_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthBar
@onready var health_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/HealthGroup/HealthLabel
@onready var stamina_bar: ProgressBar = $HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaBar
@onready var stamina_label: Label = $HUD/PlayerStatus/Margin/Content/Stats/StaminaGroup/StaminaLabel
@onready var inventory_overlay: Control = $HUD/InventoryOverlay
@onready var inventory_grid: GridContainer = $HUD/InventoryOverlay/InventoryPanel/Margin/Content/InventoryGrid
@onready var inventory_capacity_label: Label = $HUD/InventoryOverlay/InventoryPanel/Margin/Content/CapacityLabel
@onready var skill_overlay: Control = $HUD/SkillOverlay
@onready var skill_points_label: Label = $HUD/SkillOverlay/SkillPanel/Margin/Content/Header/SkillPointsLabel
@onready var era_progress_label: Label = $HUD/SkillOverlay/SkillPanel/Margin/Content/EraProgressLabel
@onready var skill_tree_row: HBoxContainer = $HUD/SkillOverlay/SkillPanel/Margin/Content/TreeRow

var inventory
var skill_tree


func _ready() -> void:
	inventory = InventoryDataScript.new()
	skill_tree = EraSkillTreeScript.new()
	player.concealment_changed.connect(_on_concealment_changed)
	player.movement_state_changed.connect(_on_movement_state_changed)
	player.health_changed.connect(_on_health_changed)
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
	concealment_label.text = "草丛隐蔽" if is_concealed else "公开可见"
	concealment_label.add_theme_color_override(
		"font_color",
		Color(0.63, 1.0, 0.60) if is_concealed else Color(0.86, 0.91, 0.82)
	)


func _on_movement_state_changed(state_label: String) -> void:
	action_label.text = state_label


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
	_clear_children(skill_tree_row)
	skill_points_label.text = "技能点  %d" % skill_tree.skill_points
	era_progress_label.text = "已进化至 青铜时代" if skill_tree.current_era == "青铜时代" else "原始时代 → 青铜时代"
	for index: int in range(skill_tree.SKILLS.size()):
		if index > 0:
			var arrow := Label.new()
			arrow.custom_minimum_size = Vector2(12.0, 64.0)
			arrow.text = ">"
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow.add_theme_color_override("font_color", Color(0.59, 0.66, 0.49))
			skill_tree_row.add_child(arrow)

		var skill: Dictionary = skill_tree.SKILLS[index]
		var skill_id := String(skill["id"])
		var unlocked: bool = skill_tree.is_unlocked(skill_id)
		var available: bool = skill_tree.can_unlock(skill_id)
		var ritual := bool(skill.get("ritual", false))
		var button := Button.new()
		button.custom_minimum_size = Vector2(82.0, 64.0)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not available
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", Color(0.94, 0.95, 0.87))
		button.add_theme_color_override("font_disabled_color", Color(0.56, 0.61, 0.52))
		button.pressed.connect(_on_skill_pressed.bind(skill_id))
		if unlocked:
			button.text = "%s\n已完成" % String(skill["name"])
			button.add_theme_stylebox_override("disabled", _style_box(Color(0.12, 0.28, 0.17), Color(0.48, 0.78, 0.42), 2))
		elif available:
			button.text = "%s\n%s" % [String(skill["name"]), "可举行" if ritual else "消耗 1 点"]
			button.add_theme_stylebox_override("normal", _style_box(Color(0.23, 0.20, 0.07), Color(0.98, 0.76, 0.22), 2))
			button.add_theme_stylebox_override("hover", _style_box(Color(0.31, 0.27, 0.08), Color(1.0, 0.86, 0.34), 2))
			button.add_theme_stylebox_override("pressed", _style_box(Color(0.16, 0.28, 0.13), Color(0.78, 0.94, 0.45), 2))
		else:
			button.text = "%s\n%s" % [String(skill["name"]), "待激活" if ritual else "未解锁"]
			button.add_theme_stylebox_override("disabled", _style_box(Color(0.055, 0.075, 0.06), Color(0.22, 0.28, 0.20)))
		skill_tree_row.add_child(button)


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
