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
uniform float shallow_opacity : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float deep_opacity : hint_range(0.0, 1.0, 0.01) = 0.84;
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
	vec2 flow_offset = direction * TIME * flow_speed;
	float broad_noise = smooth_noise((world_position + flow_offset * 0.35) * 0.0065);
	float detail_noise = smooth_noise((world_position + flow_offset + vec2(137.0, -83.0)) * 0.018);
	float cross_noise = smooth_noise((world_position * vec2(0.82, 1.18) - flow_offset * 0.62 + vec2(-211.0, 149.0)) * 0.029);

	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float chunk_edge_fade = smoothstep(0.0, 0.006, edge_distance);
	float active_distortion = distortion_pixels * mix(1.0, 1.65, weather_strength);
	vec2 distortion_field = vec2(detail_noise - 0.5, cross_noise - 0.5);
	distortion_field += direction * (broad_noise - 0.5) * 0.45;
	vec2 distortion = distortion_field * texel * active_distortion * chunk_edge_fade;
	vec3 source = texture(TEXTURE, clamp(UV + distortion, vec2(0.0), vec2(1.0))).rgb;

	float depth = texture(water_depth, UV).r;
	float shoreline = mask * (1.0 - smoothstep(0.015, 0.18, depth));
	float shallow_water = mask * (1.0 - smoothstep(0.04, 0.56, depth));
	float deep_water = smoothstep(0.24, 0.82, depth);
	float foam_noise = smooth_noise((world_position + flow_offset * 0.28 + vec2(31.0, -17.0)) * 0.024);
	float foam_breakup = smoothstep(0.36, 0.72, foam_noise + detail_noise * 0.24);
	float foam_pulse = 0.58 + 0.42 * sin(TIME * 1.1 + broad_noise * 5.8 + depth * 28.0);
	float shoreline_foam = shoreline * mix(0.28, 1.0, foam_breakup) * foam_pulse;
	float inner_foam_band = smoothstep(0.055, 0.11, depth) * (1.0 - smoothstep(0.11, 0.25, depth));
	inner_foam_band *= smoothstep(0.54, 0.78, foam_noise) * (0.56 + 0.44 * sin(TIME * 0.82 + cross_noise * 6.2));

	float caustic_field = detail_noise * 0.62 + cross_noise * 0.38;
	float organic_caustics = smoothstep(0.93, 0.985, 1.0 - abs(caustic_field * 2.0 - 1.0));
	organic_caustics *= shallow_water;
	float reflection_field = broad_noise * 0.64 + smooth_noise((world_position - flow_offset * 0.18 + vec2(83.0, 219.0)) * 0.0042) * 0.36;
	float broad_reflection = smoothstep(0.49, 0.77, reflection_field);
	float surface_glint = smoothstep(0.70, 0.88, detail_noise * 0.42 + broad_noise * 0.58) * deep_water;
	float rain_rings = 0.0;
	if (weather_strength > 0.001) {
		rain_rings = rain_ring(world_position, 74.0, 0.82, vec2(0.0));
		rain_rings += rain_ring(world_position, 108.0, 0.57, vec2(3.7, 5.1)) * 0.65;
		rain_rings *= weather_strength;
	}

	vec3 color = mix(source, water_tint.rgb, tint_strength * mix(0.35, 1.0, deep_water));
	color = mix(color, shallow_tint.rgb, shallow_water * shallow_strength * 0.72);
	float reflection_amount = broad_reflection * mix(0.18, 1.0, deep_water) * reflection_strength * mix(1.0, 0.72, weather_strength);
	color = mix(color, reflection_tint.rgb, reflection_amount);
	float visible_highlight = organic_caustics * 0.72 + surface_glint * 0.26;
	color += vec3(0.62, 0.92, 0.96) * visible_highlight * highlight_strength * mix(1.0, 0.55, weather_strength);
	color += vec3(0.68, 0.91, 0.95) * rain_rings * 0.075;
	float foam = clamp(shoreline_foam + inner_foam_band * 0.55, 0.0, 1.0);
	color = mix(color, vec3(0.86, 0.98, 1.0), foam * shoreline_strength);
	float surface_opacity = mix(shallow_opacity, deep_opacity, smoothstep(0.10, 0.72, depth));
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), mask * surface_opacity);
}
