extends CharacterBody2D

signal concealment_changed(is_concealed: bool)
signal movement_state_changed(state_label: String)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal oxygen_changed(current: float, maximum: float)
signal health_condition_changed(condition: String)
signal torch_equipped_changed(is_equipped: bool)
signal gender_changed(gender: String)
signal died

const STATE_IDLE := "站立"
const STATE_WALK := "行走"
const STATE_RUN := "奔跑"
const STATE_JUMP := "跳跃"
const STATE_CROUCH := "蹲伏"
const STATE_PRONE := "趴下"
const STATE_CRAWL := "爬行"
const STATE_PICKUP := "拾取"
const STATE_SWIM := "游泳"
const STATE_DIVE := "潜水"
const STATE_DEAD := "死亡"

const CONDITION_HAPPY := "开心"
const CONDITION_UNHAPPY := "不开心"
const CONDITION_SICK := "生病"
const CONDITION_DYING := "濒死"

const GENDER_MALE := "male"
const GENDER_FEMALE := "female"
const CHARACTER_SCALE := Vector2(1.76, 1.76)
const CHARACTER_VISUAL_SCALE := 4.0

const MALE_WALK_TEXTURE := preload("res://assets/characters/player_male_walk/sheet-transparent.png")
const MALE_CROUCH_TEXTURE := preload("res://assets/characters/player_male_crouch/sheet-transparent.png")
const MALE_PRONE_IDLE_TEXTURE := preload("res://assets/characters/player_male_prone_idle/sheet-transparent.png")
const MALE_CRAWL_TEXTURE := preload("res://assets/characters/player_male_crawl/sheet-transparent.png")
const MALE_JUMP_TEXTURE := preload("res://assets/characters/player_male_jump/sheet-transparent.png")
const MALE_TORCH_HOLD_TEXTURE := preload("res://assets/characters/player_male_torch_hold/sheet-transparent.png")
const MALE_PICKUP_TEXTURE := preload("res://assets/characters/player_male_pickup/sheet-transparent.png")
const MALE_IDLE_RELAXED_TEXTURE := preload("res://assets/characters/player_male_idle_relaxed/sheet-transparent.png")
const MALE_IDLE_SIT_TEXTURE := preload("res://assets/characters/player_male_idle_sit/sheet-transparent.png")
const MALE_SWIM_TEXTURE := preload("res://assets/characters/player_male_swim/sheet-transparent.png")

const FEMALE_WALK_TEXTURE := preload("res://assets/characters/player_female_walk/sheet-transparent.png")
const FEMALE_CROUCH_TEXTURE := preload("res://assets/characters/player_female_crouch/sheet-transparent.png")
const FEMALE_PRONE_IDLE_TEXTURE := preload("res://assets/characters/player_female_prone_idle/sheet-transparent.png")
const FEMALE_CRAWL_TEXTURE := preload("res://assets/characters/player_female_crawl/sheet-transparent.png")
const FEMALE_JUMP_TEXTURE := preload("res://assets/characters/player_female_jump/sheet-transparent.png")
const FEMALE_TORCH_HOLD_TEXTURE := preload("res://assets/characters/player_female_torch_hold/sheet-transparent.png")
const FEMALE_PICKUP_TEXTURE := preload("res://assets/characters/player_female_pickup/sheet-transparent.png")
const FEMALE_IDLE_RELAXED_TEXTURE := preload("res://assets/characters/player_female_idle_relaxed/sheet-transparent.png")
const FEMALE_IDLE_SIT_TEXTURE := preload("res://assets/characters/player_female_idle_sit/sheet-transparent.png")
const FEMALE_SWIM_TEXTURE := preload("res://assets/characters/player_female_swim/sheet-transparent.png")

@export var move_speed := 85.0
@export var run_speed := 140.0
@export var crouch_speed := 41.0
@export var crawl_speed := 23.0
@export var jump_height := 30.0
@export var jump_duration := 0.55
@export var world_size := Vector2(2048.0, 2048.0)
@export var is_local_player := true
@export var max_health := 100.0
@export var max_stamina := 100.0
@export var max_hunger := 100.0
@export var stamina_drain_per_second := 28.0
@export var stamina_recovery_per_second := 20.0
@export var hunger_drain_per_second := 0.12
@export_range(0.0, 1.0) var stamina_resume_ratio := 0.2
@export var seated_idle_delay := 8.0
@export var swim_speed := 70.0
@export var dive_speed := 62.0
@export var max_oxygen := 100.0
@export var oxygen_drain_per_second := 7.0
@export var oxygen_recovery_per_second := 24.0

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
var _is_picking_up := false
var _pickup_elapsed := 0.0
var _idle_elapsed := 0.0
var torch_equipped := false
var gender := GENDER_MALE
var health := 100.0
var stamina := 100.0
var hunger := 100.0
var health_condition := CONDITION_HAPPY
var surface_swimming := false
var water_mode := false
var water_surface_y := 0.0
var oxygen := 100.0
var is_dead := false

