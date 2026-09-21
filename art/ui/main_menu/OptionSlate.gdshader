shader_type canvas_item;

uniform float body_opacity : hint_range(0.0, 1.0) = 0.66;
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform float outline_pixels = 14.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_pixels;
	float neighbor = min(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a);
	neighbor = min(neighbor, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	neighbor = min(neighbor, texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a);
	float edge = smoothstep(0.12, 0.65, ink.a) * (1.0 - smoothstep(0.12, 0.65, neighbor));
	float white = edge * highlight;
	// Remove almost invisible generation specks; keep the painted alpha edge.
	float alpha = ink.a * smoothstep(0.04, 0.12, ink.a) * body_opacity;
	COLOR = vec4(mix(ink.rgb, vec3(1.0), white), max(alpha, white)) * vertex_tint;
}
