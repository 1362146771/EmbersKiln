shader_type canvas_item;
render_mode unshaded;
uniform vec4 blood_color : source_color;
uniform float edge_width;
uniform float opacity;

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float nearest = min(edge.x, edge.y);
	float border = 1.0 - smoothstep(0.0, edge_width, nearest);
	// Soft, slightly uneven edge; the center remains completely transparent.
	float grain = 0.92 + 0.08 * sin(UV.x * 45.0 + sin(UV.y * 31.0));
	COLOR = vec4(blood_color.rgb, border * border * grain * opacity);
}
