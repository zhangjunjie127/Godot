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
	var expected_default_offset := Vector2(50.0, -120.0)
	if (prop_shadow.transform * local_anchor).distance_to(local_anchor + expected_default_offset) > 0.1:
		_fail("Vegetation shadow does not use the copied start offset")
		return
	if tall_prop.ground_shadow_local_offset != scene.vegetation_shadow_local_offset \
		or tall_prop.ground_shadow_scale != scene.vegetation_shadow_scale \
		or not is_equal_approx(tall_prop.ground_shadow_strength, scene.vegetation_shadow_strength):
		_fail("Vegetation did not receive the global shadow shape profile")
		return
	if scene.vegetation_contact_shadow_enabled or tall_prop.ground_contact_shadow_enabled:
		_fail("Vegetation root-contact shadows were not disabled by the copied profile")
		return
	if tall_prop.has_node("GroundContactShadow") and tall_prop.get_node("GroundContactShadow").visible:
		_fail("Disabled vegetation root-contact shadow remains visible")
		return
	var cast_direction: Vector2 = tall_prop.get_ground_shadow_cast_direction()
	var expected_default_direction := Vector2.RIGHT.rotated(deg_to_rad(165.0))
	if cast_direction.distance_to(expected_default_direction) > 0.001:
		_fail("Vegetation did not receive the copied 165-degree shadow direction")
		return
	if not is_equal_approx(tall_prop.ground_shadow_direction_degrees, scene.vegetation_shadow_direction_degrees):
		_fail("Vegetation shadow direction is not synchronized with the global sun direction")
		return
	var property_names := {}
	for property: Dictionary in tall_prop.get_property_list():
		property_names[String(property["name"])] = true
	for property_name: String in [
		"use_individual_ground_shadow",
		"individual_shadow_start_offset",
		"individual_shadow_direction_degrees",
		"individual_shadow_length_scale",
		"individual_shadow_width_scale",
	]:
		if not property_names.has(property_name):
			_fail("Vegetation is missing editable per-tree shadow property: " + property_name)
			return
	if not tall_prop.use_individual_ground_shadow \
		or tall_prop.individual_shadow_start_offset != expected_default_offset \
		or not is_equal_approx(tall_prop.individual_shadow_direction_degrees, 165.0) \
		or not is_equal_approx(tall_prop.individual_shadow_length_scale, 0.8) \
		or not is_equal_approx(tall_prop.individual_shadow_width_scale, 0.9):
		_fail("Vegetation did not receive the copied per-tree shadow profile")
		return
	tall_prop.use_individual_ground_shadow = true
	tall_prop.individual_shadow_start_offset = Vector2(18.0, -11.0)
	tall_prop.individual_shadow_direction_degrees = 125.0
	tall_prop.individual_shadow_length_scale = 1.15
	tall_prop.individual_shadow_width_scale = 0.72
	tall_prop._sync_ground_shadow()
	scene.vegetation_shadow_direction_degrees = -20.0
	scene.vegetation_shadow_local_offset = Vector2(80.0, 80.0)
	scene.vegetation_shadow_scale = Vector2(-0.2, 0.2)
	scene._apply_vegetation_shadow_direction()
	var individual_direction := Vector2.RIGHT.rotated(deg_to_rad(125.0))
	var projected_anchor: Vector2 = prop_shadow.transform * local_anchor
	if tall_prop.get_ground_shadow_cast_direction().distance_to(individual_direction) > 0.001 \
		or prop_shadow.scale != Vector2(-0.72, 1.15) \
		or projected_anchor.distance_to(local_anchor + Vector2(18.0, -11.0)) > 0.1:
		_fail("Per-tree shadow settings were overwritten by the global profile")
		return
	tall_prop.individual_shadow_start_offset = expected_default_offset
	tall_prop.individual_shadow_direction_degrees = 165.0
	tall_prop.individual_shadow_length_scale = 0.8
	tall_prop.individual_shadow_width_scale = 0.9
	tall_prop._sync_ground_shadow()
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
		if not sprite.use_individual_ground_shadow \
			or sprite.individual_shadow_start_offset != expected_default_offset \
			or not is_equal_approx(sprite.individual_shadow_direction_degrees, 165.0) \
			or not is_equal_approx(sprite.individual_shadow_length_scale, 0.8) \
			or not is_equal_approx(sprite.individual_shadow_width_scale, 0.9) \
			or sprite.ground_contact_shadow_enabled:
			_fail("Vegetation is missing the copied shadow profile: " + sprite.texture.resource_path)
			return
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
