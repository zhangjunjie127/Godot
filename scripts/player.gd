extends CharacterBody2D

signal concealment_changed(is_concealed: bool)
signal movement_state_changed(state_label: String)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)

const STATE_IDLE := "站立"
const STATE_WALK := "行走"
const STATE_RUN := "奔跑"
const STATE_JUMP := "跳跃"
const STATE_CROUCH := "蹲伏"
const STATE_PRONE := "趴下"
const STATE_CRAWL := "爬行"

const WALK_TEXTURE := preload("res://assets/characters/player_male_walk/sheet-transparent.png")
const CROUCH_TEXTURE := preload("res://assets/characters/player_male_crouch/sheet-transparent.png")
const PRONE_IDLE_TEXTURE := preload("res://assets/characters/player_male_prone_idle/sheet-transparent.png")
const CRAWL_TEXTURE := preload("res://assets/characters/player_male_crawl/sheet-transparent.png")
const JUMP_TEXTURE := preload("res://assets/characters/player_male_jump/sheet-transparent.png")

@export var move_speed := 170.0
@export var run_speed := 280.0
@export var crouch_speed := 82.0
@export var crawl_speed := 46.0
@export var jump_height := 30.0
@export var jump_duration := 0.55
@export var world_size := Vector2(2048.0, 2048.0)
@export var is_local_player := true
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_drain_per_second := 28.0
@export var stamina_recovery_per_second := 20.0
@export_range(0.0, 1.0) var stamina_resume_ratio := 0.2

@onready var sprite: Sprite2D = $Sprite2D

var _cover_sources: Dictionary = {}
var _is_concealed := false
var _is_jumping := false
var _jump_elapsed := 0.0
var _jump_offset := 0.0
var _jump_was_pressed := false
var _movement_state := STATE_IDLE
var _is_exhausted := false
var _animation_elapsed := 0.0
var _active_animation := ""
var _facing_row := 0
var health := 100.0
var stamina := 100.0


func _ready() -> void:
	health = max_health
	stamina = max_stamina
	_ensure_action("player_run", KEY_SHIFT)
	_ensure_action("player_jump", KEY_SPACE)
	_ensure_action("player_crouch", KEY_C)
	_ensure_action("player_crawl", KEY_Z)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length_squared() > 0.0:
		direction = wasd.normalized()

	var jump_pressed := Input.is_action_pressed("player_jump")
	if jump_pressed and not _jump_was_pressed and not _is_jumping:
		_start_jump()
	_jump_was_pressed = jump_pressed
	_update_jump(delta)

	var crawling := Input.is_action_pressed("player_crawl") and not _is_jumping
	var crouching := Input.is_action_pressed("player_crouch") and not crawling and not _is_jumping
	var wants_to_run := Input.is_action_pressed("player_run") and direction.length_squared() > 0.0 and not crouching and not crawling
	var running := wants_to_run and not _is_exhausted
	_update_stamina(delta, running)
	var speed := move_speed
	if crawling:
		speed = crawl_speed
	elif crouching:
		speed = crouch_speed
	elif running:
		speed = run_speed

	velocity = direction * speed
	move_and_slide()
	global_position = global_position.clamp(Vector2(24.0, 24.0), world_size - Vector2(24.0, 24.0))

	var state := _resolve_movement_state(direction, running, crouching, crawling)
	_set_movement_state(state)
	_update_sprite(direction, delta)
	queue_redraw()


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


func set_health(value: float) -> void:
	var next_value := clampf(value, 0.0, max_health)
	if is_equal_approx(health, next_value):
		return
	health = next_value
	health_changed.emit(health, max_health)


func take_damage(amount: float) -> void:
	set_health(health - maxf(amount, 0.0))


func restore_health(amount: float) -> void:
	set_health(health + maxf(amount, 0.0))


func _apply_concealment_visual() -> void:
	visible = is_local_player or not _is_concealed
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.58 if _is_concealed else 1.0)


func _draw() -> void:
	var jump_ratio := _jump_offset / jump_height if jump_height > 0.0 else 0.0
	var shadow_width := 1.35 if _movement_state == STATE_PRONE or _movement_state == STATE_CRAWL else 1.1 if _movement_state == STATE_CROUCH else 1.0
	var jump_scale := 1.0 - jump_ratio * 0.45
	draw_set_transform(Vector2(3.0, -1.0), 0.0, Vector2(shadow_width * jump_scale, 0.34 * jump_scale))
	draw_circle(Vector2.ZERO, 15.0, Color(0.08, 0.16, 0.10, 0.28 - jump_ratio * 0.12))
	draw_set_transform(Vector2.ZERO)


