extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene := (load("res://water_lab.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for _frame: int in range(20):
		await process_frame
	var first_path := OS.get_temp_dir().path_join("water_lab_before.png")
	var second_path := OS.get_temp_dir().path_join("water_lab_after.png")
	root.get_viewport().get_texture().get_image().save_png(first_path)
	await create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(second_path)
	print("WATER_LAB_CAPTURED:%s|%s" % [first_path, second_path])
	quit()
