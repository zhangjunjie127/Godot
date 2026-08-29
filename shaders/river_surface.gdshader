shader_type canvas_item;

uniform sampler2D water_mask : repeat_disable, filter_linear;
uniform vec2 chunk_world_origin = vec2(0.0);
uniform vec2 chunk_world_size = vec2(2048.0);
uniform vec2 flow_direction = vec2(0.94, 0.34);
uniform float flow_speed : hint_range(0.0, 80.0, 1.0) = 22.0;
uniform float flow_strength : hint_range(0.0, 0.2, 0.005) = 0.075;
uniform float caustics_scale : hint_range(0.004, 0.05, 0.001) = 0.018;
uniform float caustics_strength : hint_range(0.0, 0.4, 0.01) = 0.12;
uniform vec4 water_tint : source_color = vec4(0.06, 0.50, 0.66, 1.0);


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
	vec4 source = texture(TEXTURE, UV);
	float shoreline_alpha = texture(water_mask, UV).r;
	vec2 world_position = chunk_world_origin + UV * chunk_world_size;
	vec2 direction = normalize(flow_direction);
	vec2 perpendicular = vec2(-direction.y, direction.x);
	vec2 moving_position = world_position + direction * TIME * flow_speed;

	float broad_current = smooth_noise(vec2(
		dot(moving_position, direction) * 0.006,
		dot(world_position, perpendicular) * 0.014
	));
	float web_a = abs(smooth_noise(moving_position * caustics_scale) - 0.5);
	float web_b = abs(smooth_noise((world_position - direction * TIME * flow_speed * 0.62) * caustics_scale * 1.47 + 19.0) - 0.5);
	float caustics = 1.0 - smoothstep(0.06, 0.22, min(web_a, web_b));

	vec3 color = source.rgb;
	color = mix(color, water_tint.rgb, (broad_current - 0.5) * flow_strength + flow_strength * 0.5);
	color += vec3(0.55, 0.90, 0.86) * caustics * caustics_strength;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), shoreline_alpha * source.a);
}
