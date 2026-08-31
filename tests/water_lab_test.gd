extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://water_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var previews := get_nodes_in_group("water_comparison_preview")
	if previews.size() != 3:
		_fail("Water comparison scene did not build all three presets")
		return
	var presets: Array[int] = []
	for preview: TextureRect in previews:
		var material := preview.material as ShaderMaterial
		if material == null or material.shader == null or material.get_shader_parameter("water_mask") == null:
			_fail("A water comparison preset is missing its shader or mask")
			return
		presets.append(int(preview.get_meta("preset", -1)))
	presets.sort()
	if presets != [0, 1, 2]:
		_fail("Water comparison presets are not independently configured")
		return
	print("WATER_LAB_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
