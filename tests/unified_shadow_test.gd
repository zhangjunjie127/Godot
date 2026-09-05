extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame

	var player_shadow = scene.get_node("World/DepthSorted/Player/GroundShadow")
	var boar_shadow = scene.get_node("World/DepthSorted/WildBoar/GroundShadow")
	if player_shadow.material == null or player_shadow.material != boar_shadow.material:
		_fail("Player and wild boar do not share the canonical ground-shadow material")
		return
	if player_shadow.material.shader.resource_path != "res://shaders/ordered_shadow.gdshader":
		_fail("Actor ground shadows are not using the ordered shadow shader")
		return

	var tall_prop := _find_art_sprite(scene, "/trees/")
	var low_prop := _find_art_sprite(scene, "/grasses/")
	if tall_prop == null or not tall_prop.has_node("GroundShadow"):
		_fail("Tall vegetation did not receive an editable ground projection")
		return
	var prop_shadow := tall_prop.get_node("GroundShadow") as Sprite2D
	if not prop_shadow.visible or prop_shadow.material != player_shadow.material:
		_fail("Tall vegetation does not share the canonical ground-shadow material")
		return
	var frame_size := tall_prop.texture.get_size()
	var opaque_bounds := tall_prop.texture.get_image().get_used_rect()
	var expected_local_anchor := tall_prop.offset + Vector2(
		opaque_bounds.position.x + opaque_bounds.size.x * 0.5,
		opaque_bounds.end.y
	) - frame_size * 0.5
	var local_anchor: Vector2 = tall_prop.transform.affine_inverse() * tall_prop.get_trunk_anchor_position()
	if local_anchor.distance_to(expected_local_anchor) > 0.1:
		_fail("Vegetation shadows are not anchored to the visible trunk base")
		return
	if prop_shadow.to_global(local_anchor).distance_to(tall_prop.to_global(local_anchor)) > 0.1:
		_fail("Vegetation shadow is separated from the trunk base")
		return
	if tall_prop.ground_shadow_local_offset != scene.vegetation_shadow_local_offset \
		or tall_prop.ground_shadow_scale != scene.vegetation_shadow_scale \
		or not is_equal_approx(tall_prop.ground_shadow_strength, scene.vegetation_shadow_strength):
		_fail("Vegetation did not receive the global shadow shape profile")
		return
	if not scene.vegetation_contact_shadow_enabled or not tall_prop.ground_contact_shadow_enabled:
		_fail("Vegetation root-contact shadows are not enabled globally")
		return
	if not tall_prop.has_node("GroundContactShadow") or not tall_prop.get_node("GroundContactShadow").visible:
		_fail("Vegetation root contact shadow is not bridging the projected shadow")
		return
	var cast_direction: Vector2 = tall_prop.get_ground_shadow_cast_direction()
	if cast_direction.x >= -0.6 or cast_direction.y <= 0.6:
		_fail("Top-right sunlight did not cast vegetation shadows toward the bottom-left")
		return
	if not is_equal_approx(tall_prop.ground_shadow_direction_degrees, scene.vegetation_shadow_direction_degrees):
		_fail("Vegetation shadow direction is not synchronized with the global sun direction")
		return
	if low_prop == null or not low_prop.has_node("GroundShadow"):
		_fail("Low vegetation did not receive the unified directional shadow")
		return

	var vegetation_sprites: Array[Sprite2D] = []
	_collect_art_sprites(scene, vegetation_sprites)
	if vegetation_sprites.size() < 170:
		_fail("Not all vegetation assets were discovered: %d" % vegetation_sprites.size())
		return
	var sampled_collision: CollisionShape2D
	for sprite: Sprite2D in vegetation_sprites:
		if not sprite.has_node("GroundShadow"):
			_fail("Vegetation is missing its unified shadow: " + sprite.texture.resource_path)
			return
		var manual_blocker := sprite.get_parent().get_node_or_null("Blocker") as StaticBody2D
		var generated_blocker := sprite.get_node_or_null("VegetationBlocker") as StaticBody2D
		var blocker := manual_blocker if manual_blocker != null else generated_blocker
		if blocker == null or blocker.collision_layer != 2:
			_fail("Vegetation is missing its root blocker: " + sprite.texture.resource_path)
			return
		var collision := blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.disabled or not collision.shape is CircleShape2D:
			_fail("Vegetation root blocker is not an active circle: " + sprite.texture.resource_path)
			return
		if generated_blocker != null and sampled_collision == null:
			sampled_collision = collision
	if sampled_collision == null:
		_fail("No generated vegetation blocker was available for physics validation")
		return
	await physics_frame
	var root_query := PhysicsPointQueryParameters2D.new()
	root_query.position = sampled_collision.global_position
	root_query.collision_mask = 2
	if scene.get_world_2d().direct_space_state.intersect_point(root_query).is_empty():
		_fail("Generated vegetation root blocker is not registered in physics")
		return

	var player = scene.get_node("World/DepthSorted/Player")
	player.set_surface_swimming(true)
	if player_shadow.visible:
		_fail("Player ground shadow remained visible while surface swimming")
		return
	player.set_surface_swimming(false)
	if not player_shadow.visible:
		_fail("Player ground shadow did not return on land")
		return

	print("UNIFIED_SHADOW_OK")
	scene.free()
	await process_frame
	quit()


func _find_art_sprite(node: Node, path_fragment: String) -> Sprite2D:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and path_fragment in sprite.texture.resource_path and sprite.get_script() != null:
			return sprite
	for child: Node in node.get_children():
		var found := _find_art_sprite(child, path_fragment)
		if found != null:
			return found
	return null


func _collect_art_sprites(node: Node, result: Array[Sprite2D]) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null and "/vegetation/" in sprite.texture.resource_path and sprite.get_script() != null:
			result.append(sprite)
	for child: Node in node.get_children():
		_collect_art_sprites(child, result)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
