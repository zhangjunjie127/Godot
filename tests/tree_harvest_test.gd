extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame

	var player = scene.get_node("World/DepthSorted/Player")
	var tree = scene.get_node("World/DepthSorted/NortheastPalm01")
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

	for _hit: int in range(tree.hits_required):
		player._cancel_attack()
		player.start_attack()
	if not tree.is_felled or tree.visible or tree.last_drop_amount < tree.min_drop or tree.last_drop_amount > tree.max_drop:
		_fail("Coconut palm did not fall with a random valid wood yield")
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
