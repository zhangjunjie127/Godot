extends SceneTree


func _initialize() -> void:
	var shader := load("res://shaders/river_surface.gdshader") as Shader
	if shader == null:
		_fail("River surface shader could not be loaded")
		return
	if "render_mode unshaded" in shader.code:
		_fail("River surface bypasses CanvasModulate and will be over-brightened by night vision")
		return
	if "reflection_strength" not in shader.code or "broad_reflection" not in shader.code:
		_fail("River surface is missing smooth environment reflection")
		return
	if "thread_a" in shader.code or "thread_b" in shader.code or "caustic_web" in shader.code:
		_fail("River surface still contains the artificial cross-grid pattern")
		return
	if "organic_caustics" not in shader.code or "shallow_opacity" not in shader.code or "deep_opacity" not in shader.code:
		_fail("River surface is missing depth-aware transparent water")
		return
	if "traveling_wave" not in shader.code or "wave_strength" not in shader.code:
		_fail("River surface is missing traveling wave bands")
		return
	if "shoreline_mask" not in shader.code or "inner_shore_foam" not in shader.code or "outer_shore_foam" not in shader.code:
		_fail("River surface is missing the animated two-layer shoreline replacement")
		return
	if "baked_edge_cover" not in shader.code or "shore_foam_strength" not in shader.code:
		_fail("River surface is missing shoreline cover controls")
		return
	var underwater_shader := load("res://shaders/underwater_current.gdshader") as Shader
	if underwater_shader == null or "underwater_flow" not in underwater_shader.code or "caustic_line" not in underwater_shader.code:
		_fail("Underwater current distortion is missing")
		return
	var atmosphere := load("res://shaders/outdoor_ambient_fill.gdshader") as Shader
	if atmosphere == null or "filter_nearest" in atmosphere.code:
		_fail("Outdoor reflection and glow are not using continuous sampling")
		return
	print("WATER_NIGHT_LIGHTING_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
