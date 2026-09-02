shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 fill_color = vec3(0.52, 0.66, 0.60);
uniform float fill_strength : hint_range(0.0, 0.3, 0.005) = 0.10;
uniform float shadow_start : hint_range(0.0, 0.5, 0.01) = 0.04;
uniform float shadow_end : hint_range(0.1, 1.0, 0.01) = 0.58;
uniform float outline_guard : hint_range(0.0, 0.2, 0.005) = 0.075;

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	float luminance = dot(scene.rgb, vec3(0.299, 0.587, 0.114));
	float shadow_weight = 1.0 - smoothstep(shadow_start, shadow_end, luminance);
	float outline_weight = smoothstep(0.015, outline_guard, luminance);
	float weight = shadow_weight * outline_weight;
	vec3 lifted = scene.rgb + fill_color * fill_strength * weight * (vec3(1.0) - scene.rgb);
	COLOR = vec4(clamp(lifted, vec3(0.0), vec3(1.0)), scene.a);
}
