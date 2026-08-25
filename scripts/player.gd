extends CharacterBody2D

signal concealment_changed(is_concealed: bool)

@export var move_speed := 170.0
@export var world_size := Vector2(6144.0, 6144.0)
@export var is_local_player := true

@onready var sprite: Sprite2D = $Sprite2D

var _cover_sources: Dictionary = {}
var _is_concealed := false


func _ready() -> void:
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length_squared() > 0.0:
		direction = wasd.normalized()

	velocity = direction * move_speed
	move_and_slide()
	global_position = global_position.clamp(Vector2(24.0, 24.0), world_size - Vector2(24.0, 24.0))
	_update_sprite(direction)


func enter_cover(source: Node) -> void:
	_cover_sources[source.get_instance_id()] = true
	set_concealed(true)


func exit_cover(source: Node) -> void:
	_cover_sources.erase(source.get_instance_id())
	set_concealed(not _cover_sources.is_empty())


func set_concealed(value: bool) -> void:
	if _is_concealed == value:
		return
	_is_concealed = value
	_apply_concealment_visual()
	concealment_changed.emit(value)


func set_local_player(value: bool) -> void:
	is_local_player = value
	_apply_concealment_visual()


func _apply_concealment_visual() -> void:
	visible = is_local_player or not _is_concealed
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.58 if _is_concealed else 1.0)


func _draw() -> void:
	draw_set_transform(Vector2(3.0, -1.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 15.0, Color(0.08, 0.16, 0.10, 0.28))
	draw_set_transform(Vector2.ZERO)


func _update_sprite(direction: Vector2) -> void:
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	var bob := sin(Time.get_ticks_msec() * 0.018) * 1.5 if direction.length_squared() > 0.0 else 0.0
	sprite.position.y = -32.0 + bob
