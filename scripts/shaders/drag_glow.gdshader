shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.2, 1.0);
uniform float glow_strength = 1.0;
uniform float pulse_speed = 2.0;
uniform float edge_width = 0.08;
uniform float inner_fade = 0.02;

void fragment() {
	vec2 uv = UV;
	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float edge = 1.0 - smoothstep(edge_width, edge_width + inner_fade, edge_dist);
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);
	vec4 color = glow_color;
	color.a *= edge * glow_strength * pulse;
	COLOR = color;
}
