shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float max_opacity : hint_range(0.0, 0.35) = 0.28;
uniform float saturation : hint_range(0.0, 1.0) = 0.72;
uniform vec4 rain_tint : source_color = vec4(0.60, 0.71, 0.76, 1.0);

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 softened = mix(vec3(luminance), scene, saturation);
	vec3 cooled = softened * rain_tint.rgb;
	float highlight = smoothstep(0.72, 1.0, max(scene.r, max(scene.g, scene.b)));
	cooled += vec3(0.014, 0.021, 0.024) * highlight;
	COLOR = vec4(cooled, max_opacity * rain_intensity);
}
