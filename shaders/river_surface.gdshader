shader_type canvas_item;

uniform sampler2D water_mask : repeat_disable, filter_linear;
uniform sampler2D water_depth : repeat_disable, filter_linear;
uniform sampler2D shoreline_mask : repeat_disable, filter_linear;
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
uniform float baked_edge_cover : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float shore_foam_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float wave_strength : hint_range(0.0, 0.25, 0.005) = 0.10;
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
	vec3 shoreline_data = texture(shoreline_mask, UV).rgb;
	float baked_edge = shoreline_data.r;
	float shore_field = shoreline_data.g;
	float outer_shore_field = shoreline_data.b;
	if (max(mask, shore_field) < 0.01) {
		discard;
	}

	vec2 texel = 1.0 / vec2(textureSize(water_mask, 0));
	vec2 world_position = chunk_world_origin + UV * chunk_world_size;
	vec2 direction = normalize(flow_direction);
	vec2 perpendicular = vec2(-direction.y, direction.x);
	vec2 flow_offset = direction * TIME * flow_speed;
	float depth = texture(water_depth, UV).r;
	float motion_depth = smoothstep(0.08, 0.68, depth);
	float broad_noise = smooth_noise((world_position + flow_offset * 0.35) * 0.0065);
	float detail_noise = smooth_noise((world_position + flow_offset * 1.12 + vec2(137.0, -83.0)) * 0.018);
	float cross_noise = smooth_noise((world_position * vec2(0.82, 1.18) - flow_offset * 0.72 + vec2(-211.0, 149.0)) * 0.029);
	vec2 wave_direction = normalize(direction + perpendicular * 0.20);
	vec2 secondary_wave_direction = normalize(direction + perpendicular * 0.28);
	float wave_phase_a = dot(world_position, wave_direction) * 0.018 - TIME * 1.02 + broad_noise * 2.4;
	float wave_phase_b = dot(world_position, secondary_wave_direction) * 0.031 - TIME * 0.76 + cross_noise * 1.8;
	float wave_a = smoothstep(0.64, 0.96, 0.5 + 0.5 * sin(wave_phase_a));
	float wave_b = smoothstep(0.78, 0.985, 0.5 + 0.5 * sin(wave_phase_b));
	float wave_breakup = 0.38 + 0.62 * smooth_noise((world_position + flow_offset * 0.18 + vec2(47.0, 91.0)) * 0.011);
	float traveling_wave = (wave_a * 0.64 + wave_b * 0.36) * wave_breakup * motion_depth;

	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float chunk_edge_fade = smoothstep(0.0, 0.006, edge_distance);
	float active_distortion = distortion_pixels * mix(0.16, 1.0, motion_depth) * mix(1.0, 1.42, weather_strength);
	vec2 distortion_field = vec2(detail_noise - 0.5, cross_noise - 0.5);
	distortion_field += direction * (broad_noise - 0.5) * 0.45;
	float wave_displacement = sin(wave_phase_a) * 0.64 + sin(wave_phase_b) * 0.36;
	distortion_field += perpendicular * wave_displacement * motion_depth * 0.30;
	vec2 distortion = distortion_field * texel * active_distortion * chunk_edge_fade * smoothstep(0.02, 0.24, mask);
	vec3 source = texture(TEXTURE, clamp(UV + distortion, vec2(0.0), vec2(1.0))).rgb;

	float shoreline = mask * (1.0 - smoothstep(0.015, 0.18, depth));
	float shallow_water = mask * (1.0 - smoothstep(0.04, 0.56, depth));
	float deep_water = smoothstep(0.24, 0.82, depth);
	float foam_noise = smooth_noise((world_position + flow_offset * 0.28 + vec2(31.0, -17.0)) * 0.024);
	float foam_breakup = smoothstep(0.36, 0.72, foam_noise + detail_noise * 0.24);
	float swash_phase = 0.5 + 0.5 * sin(TIME * 0.72 + broad_noise * 2.8);
	float swash_front = mix(0.24, 0.78, swash_phase);
	float inner_shore_foam = 1.0 - smoothstep(0.055, 0.15, abs(shore_field - swash_front));
	inner_shore_foam *= smoothstep(0.34, 0.70, foam_noise + detail_noise * 0.22);
	inner_shore_foam *= smoothstep(0.04, 0.24, shore_field);
	float outer_foam_pulse = 0.5 + 0.5 * sin(TIME * 0.64 - depth * 23.0 + broad_noise * 4.2);
	float outer_foam_front = mix(0.18, 0.56, outer_foam_pulse);
	float outer_shore_foam = 1.0 - smoothstep(0.045, 0.12, abs(outer_shore_field - outer_foam_front));
	outer_shore_foam *= smoothstep(0.52, 0.78, foam_noise + cross_noise * 0.18);
	outer_shore_foam *= smoothstep(0.03, 0.20, outer_shore_field);
	outer_shore_foam *= smoothstep(0.24, 0.72, outer_foam_pulse);
	float edge_wash = baked_edge * smoothstep(0.58, 0.80, foam_noise + swash_phase * 0.16) * 0.36;

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

	vec3 water_color = mix(source, water_tint.rgb, tint_strength * mix(0.35, 1.0, deep_water));
	vec3 edge_cover_color = mix(water_tint.rgb, shallow_tint.rgb, 0.48);
	vec3 edge_color = edge_cover_color;
	vec3 color = mix(edge_color, water_color, mask);
	color = mix(color, shallow_tint.rgb, shallow_water * shallow_strength * 0.72);
	float reflection_amount = broad_reflection * mix(0.18, 1.0, deep_water) * reflection_strength * mix(1.0, 0.72, weather_strength);
	color = mix(color, reflection_tint.rgb, reflection_amount);
	float visible_highlight = organic_caustics * 0.72 + surface_glint * 0.26;
	color += vec3(0.62, 0.92, 0.96) * visible_highlight * highlight_strength * mix(1.0, 0.55, weather_strength);
	color += vec3(0.68, 0.91, 0.95) * rain_rings * 0.075;
	float wave_crest = traveling_wave * mix(0.22, 1.0, deep_water);
	color += reflection_tint.rgb * wave_crest * wave_strength * mix(1.0, 0.68, weather_strength);
	float foam = clamp(max(max(inner_shore_foam, outer_shore_foam), edge_wash) + traveling_wave * shoreline * foam_breakup * shoreline_strength * 1.55, 0.0, 1.0);
	color = mix(color, vec3(0.86, 0.98, 1.0), foam * shore_foam_strength);
	float surface_opacity = mix(shallow_opacity, deep_opacity, smoothstep(0.10, 0.72, depth));
	float edge_opacity = baked_edge * baked_edge_cover;
	float foam_opacity = foam * shore_foam_strength * 0.86;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), max(mask * surface_opacity, max(edge_opacity, foam_opacity)));
}
