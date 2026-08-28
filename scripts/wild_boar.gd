extends CharacterBody2D

@export var roam_speed := 48.0
@export var roam_radius := 150.0
@export var roam_seed := 20260827
@export var hits_required := 3

@onready var sprite: Sprite2D = $Sprite2D

var _rng := RandomNumberGenerator.new()
var _home_position := Vector2.ZERO
var _move_direction := Vector2.DOWN
var _move_remaining := 0.0
var _pause_remaining := 0.6
var _animation_elapsed := 0.0
var _facing_row := 0
var hits_remaining := 3
var is_hunted := false


func _ready() -> void:
	sprite.texture = ArtAssets.texture(sprite.texture.resource_path, sprite.texture)
	_home_position = global_position
	_rng.seed = roam_seed
	hits_remaining = hits_required
	add_to_group("interactable")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_hunted:
		return
	if _pause_remaining > 0.0:
		_pause_remaining -= delta
		velocity = Vector2.ZERO
		if _pause_remaining <= 0.0:
			_start_roaming()
	else:
		_move_remaining -= delta
		if global_position.distance_to(_home_position) > roam_radius:
			_move_direction = global_position.direction_to(_home_position)
		velocity = _move_direction * roam_speed
		move_and_slide()
		if get_slide_collision_count() > 0 or _move_remaining <= 0.0:
			_start_pause()

	_update_animation(delta)
	queue_redraw()


func interact(inventory) -> bool:
	if is_hunted or inventory.get_item_count("stone_axe") <= 0:
		return false
	hits_remaining -= 1
	modulate = Color(1.0, 0.62, 0.55)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.14)
	if hits_remaining > 0:
		_start_pause()
		return true

	var added: int = inventory.add_item("meat_boar", "野猪肉", 3, 99)
	if added <= 0:
		hits_remaining = 1
		return false
	is_hunted = true
	visible = false
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	return true


func _draw() -> void:
	draw_set_transform(Vector2(2.0, -1.0), 0.0, Vector2(1.15, 0.38))
	draw_circle(Vector2.ZERO, 13.0, Color(0.08, 0.12, 0.07, 0.26))
	draw_set_transform(Vector2.ZERO)


func _start_roaming() -> void:
	_move_direction = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	_move_remaining = _rng.randf_range(1.0, 2.8)
	_pause_remaining = 0.0


func _start_pause() -> void:
	velocity = Vector2.ZERO
	_pause_remaining = _rng.randf_range(0.5, 1.5)
	_move_remaining = 0.0


func _update_animation(delta: float) -> void:
	var moving := velocity.length_squared() > 1.0
	if moving:
		_facing_row = _direction_row(velocity)
		_animation_elapsed += delta
	else:
		_animation_elapsed = 0.0
	var frame_column := floori(_animation_elapsed / 0.15) % 4 if moving else 0
	sprite.frame_coords = Vector2i(frame_column, _facing_row)


func _direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x > 0.0 else 1
	return 0 if direction.y > 0.0 else 3
