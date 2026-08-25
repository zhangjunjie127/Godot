extends CharacterBody2D

signal concealment_changed(is_concealed: bool)

@export var move_speed := 170.0
@export var world_size := Vector2(6144.0, 6144.0)

@onready var sprite: Sprite2D = $Sprite2D

var _cover_sources: Dictionary = {}


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
	_set_concealed(true)


func exit_cover(source: Node) -> void:
	_cover_sources.erase(source.get_instance_id())
	_set_concealed(not _cover_sources.is_empty())


func _set_concealed(value: bool) -> void:
	var alpha := 0.58 if value else 1.0
	if is_equal_approx(sprite.self_modulate.a, alpha):
		return
	sprite.self_modulate = Color(1.0, 1.0, 1.0, alpha)
	concealment_changed.emit(value)


func _update_sprite(direction: Vector2) -> void:
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
	var bob := sin(Time.get_ticks_msec() * 0.018) * 1.5 if direction.length_squared() > 0.0 else 0.0
	sprite.position.y = -32.0 + bob
