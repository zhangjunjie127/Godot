extends Control

const FAR_PARTICLE_COUNT := 360
const NEAR_PARTICLE_COUNT := 160

@export var random_seed := 20260828
@export var far_particles_path: NodePath
@export var near_particles_path: NodePath
@export var audio_player_path: NodePath
@export var streak_shader: Shader
@export_range(-0.45, -0.04, 0.01) var base_wind_x := -0.16
@export_range(0.0, 0.18, 0.01) var gust_variation := 0.055
@export_range(0.2, 4.0, 0.1) var gust_response := 0.85
@export_range(1.5, 9.0, 0.1) var gust_interval_min := 3.4
@export_range(1.5, 12.0, 0.1) var gust_interval_max := 6.8
@export_range(200.0, 900.0, 10.0) var far_speed_min := 430.0
@export_range(200.0, 1000.0, 10.0) var far_speed_max := 590.0
@export_range(300.0, 1200.0, 10.0) var near_speed_min := 620.0
@export_range(300.0, 1400.0, 10.0) var near_speed_max := 820.0
@export_range(0.0, 0.12, 0.005) var haze_max_alpha := 0.045
@export_range(-40.0, 0.0, 0.5) var rain_loop_max_volume_db := -8.0

var intensity := 0.0
var _far_particles: GPUParticles2D
var _near_particles: GPUParticles2D
var _rain_loop: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _wind_current := -0.16
var _wind_target := -0.16
var _gust_elapsed := 0.0
var _gust_duration := 4.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = random_seed
	_far_particles = get_node_or_null(far_particles_path) as GPUParticles2D
	_near_particles = get_node_or_null(near_particles_path) as GPUParticles2D
	_rain_loop = get_node_or_null(audio_player_path) as AudioStreamPlayer
	_wind_current = base_wind_x
	_wind_target = base_wind_x
	_configure_layer(
		_far_particles,
		FAR_PARTICLE_COUNT,
		0.86,
		far_speed_min,
		far_speed_max,
		Vector2(3.0, 11.0),
		Color(0.60, 0.75, 0.84, 0.23),
		0.09
	)
	_configure_layer(
		_near_particles,
		NEAR_PARTICLE_COUNT,
		0.68,
		near_speed_min,
		near_speed_max,
		Vector2(4.0, 16.0),
		Color(0.74, 0.88, 0.94, 0.38),
		0.11
	)
	_setup_audio_loop()
	resized.connect(_update_viewport_coverage)
	_update_viewport_coverage()
	_choose_next_gust()
	_sync_layers()
	set_process(false)


func _exit_tree() -> void:
	if _rain_loop != null:
		_rain_loop.stop()
		_rain_loop.stream = null


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	visible = intensity > 0.001
	_sync_layers()
	_sync_audio()
	queue_redraw()


func advance_effects(seconds: float) -> void:
	var delta := maxf(seconds, 0.0)
	if delta > 0.0:
		_advance_wind(delta)
	_sync_audio()
	queue_redraw()


func get_active_particle_count() -> int:
	var far_count := roundi(float(FAR_PARTICLE_COUNT) * pow(intensity, 1.25))
	var near_count := roundi(float(NEAR_PARTICLE_COUNT) * pow(intensity, 1.75))
	return far_count + near_count


func get_layer_particle_counts() -> Vector2i:
	return Vector2i(FAR_PARTICLE_COUNT, NEAR_PARTICLE_COUNT)


func get_wind_vector() -> Vector2:
	return Vector2(_wind_current, 1.0).normalized()


func get_audio_volume_db() -> float:
	return _rain_loop.volume_db if _rain_loop != null else -80.0


func is_audio_playing() -> bool:
	return _rain_loop != null and _rain_loop.playing


