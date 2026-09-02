shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 shadow_multiplier = vec3(0.68, 0.78, 0.72);
uniform float shadow_coverage : hint_range(0.0, 1.0, 0.01) = 0.32;

const mat4 BAYER_4X4 = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
);


float bayer_threshold(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	return (BAYER_4X4[x][y] + 0.5) / 16.0;
}


void fragment() {
	float shape = texture(TEXTURE, UV).a * COLOR.a;
	vec2 screen_pixel = floor(SCREEN_UV * vec2(textureSize(screen_texture, 0)));
	if (shape * shadow_coverage <= bayer_threshold(screen_pixel)) {
		discard;
	}
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec3 shadowed = scene * shadow_multiplier;
	COLOR = vec4(shadowed, 1.0);
}
