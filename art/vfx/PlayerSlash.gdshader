shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.08, 0.30);
	float angle = atan(p.y, p.x);
	float radius = length(p);
	float sweep = smoothstep(-0.35, -0.10, angle) * (1.0 - smoothstep(1.12, 1.38, angle));
	float width = 0.055 * sweep * (1.0 - progress * 0.8);
	float arc = 1.0 - smoothstep(width, width + 0.012, abs(radius - 0.64));
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	COLOR = vec4(vec3(1.0), arc * sweep * fade * 0.9);
}
