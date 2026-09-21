shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fire_noise : filter_linear, repeat_enable;
uniform bool use_runtime_clock = false;
uniform float cycle_phase = 0.0;
uniform float heat_strength : hint_range(0.0, 1.0) = 0.85;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float phase = use_runtime_clock ? cycle_phase : fract(TIME / 8.0);
	float angle = phase * TAU;
	float noise = texture(fire_noise, vec2(UV.x * 3.0, UV.y * 2.0 + phase * 4.0)).r;
	// Heat belongs to the fired clay and yellow cracks, excluding the pale tag.
	float tag = smoothstep(0.83, 0.88, UV.x) * (1.0 - smoothstep(0.35, 0.41, UV.y));
	float hot = smoothstep(0.23, 0.48, base.r - base.b) * (1.0 - tag);
	float cracks = smoothstep(0.42, 0.72, base.g) * hot;
	float pulse = 0.5 + 0.5 * sin(angle * 2.0 + UV.x * 8.0 + UV.y * 5.0);
	vec3 color = base.rgb * (1.0 + hot * (pulse - 0.5) * 0.14 * heat_strength);
	color += vec3(0.30, 0.15, 0.018) * cracks * (0.15 + noise * 0.85) * heat_strength;
	// Existing kiln opening: vary only the painted flame, not its masonry frame.
	float opening = smoothstep(0.322, 0.335, UV.x) * (1.0 - smoothstep(0.388, 0.402, UV.x));
	opening *= smoothstep(0.395, 0.425, UV.y) * (1.0 - smoothstep(0.50, 0.525, UV.y));
	float flicker = 0.65 + 0.35 * sin(angle * 7.0 + UV.y * 115.0 + noise * 2.0);
	color = mix(color, base.rgb * (0.78 + flicker * 0.38) + vec3(0.15, 0.055, 0.0) * noise,
		opening * hot * heat_strength);
	// Alpha and geometry are untouched, even at the hottest part of the cycle.
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), base.a) * vertex_tint;
}
