shader_type canvas_item;

instance uniform float wind_time = 0.0;
instance uniform float wind_phase = 0.0;
instance uniform float wind_strength = 0.4;
instance uniform float trunk_amplitude_pixels = 1.2;
instance uniform float leaf_amplitude_pixels = 4.0;
instance uniform float trunk_speed = 0.6;
instance uniform float leaf_speed = 1.4;
instance uniform float root_lock_height : hint_range(0.0, 0.35, 0.01) = 0.1;
instance uniform float canopy_start_height : hint_range(0.0, 0.85, 0.01) = 0.4;

varying vec4 vertex_modulate;


void vertex() {
	vertex_modulate = COLOR;
}


void fragment() {
	float height = 1.0 - UV.y;
	float trunk_weight = smoothstep(root_lock_height, min(root_lock_height + 0.38, 0.98), height);
	float canopy_weight = smoothstep(canopy_start_height, min(canopy_start_height + 0.24, 1.0), height);
	float trunk_wave = sin(wind_time * trunk_speed + wind_phase)
		+ sin(wind_time * trunk_speed * 0.43 + wind_phase * 1.63) * 0.22;
	float leaf_wave = sin(wind_time * leaf_speed + wind_phase * 1.37 + height * 2.4)
		+ sin(wind_time * leaf_speed * 2.15 + wind_phase * 0.71 + UV.x * 5.0) * 0.24;
	float horizontal_pixels = (
		trunk_wave * trunk_amplitude_pixels * trunk_weight
		+ leaf_wave * leaf_amplitude_pixels * canopy_weight
	) * wind_strength;
	float vertical_pixels = cos(wind_time * leaf_speed * 1.31 + wind_phase + UV.x * 3.0)
		* leaf_amplitude_pixels * 0.14 * canopy_weight * wind_strength;
	vec2 displaced_uv = UV - vec2(horizontal_pixels, vertical_pixels) * TEXTURE_PIXEL_SIZE;
	if (displaced_uv.x < 0.0 || displaced_uv.x > 1.0 || displaced_uv.y < 0.0 || displaced_uv.y > 1.0) {
		discard;
	}
	COLOR = texture(TEXTURE, displaced_uv) * vertex_modulate;
}
