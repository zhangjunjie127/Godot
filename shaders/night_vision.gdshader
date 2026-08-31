shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform vec2 viewport_size = vec2(640.0, 360.0);
uniform vec3 night_tint = vec3(0.07, 0.084, 0.126);
uniform float radius_px = 41.0;
uniform float softness_px = 30.0;
uniform float outer_alpha = 0.50;
uniform float no_torch_inner_alpha = 0.55;
uniform float torch_inner_alpha = 0.20;
uniform bool torch_equipped = false;

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	vec2 delta_px = (UV - center_uv) * viewport_size;
	float visibility = 1.0 - smoothstep(radius_px, radius_px + softness_px, length(delta_px));
	float inner_alpha = torch_equipped ? torch_inner_alpha : no_torch_inner_alpha;
	float darkness = mix(outer_alpha, inner_alpha, visibility);
	vec3 restored = clamp(scene.rgb / max(night_tint, vec3(0.04)), vec3(0.0), vec3(1.0));
	vec3 night_color = restored * vec3(0.84, 0.90, 1.0);
	vec3 base_color = mix(night_color, restored, visibility);
	COLOR = vec4(mix(base_color, vec3(0.0), darkness), scene.a);
}
