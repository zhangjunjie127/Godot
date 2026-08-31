shader_type canvas_item;
render_mode unshaded;

uniform sampler2D water_mask : repeat_disable, filter_linear;
uniform sampler2D water_depth : repeat_disable, filter_linear;
uniform vec2 chunk_world_origin = vec2(0.0);
uniform vec2 chunk_world_size = vec2(2048.0);
uniform vec2 flow_direction = vec2(0.94, 0.34);
uniform float flow_speed : hint_range(0.0, 80.0, 1.0) = 22.0;
uniform float distortion_pixels : hint_range(0.0, 10.0, 0.1) = 4.0;
uniform float tint_strength : hint_range(0.0, 0.4, 0.01) = 0.10;
uniform float shallow_strength : hint_range(0.0, 0.4, 0.01) = 0.14;
uniform float highlight_strength : hint_range(0.0, 0.12, 0.001) = 0.018;
uniform float shoreline_strength : hint_range(0.0, 0.4, 0.01) = 0.10;
uniform float weather_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 water_tint : source_color = vec4(0.02, 0.34, 0.52, 1.0);
uniform vec4 shallow_tint : source_color = vec4(0.08, 0.68, 0.74, 1.0);


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
	float thread = pow(0.5 + 0.5 * sin(
		dot(world_position, direction) * 0.125
		+ dot(world_position, perpendicular) * 0.035
		+ TIME * 1.05
		+ current * 3.0
	), 18.0);

	vec3 color = mix(source, water_tint.rgb, tint_strength);
	color = mix(color, shallow_tint.rgb, shallow_water * shallow_strength);
	color += vec3(0.62, 0.92, 0.96) * thread * current * highlight_strength * mix(1.0, 0.55, weather_strength);
	color = mix(color, vec3(0.86, 0.98, 1.0), shoreline * foam_motion * shoreline_strength);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), mask);
}
