shader_type canvas_item;

uniform float distortion_pixels : hint_range(0.0, 8.0, 0.1) = 3.2;
uniform float current_speed : hint_range(0.0, 2.0, 0.01) = 0.42;
uniform float caustic_strength : hint_range(0.0, 0.2, 0.005) = 0.028;
uniform vec4 depth_tint : source_color = vec4(0.02, 0.28, 0.42, 1.0);


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
	vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
	float underwater_flow = TIME * current_speed;
	float broad_noise = smooth_noise(UV * vec2(11.0, 15.0) + vec2(underwater_flow * 0.28, -underwater_flow * 0.12));
	float detail_noise = smooth_noise(UV * vec2(28.0, 22.0) + vec2(-underwater_flow, underwater_flow * 0.34));
	float wave_a = sin(UV.y * 18.0 + UV.x * 7.0 - underwater_flow * 2.1 + broad_noise * 2.4);
	float wave_b = sin(UV.y * 31.0 - UV.x * 5.0 - underwater_flow * 1.4 + detail_noise * 1.8);
	vec2 distortion = vec2(wave_a * 0.78 + detail_noise - 0.5, wave_b * 0.28 + broad_noise - 0.5);
	vec3 source = texture(TEXTURE, clamp(UV + distortion * texel * distortion_pixels, vec2(0.0), vec2(1.0))).rgb;

	float depth = smoothstep(0.12, 0.94, UV.y);
	float caustic_phase = UV.x * 34.0 + UV.y * 5.0 - underwater_flow * 0.9 + broad_noise * 2.6;
	float caustic_line = pow(0.5 + 0.5 * sin(caustic_phase), 10.0);
	caustic_line *= (0.34 + detail_noise * 0.66) * (1.0 - smoothstep(0.16, 0.82, UV.y));
	vec3 color = mix(source, depth_tint.rgb, 0.06 + depth * 0.18);
	color += vec3(0.46, 0.90, 0.96) * caustic_line * caustic_strength * (1.0 - depth * 0.72);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
