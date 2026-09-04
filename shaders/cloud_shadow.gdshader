shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform vec3 shadow_multiplier = vec3(0.60, 0.70, 0.64);
uniform float shadow_coverage : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float cloud_density : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float cloud_scale : hint_range(400.0, 3200.0, 50.0) = 1450.0;
uniform float edge_softness : hint_range(0.01, 0.25, 0.01) = 0.08;
uniform vec2 primary_offset = vec2(0.0);
uniform vec2 shape_offset = vec2(631.0, 277.0);

varying vec2 world_position;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float fbm(vec2 point) {
	float value = 0.0;
	float amplitude = 0.5;
	float weight = 0.0;
	mat2 rotation = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int octave = 0; octave < 4; octave++) {
		value += value_noise(point) * amplitude;
		weight += amplitude;
		point = rotation * point + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value / weight;
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec2 primary = (world_position + primary_offset) / cloud_scale;
	vec2 secondary = (world_position + shape_offset) / (cloud_scale * 0.62);
	float cloud_field = mix(fbm(primary), value_noise(secondary), 0.18);
	float threshold = mix(0.50, 0.37, cloud_density);
	float cloud_mask = smoothstep(threshold - edge_softness, threshold + edge_softness, cloud_field);
	float strength = cloud_mask * shadow_coverage * COLOR.a;
	vec3 multiplier = mix(vec3(1.0), shadow_multiplier, strength);
	COLOR = vec4(multiplier, 1.0);
}
