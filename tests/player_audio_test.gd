extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("World/DepthSorted/Player")
	var weather = scene.get_node("Weather/Effect")
	var footstep := scene.get_node("Weather/WetFootstep") as AudioStreamPlayer

	for audio: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
		var audio_name := String(audio.name).to_lower()
		if "attack" in audio_name or "punch" in audio_name:
			_fail("Attack audio is still present")
			return
	if footstep.max_polyphony < 2:
		_fail("Footsteps restart the same voice instead of overlapping naturally")
		return

	weather.start_weather_event("下雨", "半天", "中雨")
	weather.advance_visual_seconds(weather.rain_fade_seconds)
	player._set_movement_state(player.STATE_WALK)
	var before_walk: int = scene.get_rain_step_play_count()
	scene._last_puddle_step_position = player.global_position - Vector2(90.0, 0.0)
	scene._update_rain_step_audio()
	if scene.get_rain_step_play_count() != before_walk + 1:
		_fail("Walking did not produce a paced wet footstep")
		return

	player._set_movement_state(player.STATE_ATTACK)
	var before_attack: int = scene.get_rain_step_play_count()
	scene._last_puddle_step_position = player.global_position - Vector2(120.0, 0.0)
	scene._update_rain_step_audio()
	if scene.get_rain_step_play_count() != before_attack:
		_fail("Attack state leaked a movement footstep sound")
		return

	print("PLAYER_AUDIO_OK: no attack audio and paced overlapping footsteps")
	scene.free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
