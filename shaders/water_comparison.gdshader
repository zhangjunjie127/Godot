shader_type canvas_item;
render_mode unshaded;

uniform sampler2D water_mask : repeat_disable, filter_linear;
uniform int preset : hint_range(0, 2, 1) = 0;


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


float minimum_mask_ring(vec2 uv, vec2 texel, float radius) {
	vec2 x = vec2(texel.x * radius, 0.0);
	vec2 y = vec2(0.0, texel.y * radius);
	vec2 d = vec2(texel.x * radius * 0.707, texel.y * radius * 0.707);
	float value = texture(water_mask, clamp(uv + x, vec2(0.0), vec2(1.0))).r;
	value = min(value, texture(water_mask, clamp(uv - x, vec2(0.0), vec2(1.0))).r);
	value = min(value, texture(water_mask, clamp(uv + y, vec2(0.0), vec2(1.0))).r);
	value = min(value, texture(water_mask, clamp(uv - y, vec2(0.0), vec2(1.0))).r);
	value = min(value, texture(water_mask, clamp(uv + d, vec2(0.0), vec2(1.0))).r);
	value = min(value, texture(water_mask, clamp(uv - d, vec2(0.0), vec2(1.0))).r);
	value = min(value, texture(water_mask, clamp(uv + vec2(d.x, -d.y), vec2(0.0), vec2(1.0))).r);
	return min(value, texture(water_mask, clamp(uv + vec2(-d.x, d.y), vec2(0.0), vec2(1.0))).r);
}


float expanding_ripple(vec2 uv, vec2 center, float phase) {
	float progress = fract(TIME * 0.11 + phase);
	float radius = progress * 0.09;
	float distance_to_center = length(uv - center);
	float ring = 1.0 - smoothstep(0.002, 0.005, abs(distance_to_center - radius));
	return ring * (1.0 - progress);
}


void fragment() {
	float mask = texture(water_mask, UV).r;
	vec2 texel = 1.0 / vec2(textureSize(water_mask, 0));
	float shoreline = mask * (1.0 - minimum_mask_ring(UV, texel, 12.0));
	float shallow_water = mask * (1.0 - minimum_mask_ring(UV, texel, 42.0));

	float wave_a = sin(UV.x * 72.0 + UV.y * 34.0 + TIME * 1.25);
	float wave_b = sin(UV.x * -41.0 + UV.y * 86.0 - TIME * 0.92);
	float current = smooth_noise(UV * 18.0 + vec2(TIME * 0.28, TIME * -0.12));
	float distortion_strength = 0.0014;
	if (preset == 1) {
		distortion_strength = 0.0021;
	} else if (preset == 2) {
		distortion_strength = 0.0042;
	}
	vec2 distortion = vec2(wave_a + current - 0.5, wave_b - current + 0.5) * distortion_strength;
	vec3 source = texture(TEXTURE, clamp(UV + distortion * mask, vec2(0.0), vec2(1.0))).rgb;

	float thread_a = pow(0.5 + 0.5 * sin(UV.x * 150.0 + UV.y * 42.0 + TIME * 1.15 + current * 3.0), 18.0);
	float thread_b = pow(0.5 + 0.5 * sin(UV.x * -96.0 + UV.y * 128.0 - TIME * 0.82 + current * 2.0), 20.0);
	float caustic = clamp(thread_a + thread_b, 0.0, 1.0);
	float long_band = smoothstep(0.88, 0.97, 0.5 + 0.5 * sin(UV.x * 168.0 + UV.y * 72.0 + TIME * 1.45 + current * 3.0));
	float foam_motion = 0.55 + 0.45 * sin((UV.x - UV.y) * 96.0 + TIME * 2.1 + current * 5.0);
	float ripple = expanding_ripple(UV, vec2(0.30, 0.58), 0.0) + expanding_ripple(UV, vec2(0.68, 0.30), 0.48);
	ripple *= mask;

	vec3 color = source;
	if (preset == 0) {
		color = mix(color, vec3(0.04, 0.57, 0.78), 0.08 + shallow_water * 0.08);
		color += vec3(0.66, 0.94, 1.0) * ripple * 0.10;
		color += vec3(0.76, 0.96, 1.0) * shoreline * foam_motion * 0.12;
	} else if (preset == 1) {
		color = mix(color, vec3(0.02, 0.42, 0.70), 0.13 + shallow_water * 0.10);
		color += vec3(0.34, 0.85, 1.0) * long_band * 0.10;
		color += vec3(0.82, 0.98, 1.0) * ripple * 0.15;
		color = mix(color, vec3(0.92, 0.99, 1.0), shoreline * smoothstep(0.44, 0.80, foam_motion) * 0.46);
	} else {
		color = mix(color, vec3(0.02, 0.34, 0.52), 0.10);
		color = mix(color, vec3(0.08, 0.68, 0.74), shallow_water * 0.14);
		color += vec3(0.62, 0.92, 0.96) * thread_a * current * 0.018;
		color += vec3(0.68, 0.94, 1.0) * ripple * 0.13;
		color = mix(color, vec3(0.86, 0.98, 1.0), shoreline * foam_motion * 0.24);
	}

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), mask);
}
