extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame

	var player = scene.get_node("World/DepthSorted/Player")
	var tree = scene.get_node("World/DepthSorted/NortheastPalm01")
	var beach_palms: Array[Node] = []
	for candidate: Node in get_nodes_in_group("choppable_tree"):
		if String(candidate.tree_species) == "coconut_palm":
			beach_palms.append(candidate)
	if beach_palms.size() != 17:
		_fail("Not every northeast beach palm is connected to the chopping system: %d" % beach_palms.size())
		return
	for palm: Node in beach_palms:
		var trunk_collision := palm.get_node("Blocker/CollisionShape2D") as CollisionShape2D
		var visuals: Array[Node] = palm.get_children().filter(func(child: Node) -> bool: return child is Sprite2D and (child as Sprite2D).texture != null)
		if visuals.size() != 1:
			_fail("A choppable palm must contain exactly one independently interactive visual: " + palm.name)
			return
		var visual_anchor: Vector2 = (palm as Node2D).to_global(visuals[0].get_trunk_anchor_position())
		if palm.respawn_days != 10 or palm.get_interaction_position().distance_to(trunk_collision.global_position) > 0.01:
			_fail("A beach palm is missing its ten-day respawn or trunk interaction position: " + palm.name)
			return
		if visual_anchor.distance_to(palm.get_interaction_position()) > scene.CHOP_RANGE:
			_fail("A visible palm trunk is outside its attack interaction range: " + palm.name)
			return
	for target: Node in beach_palms:
		for palm: Node in beach_palms:
			palm.visible = palm == target
		var target_visual := target.get_node("Sprite2D") as Sprite2D
		var transform_before := target_visual.transform
		var hits_before: int = target.hits_remaining
		player.global_position = target.get_interaction_position() + Vector2(0.0, -120.0)
		player._facing_row = 0
		scene._on_player_attack_started()
		target._process(0.04)
		if target.hits_remaining != hits_before - 1 or target_visual.transform == transform_before:
			_fail("A visible coconut palm did not react to the real attack selection path: " + target.name)
			return
	for palm: Node in beach_palms:
		palm.visible = true
	if scene.inventory.get_item_count("stone_axe") != 1 or not scene.skill_tree.is_unlocked("stone_axe_gathering"):
		_fail("Demo does not start with the stone axe and gathering skill")
		return
	if tree.hits_required < tree.min_hits or tree.hits_required > tree.max_hits:
		_fail("Coconut palm hit count is outside its species range")
		return

	player.global_position = tree.global_position + Vector2(0.0, -120.0)
	var hits_before: int = tree.hits_remaining
	scene.inventory.remove_item("stone_axe", 1)
	player.start_attack()
	if tree.hits_remaining != hits_before:
		_fail("Tree could be chopped without a stone axe")
		return
	scene.inventory.add_item("stone_axe", "石斧", 1, 1)
	var tree_position_before: Vector2 = tree.position
	var tree_sprite = tree.get_node("Sprite2D")
	var tree_anchor_before: Vector2 = tree_sprite.get_trunk_anchor_position()
	tree.chop(scene.inventory, scene.skill_tree, Vector2.RIGHT)
	tree._process(0.04)
	if tree_sprite.rotation <= 0.0 or tree.position != tree_position_before:
		_fail("Tree did not bend away from the incoming hit while keeping its root fixed")
		return
	if tree_sprite.get_trunk_anchor_position().distance_to(tree_anchor_before) > 0.05:
		_fail("Tree hit reaction detached the trunk base from its ground anchor")
		return
	for _reaction_step: int in range(180):
		tree._process(1.0 / 60.0)
	if absf(tree_sprite.rotation) > 0.001:
		_fail("Tree hit reaction did not settle back to its resting pose")
		return

	for _hit: int in range(tree.hits_remaining):
		player._cancel_attack()
		player.start_attack()
	if not tree.is_felled or tree.visible or tree.last_drop_amount < tree.min_drop or tree.last_drop_amount > tree.max_drop:
		_fail("Coconut palm did not fall with a random valid wood yield")
		return
	tree.update_game_time(11, 6, 59)
	if not tree.is_felled:
		_fail("Coconut palm respawned before ten complete game days")
		return
	tree.update_game_time(11, 7, 0)
	await physics_frame
	var tree_collision := tree.get_node("Blocker/CollisionShape2D") as CollisionShape2D
	if tree.is_felled or not tree.visible or tree.position != tree_position_before or tree_collision.disabled or tree.hits_remaining < tree.min_hits or tree.hits_remaining > tree.max_hits:
		_fail("Coconut palm did not respawn at its original position after ten game days")
		return

	var drops := get_nodes_in_group("dropped_item")
	if drops.size() != 1:
		_fail("Felled tree did not create one collectible wood pile")
		return
	var drop = drops[0]
	var expected_amount: int = drop.amount
	var wood_before: int = scene.inventory.get_item_count("wood_palm")
	player.global_position = drop.global_position
	if not scene._try_interact():
		_fail("F did not collect the dropped wood pile")
		return
	await process_frame
	if scene.inventory.get_item_count("wood_palm") != wood_before + expected_amount or not get_nodes_in_group("dropped_item").is_empty():
		_fail("Collected wood did not update inventory quantity or clear the drop")
		return

	print("TREE_HARVEST_OK: axe-gated chopping, random yield and manual pickup")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
