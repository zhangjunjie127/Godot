shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_start : hint_range(0.0, 1.0) = 0.45;
uniform float medium_cutoff : hint_range(0.0, 1.0) = 0.72;
uniform float heavy_cutoff : hint_range(0.0, 1.0) = 0.34;
uniform float mask_softness : hint_range(0.001, 0.2) = 0.055;
uniform float distortion_pixels : hint_range(0.0, 2.0) = 0.72;
uniform float water_opacity : hint_range(0.0, 0.5) = 0.26;
uniform float sky_reflection : hint_range(0.0, 0.35) = 0.11;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.32;
uniform vec4 water_tint : source_color = vec4(0.37, 0.55, 0.64, 1.0);
uniform vec4 sky_color : source_color = vec4(0.58, 0.72, 0.79, 1.0);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float authored = texture(TEXTURE, UV).r;
	float puddle_level = smoothstep(puddle_start, 1.0, rain_intensity);
	float mask_cutoff = mix(medium_cutoff, heavy_cutoff, puddle_level);
	float puddle = smoothstep(mask_cutoff - mask_softness, mask_cutoff + mask_softness, authored);
	vec2 world_wave = world_position * vec2(0.011, 0.014);
	float wave_x = sin(world_wave.y + TIME * flow_speed) + sin(world_wave.x * 0.63 - TIME * flow_speed * 0.72);
	float wave_y = cos(world_wave.x * 0.82 - TIME * flow_speed * 0.58);
	vec2 offset = vec2(wave_x, wave_y) * 0.5 * distortion_pixels * SCREEN_PIXEL_SIZE * puddle_level;
	vec3 refracted = textureLod(screen_texture, clamp(SCREEN_UV + offset, vec2(0.0), vec2(1.0)), 0.0).rgb;
	vec3 wet = mix(refracted, refracted * water_tint.rgb, 0.20);
	wet = mix(wet, sky_color.rgb, sky_reflection);
	float sheen = smoothstep(0.72, 1.0, sin(world_wave.x + world_wave.y + TIME * 0.22) * 0.5 + 0.5);
	wet += sky_color.rgb * sheen * 0.025;
	COLOR = vec4(wet, puddle * water_opacity * puddle_level);
}
