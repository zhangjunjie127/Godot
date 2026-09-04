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

var hits_required := 1
var hits_remaining := 1
var last_drop_amount := 0
var is_felled := false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	hits_required = _rng.randi_range(mini(min_hits, max_hits), maxi(min_hits, max_hits))
	hits_remaining = hits_required
	add_to_group("choppable_tree")


func chop(inventory, skill_tree) -> bool:
	if is_felled or inventory.get_item_count(required_tool_id) <= 0 or not skill_tree.is_unlocked(required_skill_id):
		return false
	hits_remaining -= 1
	_play_hit_feedback()
	if hits_remaining > 0:
		return true
	last_drop_amount = _rng.randi_range(mini(min_drop, max_drop), maxi(min_drop, max_drop))
	is_felled = true
	for collision: Node in find_children("*", "CollisionShape2D", true, false):
		collision.set_deferred("disabled", true)
	visible = false
	felled.emit(resource_id, display_name, last_drop_amount, global_position)
	return true


func _play_hit_feedback() -> void:
	self_modulate = Color(1.0, 0.74, 0.48)
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.16)
