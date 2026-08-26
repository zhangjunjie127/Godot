extends Node2D

@onready var player: CharacterBody2D = $World/DepthSorted/Player
@onready var area_label: Label = $HUD/TopBar/Margin/Row/AreaLabel
@onready var action_label: Label = $HUD/TopBar/Margin/Row/ActionLabel
@onready var concealment_label: Label = $HUD/TopBar/Margin/Row/ConcealmentLabel


func _ready() -> void:
	player.concealment_changed.connect(_on_concealment_changed)
	player.movement_state_changed.connect(_on_movement_state_changed)
	_on_concealment_changed(false)
	_on_movement_state_changed("站立")


func _process(_delta: float) -> void:
	area_label.text = _get_area_name(player.global_position)


func _on_concealment_changed(is_concealed: bool) -> void:
	concealment_label.text = "状态：草丛隐蔽" if is_concealed else "状态：可见"
	concealment_label.add_theme_color_override(
		"font_color",
		Color(0.65, 1.0, 0.62) if is_concealed else Color.WHITE
	)


func _on_movement_state_changed(state_label: String) -> void:
	action_label.text = "动作：" + state_label


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
