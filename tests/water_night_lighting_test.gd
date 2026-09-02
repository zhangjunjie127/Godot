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
	var atmosphere := load("res://shaders/outdoor_ambient_fill.gdshader") as Shader
	if atmosphere == null or "filter_nearest" in atmosphere.code:
		_fail("Outdoor reflection and glow are not using continuous sampling")
		return
	print("WATER_NIGHT_LIGHTING_OK")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
