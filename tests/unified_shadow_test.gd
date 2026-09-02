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
	if low_prop == null or low_prop.has_node("GroundShadow"):
		_fail("Low groundcover received an unnecessary directional shadow")
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