func _configure_layer(
	particles: GPUParticles2D,
	particle_count: int,
	lifetime: float,
	speed_min: float,
	speed_max: float,
	streak_size: Vector2,
	streak_color: Color,
	width: float
) -> void:
	if particles == null:
		return
	particles.amount = particle_count
	particles.lifetime = lifetime
	particles.randomness = 0.38
	particles.preprocess = lifetime * 0.65
	particles.local_coords = true
	particles.interpolate = true
	particles.emitting = false

	var process_material := ParticleProcessMaterial.new()
	process_material.particle_flag_align_y = true
	process_material.direction = Vector3(get_wind_vector().x, get_wind_vector().y, 0.0)
	process_material.spread = 6.0
	process_material.initial_velocity_min = speed_min
	process_material.initial_velocity_max = speed_max
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.78
	process_material.scale_max = 1.22
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particles.process_material = process_material

	var shader_material := ShaderMaterial.new()
	shader_material.shader = streak_shader
	shader_material.set_shader_parameter("streak_color", streak_color)
	shader_material.set_shader_parameter("width", width)
	shader_material.set_shader_parameter("edge_softness", 0.085)
	var image := Image.create_empty(maxi(2, roundi(streak_size.x)), maxi(4, roundi(streak_size.y)), false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(image)
	particles.material = shader_material


func _update_viewport_coverage() -> void:
	var viewport_size := _effect_size()
	for particles: GPUParticles2D in [_far_particles, _near_particles]:
		if particles == null:
			continue
		particles.position = Vector2(viewport_size.x * 0.5, -42.0)
		particles.visibility_rect = Rect2(
			Vector2(-viewport_size.x * 0.75, -72.0),
			Vector2(viewport_size.x * 1.5, viewport_size.y + 190.0)
		)
		var process_material := particles.process_material as ParticleProcessMaterial
		if process_material != null:
			process_material.emission_box_extents = Vector3(viewport_size.x * 0.68, 10.0, 0.0)


func _advance_wind(delta: float) -> void:
	_gust_elapsed += delta
	if _gust_elapsed >= _gust_duration:
		_choose_next_gust()
	var blend := 1.0 - exp(-gust_response * delta)
	_wind_current = lerpf(_wind_current, _wind_target, blend)
	var direction := get_wind_vector()
	for particles: GPUParticles2D in [_far_particles, _near_particles]:
		if particles == null:
			continue
		var process_material := particles.process_material as ParticleProcessMaterial
		if process_material != null:
			process_material.direction = Vector3(direction.x, direction.y, 0.0)


func _choose_next_gust() -> void:
	_gust_elapsed = 0.0
	_gust_duration = _rng.randf_range(gust_interval_min, gust_interval_max)
	_wind_target = clampf(base_wind_x + _rng.randf_range(-gust_variation, gust_variation), -0.48, -0.02)


func _sync_layers() -> void:
	if _far_particles != null:
		_far_particles.amount_ratio = pow(intensity, 1.25)
		_far_particles.emitting = intensity > 0.001
	if _near_particles != null:
		_near_particles.amount_ratio = pow(intensity, 1.75)
		_near_particles.emitting = intensity > 0.025


func _draw() -> void:
	if intensity <= 0.001:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.095, 0.12, haze_max_alpha * intensity))


func _effect_size() -> Vector2:
	return Vector2(maxf(size.x, 640.0), maxf(size.y, 360.0))


func _setup_audio_loop() -> void:
	if _rain_loop == null or not (_rain_loop.stream is AudioStreamWAV):
		return
	var loop_stream := _rain_loop.stream as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = roundi(loop_stream.get_length() * float(loop_stream.mix_rate))


func _sync_audio() -> void:
	if _rain_loop == null:
		return
	if intensity > 0.001 and is_visible_in_tree():
		_rain_loop.volume_db = lerpf(-44.0, rain_loop_max_volume_db, sqrt(intensity))
		if DisplayServer.get_name() != "headless" and not _rain_loop.playing:
			_rain_loop.play()
	elif _rain_loop.playing:
		_rain_loop.stop()