var _land_collision_mask := 2


func _ready() -> void:
	_land_collision_mask = collision_mask
	health = max_health
	stamina = max_stamina
	hunger = max_hunger
	health_condition = _condition_for_health(health)
	oxygen = max_oxygen
	_ensure_action("player_run", KEY_SHIFT)
	_ensure_action("player_jump", KEY_SPACE)
	_ensure_action("player_crouch", KEY_C)
	_ensure_action("player_crawl", KEY_Z)
	_ensure_action("player_pickup", KEY_F)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		set_gender(String(session.selected_gender))
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		_set_movement_state(STATE_DEAD)
		return
	if Input.is_action_just_pressed("player_pickup") and not _is_picking_up:
		start_pickup()
	_update_pickup(delta)
	if water_mode:
		_physics_process_water(delta)
		return
	if surface_swimming:
		_physics_process_surface_swim(delta)
		return

	var direction := get_movement_input()
	if _is_picking_up:
		direction = Vector2.ZERO

	var jump_pressed := Input.is_action_pressed("player_jump")
	if jump_pressed and not _jump_was_pressed and not _is_jumping and not _is_picking_up:
		_start_jump()
	_jump_was_pressed = jump_pressed
	_update_jump(delta)

	var crawling := Input.is_action_pressed("player_crawl") and not _is_jumping and not _is_picking_up
	var crouching := Input.is_action_pressed("player_crouch") and not crawling and not _is_jumping
	var wants_to_run := Input.is_action_pressed("player_run") and direction.length_squared() > 0.0 and not crouching and not crawling
	var running := wants_to_run and not _is_exhausted
	_update_stamina(delta, running)
	_update_hunger(delta)
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
	_idle_elapsed = _idle_elapsed + delta if state == STATE_IDLE else 0.0
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


func set_torch_equipped(value: bool) -> void:
	if torch_equipped == value:
		return
	torch_equipped = value
	_active_animation = ""
	torch_equipped_changed.emit(value)


func set_gender(value: String) -> void:
	var next_gender := GENDER_FEMALE if value == GENDER_FEMALE else GENDER_MALE
	if gender == next_gender:
		return
	gender = next_gender
	_active_animation = ""
	gender_changed.emit(gender)


func set_water_mode(value: bool, surface_y: float = 0.0) -> void:
	water_mode = value
	if water_mode:
		surface_swimming = false
	water_surface_y = surface_y
	collision_mask = 0 if water_mode or surface_swimming else _land_collision_mask
	_is_jumping = false
	_jump_offset = 0.0
	_is_picking_up = false
	_pickup_elapsed = 0.0
	_active_animation = ""
	set_torch_equipped(false)
	if not water_mode and not is_dead:
		set_oxygen(max_oxygen)
		_set_movement_state(STATE_IDLE)
	queue_redraw()


func set_surface_swimming(value: bool) -> void:
	if surface_swimming == value or water_mode:
		return
	surface_swimming = value
	collision_mask = 0 if surface_swimming else _land_collision_mask
	_is_jumping = false
	_jump_offset = 0.0
	_is_picking_up = false
	_pickup_elapsed = 0.0
	_active_animation = ""
	velocity = Vector2.ZERO
	set_oxygen(max_oxygen)
	_set_movement_state(STATE_SWIM if surface_swimming else STATE_IDLE)
	queue_redraw()


func get_movement_input() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	return wasd.normalized() if wasd.length_squared() > 0.0 else direction


func get_movement_state() -> String:
	return _movement_state


func start_pickup() -> void:
	if _is_jumping or _is_picking_up:
		return
	_is_picking_up = true
	_pickup_elapsed = 0.0
	_set_movement_state(STATE_PICKUP)


func set_health(value: float) -> void:
	var next_value := clampf(value, 0.0, max_health)
	if is_equal_approx(health, next_value):
		if next_value <= 0.0 and not is_dead:
			_die()
		return
	health = next_value
	health_changed.emit(health, max_health)
	var next_condition := _condition_for_health(health)
	if next_condition != health_condition:
		health_condition = next_condition
		health_condition_changed.emit(health_condition)
	if health <= 0.0 and not is_dead:
		_die()


