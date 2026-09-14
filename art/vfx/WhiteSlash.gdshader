shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// A tapered white cut sweeps diagonally across the portrait, then fades.
	vec2 p = UV;
	float along = (p.x + p.y) * 0.5;
	float curve = 0.07 * sin(along * 3.14159265);
	float distance_to_cut = abs(p.y - p.x - curve);
	float taper = pow(max(sin(clamp(along, 0.0, 1.0) * 3.14159265), 0.0), 1.5);
	float width = 0.035 * taper * (1.0 - progress * 0.7);
	float cut = 1.0 - smoothstep(width, width + 0.006, distance_to_cut);
	float halo = exp(-distance_to_cut * 60.0) * 0.22;
	float reveal = 1.0 - smoothstep(progress * 1.5, progress * 1.5 + 0.1, along);
	float ends = smoothstep(0.08, 0.18, along) * (1.0 - smoothstep(0.82, 0.92, along));
	float fade = 1.0 - smoothstep(0.48, 1.0, progress);
	COLOR = vec4(vec3(1.0), clamp((cut + halo) * reveal * ends * fade, 0.0, 1.0));
}
