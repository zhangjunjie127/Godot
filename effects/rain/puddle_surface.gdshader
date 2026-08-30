shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D puddle_mask : repeat_disable, filter_linear;
uniform sampler2D ripple_flow : repeat_enable, filter_linear_mipmap;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.0;
uniform float small_cutoff : hint_range(0.0, 1.0) = 0.88;
uniform float medium_cutoff : hint_range(0.0, 1.0) = 0.72;
uniform float heavy_cutoff : hint_range(0.0, 1.0) = 0.34;
uniform float mask_softness : hint_range(0.001, 0.2) = 0.055;
uniform float medium_spread_pixels : hint_range(0.0, 12.0) = 3.0;
uniform float heavy_spread_pixels : hint_range(0.0, 16.0) = 4.0;
uniform float edge_feather_pixels : hint_range(0.0, 8.0) = 3.0;
uniform float edge_feather_opacity : hint_range(0.0, 0.8) = 0.42;
uniform float distortion_pixels : hint_range(0.0, 3.0) = 0.82;
uniform float water_opacity : hint_range(0.0, 0.6) = 0.42;
uniform float sky_reflection : hint_range(0.0, 0.35) = 0.16;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.20;
uniform float depth_strength : hint_range(0.0, 1.0) = 0.54;
uniform vec4 water_tint : source_color = vec4(0.25, 0.47, 0.55, 1.0);
uniform vec4 deep_water_tint : source_color = vec4(0.08, 0.24, 0.31, 1.0);
uniform vec4 sky_color : source_color = vec4(0.62, 0.78, 0.84, 1.0);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float expanded_mask(vec2 uv, vec2 spread) {
	float authored = texture(puddle_mask, uv).r;
	authored = max(authored, texture(puddle_mask, uv + vec2(spread.x, 0.0)).r);
	authored = max(authored, texture(puddle_mask, uv - vec2(spread.x, 0.0)).r);
	authored = max(authored, texture(puddle_mask, uv + vec2(0.0, spread.y)).r);
	authored = max(authored, texture(puddle_mask, uv - vec2(0.0, spread.y)).r);
	authored = max(authored, texture(puddle_mask, uv + spread).r);
	authored = max(authored, texture(puddle_mask, uv - spread).r);
	authored = max(authored, texture(puddle_mask, uv + vec2(spread.x, -spread.y)).r);
	authored = max(authored, texture(puddle_mask, uv + vec2(-spread.x, spread.y)).r);
	return authored;
}

vec2 sample_flow(vec2 position) {
	vec2 flow_uv = position / vec2(420.0, 260.0);
	vec2 first = texture(ripple_flow, flow_uv + vec2(0.018, 0.011) * TIME * flow_speed).gb * 2.0 - 1.0;
	vec2 second = texture(ripple_flow, flow_uv * 1.37 + vec2(0.19, 0.43) + vec2(-0.013, 0.017) * TIME * flow_speed).gb * 2.0 - 1.0;
	return (first + vec2(second.y, -second.x) * 0.72) / 1.72;
}

void fragment() {
	float medium_progress = smoothstep(0.02, 0.60, puddle_amount);
	float heavy_progress = smoothstep(0.60, 1.0, puddle_amount);
	float mask_cutoff = mix(small_cutoff, medium_cutoff, medium_progress);
	mask_cutoff = mix(mask_cutoff, heavy_cutoff, heavy_progress);
	float spread_pixels = mix(0.0, medium_spread_pixels, medium_progress);
	spread_pixels = mix(spread_pixels, heavy_spread_pixels, heavy_progress);
	vec2 mask_pixel_size = 1.0 / vec2(textureSize(puddle_mask, 0));
	vec2 spread = mask_pixel_size * spread_pixels;
	vec2 feather_spread = spread + mask_pixel_size * edge_feather_pixels;

	float authored = expanded_mask(UV, spread);
	float feather_authored = expanded_mask(UV, feather_spread);
	float puddle = smoothstep(mask_cutoff - mask_softness, mask_cutoff + mask_softness, authored);
	float damp_edge = smoothstep(mask_cutoff - mask_softness * 1.8, mask_cutoff + mask_softness * 1.8, feather_authored);
	damp_edge *= 1.0 - puddle;

	vec2 flow = sample_flow(world_position);
	vec2 offset = flow * distortion_pixels * SCREEN_PIXEL_SIZE;
	float depth = smoothstep(mask_cutoff, min(mask_cutoff + 0.34, 1.0), authored) * depth_strength;
	vec3 refracted = textureLod(
		screen_texture,
		clamp(SCREEN_UV + offset, vec2(0.0), vec2(1.0)),
		depth * 0.72
	).rgb;
	vec3 wet = mix(refracted, water_tint.rgb, 0.27);
	wet = mix(wet, sky_color.rgb, sky_reflection);
	wet = mix(wet, deep_water_tint.rgb, depth * 0.42);
	float flow_energy = clamp(length(flow), 0.0, 1.0);
	wet += sky_color.rgb * flow_energy * 0.025;

	float edge = smoothstep(0.02, 0.32, puddle) * (1.0 - smoothstep(0.68, 0.98, puddle));
	float shimmer = sin((world_position.x + world_position.y * 0.7) * 0.018 + TIME * 0.55) * 0.5 + 0.5;
	wet += sky_color.rgb * edge * mix(0.035, 0.075, shimmer);

	vec3 damp = mix(refracted, vec3(0.11, 0.20, 0.22), 0.24);
	vec3 surface = mix(damp, wet, puddle);
	float presence = smoothstep(0.01, 0.10, puddle_amount);
	float rain_sheen = mix(0.92, 1.0, rain_intensity);
	float alpha = max(puddle * water_opacity, damp_edge * edge_feather_opacity);
	COLOR = vec4(surface * rain_sheen, alpha * presence);
}
