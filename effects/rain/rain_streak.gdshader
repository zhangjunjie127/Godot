shader_type canvas_item;
render_mode unshaded;

uniform vec4 streak_color : source_color = vec4(0.72, 0.82, 0.92, 0.45);
uniform float width : hint_range(0.001, 0.5) = 0.10;
uniform float edge_softness : hint_range(0.001, 0.25) = 0.075;

void fragment() {
	float horizontal = abs(UV.x - 0.5) * 2.0;
	float body = 1.0 - smoothstep(width, width + edge_softness, horizontal);
	float tips = smoothstep(0.0, 0.13, UV.y) * smoothstep(0.0, 0.24, 1.0 - UV.y);
	float core = 1.0 - smoothstep(width * 0.22, width * 0.58, horizontal);
	float alpha = body * tips * streak_color.a * COLOR.a;
	vec3 color = mix(streak_color.rgb, vec3(0.90, 0.96, 1.0), core * 0.22);
	COLOR = vec4(color, alpha);
}