func _start_jump() -> void:
	_is_jumping = true
	_jump_elapsed = 0.0


func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _update_jump(delta: float) -> void:
	if not _is_jumping:
		_jump_offset = 0.0
		return
	_jump_elapsed += delta
	var progress := minf(_jump_elapsed / maxf(jump_duration, 0.01), 1.0)
	_jump_offset = sin(progress * PI) * jump_height
	if progress >= 1.0:
		_is_jumping = false
		_jump_offset = 0.0


func _update_stamina(delta: float, running: bool) -> void:
	var change := -stamina_drain_per_second if running else stamina_recovery_per_second
	var next_value := clampf(stamina + change * delta, 0.0, max_stamina)
	if not is_equal_approx(stamina, next_value):
		stamina = next_value
		stamina_changed.emit(stamina, max_stamina)

	if stamina <= 0.0:
		_is_exhausted = true
	elif _is_exhausted and stamina >= max_stamina * stamina_resume_ratio:
		_is_exhausted = false


func _resolve_movement_state(direction: Vector2, running: bool, crouching: bool, crawling: bool) -> String:
	if _is_jumping:
		return STATE_JUMP
	if crawling:
		return STATE_CRAWL if direction.length_squared() > 0.0 else STATE_PRONE
	if crouching:
		return STATE_CROUCH
	if direction.length_squared() == 0.0:
		return STATE_IDLE
	return STATE_RUN if running else STATE_WALK


func _set_movement_state(value: String) -> void:
	if _movement_state == value:
		return
	_movement_state = value
	movement_state_changed.emit(value)


func _update_sprite(direction: Vector2, delta: float) -> void:
	var moving := direction.length_squared() > 0.0
	if moving:
		_facing_row = _direction_row(direction)

	var animation := _animation_name(moving)
	if animation != _active_animation:
		_active_animation = animation
		_animation_elapsed = 0.0
	else:
		_animation_elapsed += delta

	var frame_column := _animation_frame(animation, moving)
	sprite.texture = _animation_texture(animation)
	sprite.frame_coords = Vector2i(frame_column, _facing_row)

	var sprite_position := Vector2(0.0, -32.0 - _jump_offset)
	var sprite_scale := Vector2(0.44, 0.44)
	match _movement_state:
		STATE_CROUCH:
			sprite_position.y = -29.0
		STATE_PRONE, STATE_CRAWL:
			sprite_position.y = -22.0

	sprite.position = sprite_position
	sprite.scale = sprite_scale


func _animation_name(moving: bool) -> String:
	match _movement_state:
		STATE_CROUCH:
			return "crouch_move" if moving else "crouch_idle"
		STATE_PRONE:
			return "prone_idle"
		STATE_CRAWL:
			return "crawl_move"
		STATE_JUMP:
			return "jump"
		STATE_RUN:
			return "run"
		STATE_WALK:
			return "walk"
		_:
			return "idle"


func _animation_texture(animation: String) -> Texture2D:
	match animation:
		"crouch_idle", "crouch_move":
			return CROUCH_TEXTURE
		"prone_idle":
			return PRONE_IDLE_TEXTURE
		"crawl_move":
			return CRAWL_TEXTURE
		"jump":
			return JUMP_TEXTURE
		_:
			return WALK_TEXTURE


func _animation_frame(animation: String, moving: bool) -> int:
	if animation == "jump":
		var progress := clampf(_jump_elapsed / maxf(jump_duration, 0.01), 0.0, 0.999)
		return mini(floori(progress * 4.0), 3)
	if animation == "prone_idle":
		return floori(_animation_elapsed / 0.24) % 4
	if not moving:
		return 0
	var frame_duration := 0.09 if animation == "run" else 0.15 if animation == "crawl_move" else 0.18 if animation == "crouch_move" else 0.14
	return floori(_animation_elapsed / frame_duration) % 4


func _direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 1 if direction.x > 0.0 else 2
	return 0 if direction.y > 0.0 else 3
