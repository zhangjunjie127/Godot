extends Sprite2D

var swim_bounds := Rect2(120.0, 210.0, 1432.0, 620.0)

var _rng := RandomNumberGenerator.new()
var _direction := 1.0
var _speed := 24.0
var _vertical_speed := 0.0
var _turn_seconds := 0.0
var _animation_seconds := 0.0


func configure(fish_texture: Texture2D, bounds: Rect2, random_seed: int, fish_scale: float) -> void:
	texture = fish_texture
	hframes = 2
	vframes = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * fish_scale
	swim_bounds = bounds
	_rng.seed = random_seed
	_direction = -1.0 if _rng.randf() < 0.5 else 1.0
	_pick_motion()
	add_to_group("underwater_fish")


func _process(delta: float) -> void:
	_animation_seconds += delta
	frame = floori(_animation_seconds / 0.18) % 4
	_turn_seconds -= delta
	if _turn_seconds <= 0.0:
		_pick_motion()

	position += Vector2(_direction * _speed, _vertical_speed) * delta
	if position.x <= swim_bounds.position.x or position.x >= swim_bounds.end.x:
		_direction *= -1.0
		position.x = clampf(position.x, swim_bounds.position.x, swim_bounds.end.x)
	if position.y <= swim_bounds.position.y or position.y >= swim_bounds.end.y:
		_vertical_speed *= -1.0
		position.y = clampf(position.y, swim_bounds.position.y, swim_bounds.end.y)
	flip_h = _direction < 0.0
	rotation = clampf(_vertical_speed / 120.0, -0.08, 0.08)


func _pick_motion() -> void:
	_speed = _rng.randf_range(18.0, 27.0)
	_vertical_speed = _rng.randf_range(-7.0, 7.0)
	_turn_seconds = _rng.randf_range(2.2, 5.0)
	if _rng.randf() < 0.22:
		_direction *= -1.0
