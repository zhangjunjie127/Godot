@tool
extends RefCounted
class_name ArtAssets

const CATALOG_PATH := "res://art/art_catalog.tres"

static var _catalog: ArtCatalog


static func texture(path: String, fallback: Texture2D = null) -> Texture2D:
	var normalized := ArtCatalog.normalize_path(path)
	var catalog := _get_catalog()
	if catalog != null:
		var replacement := catalog.texture(normalized)
		if replacement != null:
			return replacement
	if fallback != null:
		return fallback
	var loaded := ResourceLoader.load(normalized)
	if loaded is Texture2D:
		return loaded as Texture2D
	push_error("Missing art texture: " + normalized)
	return null


static func reload_catalog() -> void:
	_catalog = null


static func _get_catalog() -> ArtCatalog:
	if Engine.is_editor_hint():
		return ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ArtCatalog
	if _catalog == null:
		_catalog = ResourceLoader.load(CATALOG_PATH) as ArtCatalog
	return _catalog
