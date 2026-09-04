shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform vec3 shadow_multiplier = vec3(0.60, 0.70, 0.64);
uniform float shadow_coverage : hint_range(0.0, 1.0, 0.01) = 0.40;
uniform float edge_softness_px : hint_range(1.0, 32.0, 0.5) = 12.0;
uniform float distortion_px : hint_range(0.0, 8.0, 0.1) = 2.0;
uniform float distortion_speed : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform sampler2D cloud_texture : source_color, filter_linear, repeat_disable;


float cloud_alpha(vec2 uv) {
	return texture(cloud_texture, uv).a;
}


float soft_cloud_alpha(vec2 uv, vec2 texture_pixel_size, float time) {
	vec2 pixel = uv / texture_pixel_size;
	float phase = time * distortion_speed;
	vec2 warp = vec2(
		sin(pixel.y * 0.045 + phase),
		cos(pixel.x * 0.038 - phase * 0.8)
	) * texture_pixel_size * distortion_px;
	vec2 center = uv + warp;
	vec2 half_step = texture_pixel_size * edge_softness_px * 0.45;
	vec2 full_step = texture_pixel_size * edge_softness_px;
	float alpha = cloud_alpha(center) * 0.18;
	alpha += cloud_alpha(center + vec2(half_step.x, 0.0)) * 0.10;
	alpha += cloud_alpha(center - vec2(half_step.x, 0.0)) * 0.10;
	alpha += cloud_alpha(center + vec2(0.0, half_step.y)) * 0.10;
	alpha += cloud_alpha(center - vec2(0.0, half_step.y)) * 0.10;
	alpha += cloud_alpha(center + full_step * vec2(0.75, 0.75)) * 0.055;
	alpha += cloud_alpha(center + full_step * vec2(-0.75, 0.75)) * 0.055;
	alpha += cloud_alpha(center + full_step * vec2(0.75, -0.75)) * 0.055;
	alpha += cloud_alpha(center - full_step * 0.75) * 0.055;
	alpha += cloud_alpha(center + vec2(full_step.x, 0.0)) * 0.05;
	alpha += cloud_alpha(center - vec2(full_step.x, 0.0)) * 0.05;
	alpha += cloud_alpha(center + vec2(0.0, full_step.y)) * 0.05;
	alpha += cloud_alpha(center - vec2(0.0, full_step.y)) * 0.05;
	return smoothstep(0.02, 0.82, alpha);
}


void fragment() {
	float strength = soft_cloud_alpha(UV, TEXTURE_PIXEL_SIZE, TIME) * shadow_coverage * COLOR.a;
	vec3 multiplier = mix(vec3(1.0), shadow_multiplier, strength);
	COLOR = vec4(multiplier, 1.0);
}
