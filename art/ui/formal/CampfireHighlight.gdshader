shader_type canvas_item;
render_mode unshaded;

uniform bool highlighted = false;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tint = vertex_tint;
	vec4 source = texture(TEXTURE, UV);
	float edge = source.a;
	if (highlighted) {
		vec2 radius = TEXTURE_PIXEL_SIZE * 18.0;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				edge = max(edge, texture(TEXTURE, UV + vec2(float(x), float(y)) * radius).a);
			}
		}
		vec3 fill = min(source.rgb * 1.1, vec3(1.0));
		COLOR = vec4(mix(vec3(1.0, 0.97, 0.88), fill, source.a), edge) * tint;
	} else {
		COLOR = source * tint;
	}
}
