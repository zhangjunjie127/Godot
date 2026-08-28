shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(41.7, 289.3))) * 43758.5453);
}

void fragment() {
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 cell = floor(SCREEN_UV * screen_size / 18.0);
	float flow = hash(cell + floor(TIME * 2.0));
	vec2 offset = vec2((flow - 0.5) * 0.28, sin(SCREEN_UV.x * 43.0 + TIME) * 0.20);
	vec3 scene = texture(screen_texture, SCREEN_UV + offset * rain_intensity / max(screen_size, vec2(1.0))).rgb;
	float light = max(scene.r, max(scene.g, scene.b));
	vec3 wet = mix(scene, scene * vec3(0.73, 0.83, 0.89), 0.52);
	wet += vec3(0.035, 0.055, 0.065) * smoothstep(0.48, 0.92, light);
	COLOR = vec4(wet, rain_intensity * 0.26);
}
