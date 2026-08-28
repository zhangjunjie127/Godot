shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_start : hint_range(0.0, 1.0) = 0.45;
uniform float medium_cutoff : hint_range(0.0, 1.0) = 0.72;
uniform float heavy_cutoff : hint_range(0.0, 1.0) = 0.34;
uniform float mask_softness : hint_range(0.001, 0.2) = 0.055;
uniform float medium_spread_pixels : hint_range(0.0, 12.0) = 3.0;
uniform float heavy_spread_pixels : hint_range(0.0, 16.0) = 4.0;
uniform float edge_feather_pixels : hint_range(0.0, 8.0) = 3.0;
uniform float edge_feather_opacity : hint_range(0.0, 0.8) = 0.58;
uniform float distortion_pixels : hint_range(0.0, 2.0) = 0.72;
uniform float water_opacity : hint_range(0.0, 0.5) = 0.40;
uniform float sky_reflection : hint_range(0.0, 0.35) = 0.18;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.32;
uniform vec4 water_tint : source_color = vec4(0.37, 0.55, 0.64, 1.0);
uniform vec4 sky_color : source_color = vec4(0.58, 0.72, 0.79, 1.0);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float puddle_level = smoothstep(puddle_start, 1.0, rain_intensity);
	float spread_level = smoothstep(0.75, 1.0, rain_intensity);
	vec2 spread = TEXTURE_PIXEL_SIZE * mix(medium_spread_pixels, heavy_spread_pixels, spread_level);
	float mask_cutoff = mix(medium_cutoff, heavy_cutoff, puddle_level);
	vec2 near_spread = spread + TEXTURE_PIXEL_SIZE * edge_feather_pixels * 0.333;
	vec2 middle_spread = spread + TEXTURE_PIXEL_SIZE * edge_feather_pixels * 0.667;
	vec2 outer_spread = spread + TEXTURE_PIXEL_SIZE * edge_feather_pixels;
	float core_authored = texture(TEXTURE, UV).r;
	core_authored = max(core_authored, texture(TEXTURE, UV + vec2(spread.x, 0.0)).r);
	core_authored = max(core_authored, texture(TEXTURE, UV - vec2(spread.x, 0.0)).r);
	core_authored = max(core_authored, texture(TEXTURE, UV + vec2(0.0, spread.y)).r);
	core_authored = max(core_authored, texture(TEXTURE, UV - vec2(0.0, spread.y)).r);
	core_authored = max(core_authored, texture(TEXTURE, UV + spread).r);
	core_authored = max(core_authored, texture(TEXTURE, UV - spread).r);
	core_authored = max(core_authored, texture(TEXTURE, UV + vec2(spread.x, -spread.y)).r);
	core_authored = max(core_authored, texture(TEXTURE, UV + vec2(-spread.x, spread.y)).r);
	float near_authored = texture(TEXTURE, UV).r;
	near_authored = max(near_authored, texture(TEXTURE, UV + vec2(near_spread.x, 0.0)).r);
	near_authored = max(near_authored, texture(TEXTURE, UV - vec2(near_spread.x, 0.0)).r);
	near_authored = max(near_authored, texture(TEXTURE, UV + vec2(0.0, near_spread.y)).r);
	near_authored = max(near_authored, texture(TEXTURE, UV - vec2(0.0, near_spread.y)).r);
	near_authored = max(near_authored, texture(TEXTURE, UV + near_spread).r);
	near_authored = max(near_authored, texture(TEXTURE, UV - near_spread).r);
	near_authored = max(near_authored, texture(TEXTURE, UV + vec2(near_spread.x, -near_spread.y)).r);
	near_authored = max(near_authored, texture(TEXTURE, UV + vec2(-near_spread.x, near_spread.y)).r);
	float middle_authored = texture(TEXTURE, UV).r;
	middle_authored = max(middle_authored, texture(TEXTURE, UV + vec2(middle_spread.x, 0.0)).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV - vec2(middle_spread.x, 0.0)).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV + vec2(0.0, middle_spread.y)).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV - vec2(0.0, middle_spread.y)).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV + middle_spread).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV - middle_spread).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV + vec2(middle_spread.x, -middle_spread.y)).r);
	middle_authored = max(middle_authored, texture(TEXTURE, UV + vec2(-middle_spread.x, middle_spread.y)).r);
	float outer_authored = texture(TEXTURE, UV).r;
	outer_authored = max(outer_authored, texture(TEXTURE, UV + vec2(outer_spread.x, 0.0)).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV - vec2(outer_spread.x, 0.0)).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV + vec2(0.0, outer_spread.y)).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV - vec2(0.0, outer_spread.y)).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV + outer_spread).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV - outer_spread).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV + vec2(outer_spread.x, -outer_spread.y)).r);
	outer_authored = max(outer_authored, texture(TEXTURE, UV + vec2(-outer_spread.x, outer_spread.y)).r);
	float core = smoothstep(mask_cutoff - mask_softness, mask_cutoff + mask_softness, core_authored);
	float near_edge = smoothstep(mask_cutoff - mask_softness * 1.4, mask_cutoff + mask_softness * 1.4, near_authored);
	float middle_edge = smoothstep(mask_cutoff - mask_softness * 1.8, mask_cutoff + mask_softness * 1.8, middle_authored);
	float outer_edge = smoothstep(mask_cutoff - mask_softness * 2.2, mask_cutoff + mask_softness * 2.2, outer_authored);
	float puddle = max(core, max(near_edge * edge_feather_opacity, max(middle_edge * edge_feather_opacity * 0.45, outer_edge * edge_feather_opacity * 0.12)));
	vec2 world_wave = world_position * vec2(0.011, 0.014);
	float wave_x = sin(world_wave.y + TIME * flow_speed) + sin(world_wave.x * 0.63 - TIME * flow_speed * 0.72);
	float wave_y = cos(world_wave.x * 0.82 - TIME * flow_speed * 0.58);
	vec2 offset = vec2(wave_x, wave_y) * 0.5 * distortion_pixels * SCREEN_PIXEL_SIZE * puddle_level;
	vec3 refracted = textureLod(screen_texture, clamp(SCREEN_UV + offset, vec2(0.0), vec2(1.0)), 0.0).rgb;
	vec3 wet = mix(refracted, water_tint.rgb, 0.32);
	wet = mix(wet, sky_color.rgb, sky_reflection);
	float sheen = smoothstep(0.72, 1.0, sin(world_wave.x + world_wave.y + TIME * 0.22) * 0.5 + 0.5);
	float edge = smoothstep(0.02, 0.34, puddle) * (1.0 - smoothstep(0.68, 0.98, puddle));
	wet += sky_color.rgb * (sheen * 0.045 + edge * 0.065);
	COLOR = vec4(wet, puddle * water_opacity * puddle_level);
}
