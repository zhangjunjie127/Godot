shader_type canvas_item;

uniform sampler2D water_mask : repeat_disable, filter_linear;
uniform sampler2D water_depth : repeat_disable, filter_linear;
uniform vec2 chunk_world_origin = vec2(0.0);
uniform vec2 chunk_world_size = vec2(2048.0);
uniform vec2 flow_direction = vec2(0.94, 0.34);
uniform float flow_speed : hint_range(0.0, 80.0, 1.0) = 28.0;
uniform float distortion_pixels : hint_range(0.0, 10.0, 0.1) = 5.5;
uniform float tint_strength : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float shallow_strength : hint_range(0.0, 0.4, 0.01) = 0.22;
uniform float highlight_strength : hint_range(0.0, 0.12, 0.001) = 0.045;
uniform float reflection_strength : hint_range(0.0, 0.2, 0.005) = 0.07;
uniform float shoreline_strength : hint_range(0.0, 0.4, 0.01) = 0.18;
uniform float weather_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 water_tint : source_color = vec4(0.02, 0.34, 0.52, 1.0);
uniform vec4 shallow_tint : source_color = vec4(0.08, 0.68, 0.74, 1.0);
uniform vec4 reflection_tint : source_color = vec4(0.66, 0.84, 0.90, 1.0);


float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}


float smooth_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local = fract(position);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), local.x),
		local.y
	);
}


float rain_ring(vec2 world_position, float cell_size, float speed, vec2 offset) {
	vec2 cell_position = world_position / cell_size + offset;
	vec2 cell = floor(cell_position);
	vec2 local = fract(cell_position);
	float seed = hash21(cell + offset * 17.0);
	vec2 center = vec2(
		hash21(cell + vec2(2.7, 8.1)),
		hash21(cell + vec2(6.3, 1.9))
	) * 0.68 + 0.16;
	float age = fract(TIME * speed + seed);
	float distance_to_center = length((local - center) * vec2(1.0, 1.75));
	float radius = age * 0.34;
	float ring = 1.0 - smoothstep(0.018, 0.055, abs(distance_to_center - radius));
	return ring * smoothstep(0.02, 0.16, age) * pow(1.0 - age, 2.1);
}


void fragment() {
	float mask = texture(water_mask, UV).r;
	if (mask < 0.01) {
		discard;
	}

	vec2 texel = 1.0 / vec2(textureSize(water_mask, 0));
	vec2 world_position = chunk_world_origin + UV * chunk_world_size;
	vec2 direction = normalize(flow_direction);
	vec2 perpendicular = vec2(-direction.y, direction.x);
	vec2 moving_position = world_position + direction * TIME * flow_speed;
	float current = smooth_noise(moving_position * 0.015);
	float wave_a = sin(dot(moving_position, direction) * 0.060 + dot(world_position, perpendicular) * 0.028);
	float wave_b = sin(dot(moving_position, perpendicular) * 0.072 - dot(world_position, direction) * 0.021);

	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float chunk_edge_fade = smoothstep(0.0, 0.006, edge_distance);
	float active_distortion = distortion_pixels * mix(1.0, 1.65, weather_strength);
	vec2 distortion = vec2(wave_a + current - 0.5, wave_b - current + 0.5) * texel * active_distortion * chunk_edge_fade;
	vec3 source = texture(TEXTURE, clamp(UV + distortion, vec2(0.0), vec2(1.0))).rgb;

	float depth = texture(water_depth, UV).r;
	float shoreline = mask * (1.0 - smoothstep(0.01, 0.14, depth));
	float shallow_water = mask * (1.0 - smoothstep(0.04, 0.56, depth));
	float foam_motion = 0.55 + 0.45 * sin(dot(world_position, vec2(0.055, -0.048)) + TIME * 1.7 + current * 4.0);
	float thread_a = abs(sin(
		dot(world_position, direction) * 0.125
		+ dot(world_position, perpendicular) * 0.035
		+ TIME * 1.05
		+ current * 3.0
	));
	float thread_b = abs(sin(
		dot(world_position, perpendicular) * 0.082
		- dot(world_position, direction) * 0.047
		- TIME * 0.78
		+ current * 2.4
	));
	float caustic_web = pow(1.0 - min(thread_a, thread_b), 11.0);
	float surface_glint = pow(0.5 + 0.5 * sin(
		dot(world_position, vec2(0.026, 0.014))
		+ TIME * 0.62
		+ current * 4.0
	), 8.0);
	float reflection_wave = 0.58 * (0.5 + 0.5 * sin(
		dot(world_position, vec2(0.010, -0.007))
		+ TIME * 0.24
		+ current * 1.8
	));
	reflection_wave += 0.42 * (0.5 + 0.5 * sin(
		dot(world_position, vec2(-0.006, 0.012))
		- TIME * 0.17
		+ current * 1.2
	));
	float broad_reflection = smoothstep(0.48, 0.86, reflection_wave);
	float rain_rings = 0.0;
	if (weather_strength > 0.001) {
		rain_rings = rain_ring(world_position, 74.0, 0.82, vec2(0.0));
		rain_rings += rain_ring(world_position, 108.0, 0.57, vec2(3.7, 5.1)) * 0.65;
		rain_rings *= weather_strength;
	}

	vec3 color = mix(source, water_tint.rgb, tint_strength);
	color = mix(color, shallow_tint.rgb, shallow_water * shallow_strength);
	float reflection_amount = broad_reflection * mix(0.35, 1.0, depth) * reflection_strength * mix(1.0, 0.72, weather_strength);
	color = mix(color, reflection_tint.rgb, reflection_amount);
	float visible_highlight = caustic_web * 0.82 + surface_glint * shallow_water * 0.34;
	color += vec3(0.62, 0.92, 0.96) * visible_highlight * highlight_strength * mix(1.0, 0.55, weather_strength);
	color += vec3(0.68, 0.91, 0.95) * rain_rings * 0.075;
	color = mix(color, vec3(0.86, 0.98, 1.0), shoreline * foam_motion * shoreline_strength);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), mask);
}