func _die() -> void:
	health = 0.0
	is_dead = true
	velocity = Vector2.ZERO
	_set_movement_state(STATE_DEAD)
	sprite.self_modulate = Color(0.52, 0.72, 0.78, 1.0)
	died.emit()


func take_damage(amount: float) -> void:
	set_health(health - maxf(amount, 0.0))


func restore_health(amount: float) -> void:
	set_health(health + maxf(amount, 0.0))


func set_hunger(value: float) -> void:
	var next_value := clampf(value, 0.0, max_hunger)
	if is_equal_approx(hunger, next_value):
		return
	hunger = next_value
	hunger_changed.emit(hunger, max_hunger)


func eat(amount: float) -> void:
	set_hunger(hunger + maxf(amount, 0.0))


func set_oxygen(value: float) -> void:
	var next_value := clampf(value, 0.0, max_oxygen)
	if is_equal_approx(oxygen, next_value):
		return
	oxygen = next_value
	oxygen_changed.emit(oxygen, max_oxygen)


func _condition_for_health(value: float) -> String:
	var ratio := value / maxf(max_health, 1.0)
	if ratio >= 0.75:
		return CONDITION_HAPPY
	if ratio >= 0.45:
		return CONDITION_UNHAPPY
	if ratio >= 0.15:
		return CONDITION_SICK
	return CONDITION_DYING


func _apply_concealment_visual() -> void:
	visible = is_local_player or not _is_concealed
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.58 if _is_concealed else 1.0)


func _draw() -> void:
	if water_mode:
		draw_circle(Vector2(52.0, -120.0), 8.8, Color(0.72, 0.96, 1.0, 0.72))
		draw_circle(Vector2(72.0, -156.0), 5.2, Color(0.72, 0.96, 1.0, 0.58))
		return
	if surface_swimming:
		return
	var jump_ratio := _jump_offset / jump_height if jump_height > 0.0 else 0.0
	var shadow_width := 1.35 if _movement_state == STATE_PRONE or _movement_state == STATE_CRAWL else 1.1 if _movement_state == STATE_CROUCH else 1.0
	var jump_scale := 1.0 - jump_ratio * 0.45
	draw_set_transform(Vector2(12.0, -4.0), 0.0, Vector2(shadow_width * jump_scale, 0.34 * jump_scale))
	draw_circle(Vector2.ZERO, 60.0, Color(0.08, 0.16, 0.10, 0.28 - jump_ratio * 0.12))
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


func _update_pickup(delta: float) -> void:
	if not _is_picking_up:
		return
	_pickup_elapsed += delta
	if _pickup_elapsed >= 0.72:
		_is_picking_up = false
		_pickup_elapsed = 0.0


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


func _update_hunger(delta: float) -> void:
	set_hunger(hunger - hunger_drain_per_second * delta)


func _physics_process_water(delta: float) -> void:
	var direction := get_movement_input()
	if Input.is_action_pressed("player_jump"):
		direction.y = -1.0
		direction = direction.normalized()
	if _is_picking_up:
		direction = Vector2.ZERO

	var submerged := global_position.y > water_surface_y + 36.0
	var speed := dive_speed if submerged else swim_speed
	velocity = direction * speed
	move_and_slide()
	global_position.y = maxf(global_position.y, water_surface_y - 6.0)
	var bubble_effect := get_parent().get_node_or_null("BubbleEffect")
	if bubble_effect != null:
		bubble_effect.record_swim(direction, delta)
	_update_hunger(delta)
	_update_stamina(delta, false)
	set_oxygen(oxygen + (-oxygen_drain_per_second if submerged else oxygen_recovery_per_second) * delta)
	if submerged and oxygen <= 0.0:
		take_damage(6.0 * delta)

	var state := STATE_PICKUP if _is_picking_up else STATE_DIVE if submerged else STATE_SWIM
	_set_movement_state(state)
	_idle_elapsed = 0.0
	_update_sprite(direction, delta)
	queue_redraw()


func _physics_process_surface_swim(delta: float) -> void:
	var direction := get_movement_input()
	velocity = direction * swim_speed
	move_and_slide()
	global_position = global_position.clamp(Vector2(24.0, 24.0), world_size - Vector2(24.0, 24.0))
	_update_hunger(delta)
	_update_stamina(delta, false)
	_set_movement_state(STATE_SWIM)
	_idle_elapsed = 0.0
	_update_sprite(direction, delta)
	queue_redraw()


