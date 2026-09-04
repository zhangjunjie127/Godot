extends Node2D

signal felled(item_id: String, display_name: String, amount: int, world_position: Vector2)

@export_group("Tree Species / 树木品种")
@export var tree_species := "coconut_palm"
@export var resource_id := "wood_palm"
@export var display_name := "椰木"
@export_range(1, 20, 1) var min_hits := 4
@export_range(1, 20, 1) var max_hits := 7
@export_range(1, 99, 1) var min_drop := 8
@export_range(1, 99, 1) var max_drop := 15

@export_group("Requirements / 砍伐条件")
@export var required_tool_id := "stone_axe"
@export var required_skill_id := "stone_axe_gathering"

@export_group("Hit Reaction / 受击反馈")
@export var visual_path := NodePath("Sprite2D")
@export_range(1.0, 40.0, 0.5) var hit_impulse := 12.0
@export_range(10.0, 240.0, 1.0) var spring_strength := 95.0
@export_range(1.0, 40.0, 0.5) var spring_damping := 13.0
@export_range(1.0, 12.0, 0.5) var max_tilt_degrees := 5.0
@export_range(0.0, 0.15, 0.005) var max_depth_deformation := 0.055

@export_group("Respawn / 刷新")
@export_range(1, 100, 1) var respawn_days := 10

var hits_required := 1
var hits_remaining := 1
var last_drop_amount := 0
var is_felled := false

var _rng := RandomNumberGenerator.new()
var _visual: Sprite2D
var _visual_rest_transform := Transform2D.IDENTITY
var _visual_anchor := Vector2.ZERO
var _reaction := Vector2.ZERO
var _reaction_velocity := Vector2.ZERO
var _current_game_hours := 0.0
var _felled_at_game_hours := -1.0


func _ready() -> void:
	_rng.randomize()
	hits_required = _rng.randi_range(mini(min_hits, max_hits), maxi(min_hits, max_hits))
	hits_remaining = hits_required
	_visual = get_node_or_null(visual_path) as Sprite2D
	if _visual != null:
		_visual_rest_transform = _visual.transform
		_visual_anchor = _visual_rest_transform * _sprite_ground_anchor(_visual)
	add_to_group("choppable_tree")


func _process(delta: float) -> void:
	if _visual == null or (_reaction.is_zero_approx() and _reaction_velocity.is_zero_approx()):
		return
	delta = minf(delta, 1.0 / 30.0)
	var acceleration := -_reaction * spring_strength - _reaction_velocity * spring_damping
	_reaction_velocity += acceleration * delta
	_reaction += _reaction_velocity * delta
	_reaction = _reaction.limit_length(1.0)
	if _reaction.length_squared() < 0.000001 and _reaction_velocity.length_squared() < 0.0001:
		_reaction = Vector2.ZERO
		_reaction_velocity = Vector2.ZERO
		_visual.transform = _visual_rest_transform
		return
	_apply_hit_reaction()


func chop(inventory, skill_tree, hit_direction: Vector2 = Vector2.RIGHT) -> bool:
	if is_felled or inventory.get_item_count(required_tool_id) <= 0 or not skill_tree.is_unlocked(required_skill_id):
		return false
	hits_remaining -= 1
	_play_hit_feedback(hit_direction)
	if hits_remaining > 0:
		return true
	last_drop_amount = _rng.randi_range(mini(min_drop, max_drop), maxi(min_drop, max_drop))
	is_felled = true
	_felled_at_game_hours = _current_game_hours
	for collision: Node in find_children("*", "CollisionShape2D", true, false):
		collision.set_deferred("disabled", true)
	visible = false
	felled.emit(resource_id, display_name, last_drop_amount, get_interaction_position())
	return true


func update_game_time(day: int, hour: int, minute: int) -> void:
	_current_game_hours = float(maxi(day - 1, 0) * 24 + hour) + float(minute) / 60.0
	if is_felled and _felled_at_game_hours >= 0.0 and _current_game_hours - _felled_at_game_hours >= float(respawn_days * 24):
		_respawn()


func get_interaction_position() -> Vector2:
	var blocker := get_node_or_null("Blocker") as StaticBody2D
	if blocker != null:
		var collision := blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			return collision.global_position
	return global_position


func _respawn() -> void:
	is_felled = false
	_felled_at_game_hours = -1.0
	hits_required = _rng.randi_range(mini(min_hits, max_hits), maxi(min_hits, max_hits))
	hits_remaining = hits_required
	last_drop_amount = 0
	_reaction = Vector2.ZERO
	_reaction_velocity = Vector2.ZERO
	self_modulate = Color.WHITE
	if _visual != null:
		_visual.transform = _visual_rest_transform
	visible = true
	for collision: Node in find_children("*", "CollisionShape2D", true, false):
		collision.set_deferred("disabled", false)


func _play_hit_feedback(hit_direction: Vector2) -> void:
	var direction := hit_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	_reaction_velocity = (_reaction_velocity + direction * hit_impulse).limit_length(hit_impulse * 1.6)
	self_modulate = Color(1.0, 0.74, 0.48)
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.16)


func _apply_hit_reaction() -> void:
	var tilt := deg_to_rad(max_tilt_degrees) * _reaction.x
	var depth_scale := clampf(1.0 - _reaction.y * max_depth_deformation, 0.85, 1.15)
	var reaction_transform := Transform2D(
		_visual_rest_transform.get_rotation() + tilt,
		_visual_rest_transform.get_scale() * Vector2(1.0 / sqrt(depth_scale), depth_scale),
		_visual_rest_transform.get_skew(),
		Vector2.ZERO
	)
	reaction_transform.origin = _visual_anchor - reaction_transform * _sprite_ground_anchor(_visual)
	_visual.transform = reaction_transform


func _sprite_ground_anchor(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2.ZERO
	var frame_size := sprite.region_rect.size if sprite.region_enabled else Vector2(
		float(sprite.texture.get_width()) / float(maxi(sprite.hframes, 1)),
		float(sprite.texture.get_height()) / float(maxi(sprite.vframes, 1))
	)
	return sprite.offset + (Vector2(0.0, frame_size.y * 0.5) if sprite.centered else Vector2(frame_size.x * 0.5, frame_size.y))
