extends SceneTree

const CATALOG_PATH := "res://art/art_catalog.tres"
const MANIFEST_PATH := "res://assets/maps/spawn/spawn_map.json"
const SKIPPED_DIRECTORIES := [".git", ".godot", "art", "assets", "tests"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog := ResourceLoader.load(CATALOG_PATH) as ArtCatalog
	if catalog == null:
		_fail("Art catalog could not be loaded")
		return

	var referenced := {}
	_collect_source_paths("res://", referenced)
	_collect_manifest_paths(referenced)
	for path: String in referenced:
		if not catalog.has_entry(path):
			_fail("Runtime art is missing from the catalog: " + path)
			return

	var catalog_paths := catalog.all_paths()
	for path: String in catalog_paths:
		if not referenced.has(path):
			_fail("Catalog contains unused or intermediate art: " + path)
			return
		if not ResourceLoader.exists(path):
			_fail("Catalog art does not exist: " + path)
			return
		if "_source" in path or "/raw/" in path:
			_fail("Catalog contains a source or raw intermediate file: " + path)
			return

	if catalog_paths.size() != referenced.size():
		_fail("Catalog and runtime art counts differ: %d vs %d" % [catalog_paths.size(), referenced.size()])
		return

	var texture_path := "res://assets/characters/player_male.png"
	var texture_replacement := ResourceLoader.load("res://assets/items/stone_axe/icon.png") as Texture2D
	catalog.characters[texture_path] = texture_replacement
	var audio_path := "res://assets/weather/storm/thunder_rumble.wav"
	var audio_replacement := ResourceLoader.load("res://assets/weather/rain/rain_wash.wav") as AudioStream
	catalog.audio[audio_path] = audio_replacement
	var shader_path := "res://shaders/night_vision.gdshader"
	var shader_replacement := ResourceLoader.load("res://shaders/river_surface.gdshader") as Shader
	catalog.shaders[shader_path] = shader_replacement
	ArtAssets._catalog = catalog
	if ArtAssets.texture(texture_path) != texture_replacement or ArtAssets.audio(audio_path) != audio_replacement or ArtAssets.shader(shader_path) != shader_replacement:
		_fail("Runtime art resolver ignored a catalog replacement")
		return
	ArtAssets.reload_catalog()

	print("ART_CATALOG_OK: %d runtime art resources are editable" % catalog_paths.size())
	quit()


func _collect_source_paths(directory_path: String, paths: Dictionary) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_fail("Cannot scan project directory: " + directory_path)
		return
	var regex := RegEx.new()
	regex.compile("res://[A-Za-z0-9_./-]+\\.(png|jpg|jpeg|webp|svg|wav|ogg|mp3|gdshader)")
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child_path := directory_path.path_join(name)
		if directory.current_is_dir():
			if name not in SKIPPED_DIRECTORIES:
				_collect_source_paths(child_path, paths)
		elif name.get_extension() in ["gd", "tscn", "tres"]:
			var contents := FileAccess.get_file_as_string(child_path)
			for result: RegExMatch in regex.search_all(contents):
				paths[result.get_string()] = true
		name = directory.get_next()
	directory.list_dir_end()


func _collect_manifest_paths(paths: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Spawn map manifest is invalid")
		return
	_collect_images(parsed, paths)


func _collect_images(value: Variant, paths: Dictionary) -> void:
	if value is Dictionary:
		for key: String in ["image", "depth"]:
			if value.has(key):
				paths[ArtCatalog.normalize_path(String(value[key]))] = true
		for child: Variant in value.values():
			_collect_images(child, paths)
	elif value is Array:
		for child: Variant in value:
			_collect_images(child, paths)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