func _resolve_movement_state(direction: Vector2, running: bool, crouching: bool, crawling: bool) -> String:
	if _is_picking_up:
		return STATE_PICKUP
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

	var sprite_position := Vector2(0.0, -128.0 - _jump_offset * CHARACTER_VISUAL_SCALE)
	var sprite_scale := CHARACTER_SCALE
	match _movement_state:
		STATE_CROUCH:
			sprite_position.y = -116.0
		STATE_PRONE, STATE_CRAWL:
			sprite_position.y = -88.0
		STATE_SWIM, STATE_DIVE:
			sprite_position.y = -88.0
		STATE_IDLE:
			if _idle_elapsed >= seated_idle_delay and not torch_equipped:
				sprite_position.y = -88.0
	if moving and _facing_row == 0 and (_movement_state == STATE_WALK or _movement_state == STATE_RUN):
		sprite_position.y += 16.0

	sprite.position = sprite_position
	sprite.scale = sprite_scale


func _animation_name(moving: bool) -> String:
	match _movement_state:
		STATE_PICKUP:
			return "pickup"
		STATE_CROUCH:
			return "crouch_move" if moving else "crouch_idle"
		STATE_PRONE:
			return "prone_idle"
		STATE_CRAWL:
			return "crawl_move"
		STATE_SWIM, STATE_DIVE:
			return "swim"
		STATE_JUMP:
			return "jump"
		STATE_RUN:
			return "torch_hold" if torch_equipped else "run"
		STATE_WALK:
			return "torch_hold" if torch_equipped else "walk"
		_:
			if torch_equipped:
				return "torch_hold"
			return "idle_sit" if _idle_elapsed >= seated_idle_delay else "idle_relaxed"


func _animation_texture(animation: String) -> Texture2D:
	var is_female := gender == GENDER_FEMALE
	var fallback: Texture2D
	match animation:
		"crouch_idle", "crouch_move":
			fallback = FEMALE_CROUCH_TEXTURE if is_female else MALE_CROUCH_TEXTURE
		"prone_idle":
			fallback = FEMALE_PRONE_IDLE_TEXTURE if is_female else MALE_PRONE_IDLE_TEXTURE
		"crawl_move":
			fallback = FEMALE_CRAWL_TEXTURE if is_female else MALE_CRAWL_TEXTURE
		"swim":
			fallback = FEMALE_SWIM_TEXTURE if is_female else MALE_SWIM_TEXTURE
		"jump":
			fallback = FEMALE_JUMP_TEXTURE if is_female else MALE_JUMP_TEXTURE
		"torch_hold":
			fallback = FEMALE_TORCH_HOLD_TEXTURE if is_female else MALE_TORCH_HOLD_TEXTURE
		"pickup":
			fallback = FEMALE_PICKUP_TEXTURE if is_female else MALE_PICKUP_TEXTURE
		"idle_relaxed":
			fallback = FEMALE_IDLE_RELAXED_TEXTURE if is_female else MALE_IDLE_RELAXED_TEXTURE
		"idle_sit":
			fallback = FEMALE_IDLE_SIT_TEXTURE if is_female else MALE_IDLE_SIT_TEXTURE
		_:
			fallback = FEMALE_WALK_TEXTURE if is_female else MALE_WALK_TEXTURE
	return ArtAssets.texture(fallback.resource_path, fallback)


func _animation_frame(animation: String, moving: bool) -> int:
	if animation == "pickup":
		return mini(floori(clampf(_pickup_elapsed / 0.72, 0.0, 0.999) * 4.0), 3)
	if animation == "torch_hold":
		return floori(_animation_elapsed / 0.16) % 4
	if animation == "jump":
		var progress := clampf(_jump_elapsed / maxf(jump_duration, 0.01), 0.0, 0.999)
		return mini(floori(progress * 4.0), 3)
	if animation == "prone_idle":
		return floori(_animation_elapsed / 0.24) % 4
	if animation == "idle_relaxed":
		return floori(_animation_elapsed / 0.30) % 4
	if animation == "idle_sit":
		return floori(_animation_elapsed / 0.34) % 4
	if animation == "swim":
		return floori(_animation_elapsed / 0.18) % 4
	if not moving:
		return 0
	var frame_duration := 0.09 if animation == "run" else 0.15 if animation == "crawl_move" else 0.18 if animation == "crouch_move" else 0.14
	return floori(_animation_elapsed / frame_duration) % 4


func _direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 1 if direction.x > 0.0 else 2
	return 0 if direction.y > 0.0 else 3
