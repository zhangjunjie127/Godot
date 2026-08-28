shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_pixels : hint_range(0.0, 2.0) = 0.85;
uniform vec4 sky_color : source_color = vec4(0.48, 0.68, 0.78, 1.0);

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float authored_mask = texture(TEXTURE, UV).r;
	float puddle = smoothstep(0.28, 0.76, authored_mask);
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	float wave_x = sin(UV.y * 720.0 + TIME * 1.8 + hash(floor(UV * 90.0)) * 4.0);
	float wave_y = cos(UV.x * 610.0 - TIME * 1.25);
	vec2 offset = vec2(wave_x, wave_y) * distortion_pixels * rain_intensity / max(screen_size, vec2(1.0));
	vec3 refracted = texture(screen_texture, SCREEN_UV + offset).rgb;
	float glint = smoothstep(0.68, 0.98, sin((UV.x + UV.y) * 460.0 + TIME * 0.7) * 0.5 + 0.5);
	vec3 wet = mix(refracted, refracted * vec3(0.76, 0.87, 0.92), 0.36);
	wet += sky_color.rgb * (0.055 + glint * 0.045);
	COLOR = vec4(wet, puddle * rain_intensity * 0.46);
}
