shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 fill_color = vec3(0.52, 0.66, 0.60);
uniform float fill_strength : hint_range(0.0, 0.3, 0.005) = 0.10;
uniform float shadow_start : hint_range(0.0, 0.5, 0.01) = 0.04;
uniform float shadow_end : hint_range(0.1, 1.0, 0.01) = 0.58;
uniform float outline_guard : hint_range(0.0, 0.2, 0.005) = 0.075;
uniform float exposure : hint_range(-0.5, 0.5, 0.01) = 0.0;
uniform float contrast : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform vec3 grade_tint = vec3(1.0);
uniform float highlight_protection : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform vec3 fog_color = vec3(0.72, 0.80, 0.76);
uniform float fog_strength : hint_range(0.0, 0.2, 0.005) = 0.02;
uniform float fog_depth_start : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float fog_depth_end : hint_range(0.0, 1.0, 0.01) = 0.92;

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	vec3 graded = scene.rgb * exp2(exposure);
	float grade_luminance = dot(graded, vec3(0.299, 0.587, 0.114));
	graded = mix(vec3(grade_luminance), graded, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= grade_tint;
	float highlight = smoothstep(0.68, 0.98, max(scene.r, max(scene.g, scene.b)));
	graded = mix(graded, scene.rgb, highlight * highlight_protection);
	graded = clamp(graded, vec3(0.0), vec3(1.0));

	float luminance = dot(graded, vec3(0.299, 0.587, 0.114));
	float shadow_weight = 1.0 - smoothstep(shadow_start, shadow_end, luminance);
	float outline_weight = smoothstep(0.015, outline_guard, luminance);
	float weight = shadow_weight * outline_weight;
	vec3 lifted = graded + fill_color * fill_strength * weight * (vec3(1.0) - graded);
	float depth = 1.0 - SCREEN_UV.y;
	float fog_depth = smoothstep(fog_depth_start, fog_depth_end, depth);
	float fog_luminance_guard = mix(1.0, 0.72, luminance);
	float fog_amount = fog_strength * fog_depth * fog_luminance_guard;
	vec3 atmospheric = mix(lifted, fog_color, fog_amount);
	COLOR = vec4(clamp(atmospheric, vec3(0.0), vec3(1.0)), scene.a);
}
