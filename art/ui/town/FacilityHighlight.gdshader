shader_type canvas_item;
render_mode unshaded;

uniform float highlight : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float edge = source.a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.283185 / 16.0;
		vec2 sample_uv = UV + vec2(cos(angle), sin(angle)) * 0.018;
		edge = max(edge, texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0))).a);
	}
	float outline = (1.0 - source.a) * edge * highlight;
	float alpha = source.a + outline;
	COLOR = vertex_tint * vec4((source.rgb * source.a + vec3(outline)) / max(alpha, 0.0001), alpha);
}
