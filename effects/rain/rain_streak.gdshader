shader_type canvas_item;
render_mode unshaded;

uniform vec4 streak_color : source_color = vec4(0.72, 0.82, 0.92, 0.45);
uniform float width : hint_range(0.01, 0.5) = 0.12;
uniform float edge_softness : hint_range(0.001, 0.25) = 0.075;

void fragment() {
	float horizontal = abs(UV.x - 0.5) * 2.0;
	float body = 1.0 - smoothstep(width, width + edge_softness, horizontal);
	float head = smoothstep(0.0, 0.16, UV.y);
	float tail = pow(clamp(1.0 - UV.y, 0.0, 1.0), 0.55);
	float alpha = body * head * tail * streak_color.a * COLOR.a;
	COLOR = vec4(streak_color.rgb, alpha);
}
