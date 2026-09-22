shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atmosphere_mask : filter_linear, repeat_disable;
uniform sampler2D smoke_flow_map : filter_linear, repeat_disable;
uniform sampler2D smoke_path_uv : filter_linear, repeat_disable;
uniform sampler2D smoke_noise : filter_linear, repeat_enable;
// TIME keeps the authored scene animated in the editor. At runtime a local
// presentation clock takes over so pause/visibility and deterministic QA work.
uniform bool use_runtime_clock = false;
uniform float cycle_phase : hint_range(0.0, 1.0) = 0.0;
uniform float smoke_travel_pixels : hint_range(0.0, 120.0) = 84.0;
uniform float smoke_detail : hint_range(0.0, 0.4) = 0.22;
uniform float smoke_strength : hint_range(0.0, 1.0) = 1.0;
uniform float shed_strength : hint_range(0.0, 1.0) = 0.8;
uniform float flame_strength : hint_range(0.0, 1.0) = 0.8;
varying vec4 vertex_tint;

// Origins sit on the outside of the painted ribbons in a 720 x 1280
// reference canvas. XY = origin; ZW = outward/upward travel per lifetime.
// Keeping this in background UV also preserves alignment in tall viewports.
const vec4 SHED_STREAMS[14] = vec4[14](
	vec4(484.0, 113.0, 38.0, -56.0),
	vec4(462.0, 210.0, 44.0, -62.0),
	vec4(418.0, 292.0, 46.0, -48.0),
	vec4(73.0, 142.0, -32.0, -60.0),
	vec4(92.0, 248.0, -30.0, -45.0),
	vec4(196.0, 286.0, -44.0, -49.0),
	vec4(391.0, 422.0, 37.0, -54.0),
	vec4(410.0, 519.0, 40.0, -60.0),
	vec4(382.0, 594.0, 44.0, -55.0),
	vec4(445.0, 730.0, 49.0, -46.0),
	vec4(470.0, 797.0, 45.0, -65.0),
	vec4(292.0, 805.0, 39.0, -53.0),
	vec4(89.0, 829.0, 33.0, -46.0),
	vec4(51.0, 1032.0, 35.0, -63.0)
);

void vertex() {
	vertex_tint = COLOR;
}

float smoke_paint(vec3 c) {
	// Cool grey brushwork only. Dark ink and warm brick stay anchored.
	float chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	return (1.0 - smoothstep(0.09, 0.16, chroma)) * smoothstep(0.19, 0.32, c.g);
}

float fire_paint(vec3 c) {
	return smoothstep(0.20, 0.42, c.r - c.b) * smoothstep(0.45, 0.75, c.r);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 matte = texture(atmosphere_mask, UV).rg;
	float phase = use_runtime_clock ? cycle_phase : fract(TIME / 24.0);
	float angle = phase * TAU;
	vec3 result = base.rgb;
	float smoke = matte.r * smoke_paint(base.rgb) * smoke_strength;
	if (smoke > 0.001) {
		vec4 path = texture(smoke_flow_map, UV);
		vec3 packed_uv = texture(smoke_path_uv, UV).rgb;
		vec2 stream_uv = vec2(dot(packed_uv.rg, vec2(256.0, 1.0)) / 257.0, packed_uv.b);
		vec2 flow = path.rg * 2.0 - 1.0;
		// Three transport passes in 24 seconds, always upstream. Stagger their
		// invisible reset along/across the stream rather than pulsing a whole band.
		float phase_a = fract(phase * 3.0 + stream_uv.x * 5.0 + stream_uv.y * 0.35);
		float phase_b = fract(phase_a + 0.5);
		float weight_a = pow(sin(phase_a * PI), 2.0);
		vec2 distance_a = TEXTURE_PIXEL_SIZE * (phase_a - 0.5) * smoke_travel_pixels;
		vec2 distance_b = TEXTURE_PIXEL_SIZE * (phase_b - 0.5) * smoke_travel_pixels;
		// Midpoint tracing follows the curved path instead of cutting across bends.
		vec2 tangent_a = texture(smoke_flow_map, UV - flow * distance_a * 0.5).rg * 2.0 - 1.0;
		vec2 tangent_b = texture(smoke_flow_map, UV - flow * distance_b * 0.5).rg * 2.0 - 1.0;
		vec2 uv_a = clamp(UV - tangent_a * distance_a, vec2(0.0), vec2(1.0));
		vec2 uv_b = clamp(UV - tangent_b * distance_b, vec2(0.0), vec2(1.0));
		vec3 a = texture(TEXTURE, uv_a).rgb;
		vec3 b = texture(TEXTURE, uv_b).rgb;
		// Both ends of each lookup must remain in smoke. Sample in fragment()
		// to support the headless shader compiler as well as Mobile and GL.
		a = mix(base.rgb, a, smoke_paint(a) * texture(atmosphere_mask, uv_a).r);
		b = mix(base.rgb, b, smoke_paint(b) * texture(atmosphere_mask, uv_b).r);
		vec3 transported = mix(b, a, weight_a);
		// Seamless detail moves in path coordinates at 256 source pixels/cycle.
		// This transports wisps in one direction; there is no sine-based sway.
		float density = texture(smoke_noise, vec2(stream_uv.x * 8.0 - phase, stream_uv.y * 1.5)).r - 0.5;
		transported += vec3(1.0, 0.97, 0.93) * density * smoke_detail;
		result = mix(base.rgb, transported, smoke);
	}
	// Small detached wisps: staggered births, curved upward drift, expansion,
	// then erosion to transparency. Integer lifetime counts close the 24s loop.
	// No particle resets and no new per-frame CPU objects are required.
	if (shed_strength > 0.0) {
		vec2 point = UV * vec2(720.0, 1280.0);
		float veil = 0.0;
		for (int i = 0; i < 14; i++) {
			float seed = float(i);
			float age = fract(phase * (2.0 + mod(seed, 2.0)) + seed * 0.618034);
			vec4 stream = SHED_STREAMS[i];
			vec2 drift = stream.zw;
			vec2 bend = vec2(sin(age * PI) * (7.0 + mod(seed, 3.0) * 3.0), 0.0);
			bend.x *= sign(drift.x);
			vec2 center = stream.xy + drift * age + bend;
			vec2 up = normalize(drift);
			vec2 side = vec2(-up.y, up.x);
			vec2 relative = point - center;
			vec2 local = vec2(dot(relative, side), dot(relative, up));
			vec2 radius = vec2(10.0 + mod(seed * 7.0, 9.0), 22.0 + mod(seed * 3.0, 13.0));
			radius *= 0.7 + age * 0.9;
			vec2 q = local / radius;
			if (dot(q, q) < 2.8) {
				vec2 grain_uv = q * vec2(0.19, 0.12) + vec2(seed * 0.137, seed * 0.271 - age * 0.23);
				float grain = texture(smoke_noise, grain_uv).r;
				float curl = texture(smoke_noise, grain_uv * 2.1 + vec2(age * 0.1, 0.0)).r;
				q.x += sin(q.y * 2.5 + seed) * 0.18 + (curl - 0.5) * 0.6;
				float fringe = 1.0 - smoothstep(0.15, 1.25, length(q) + (grain - 0.5) * 0.8);
				float life = smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(0.38, 1.0, age));
				float threads = smoothstep(0.23 + age * 0.14, 0.72, grain);
				veil += fringe * life * threads * (0.48 + mod(seed, 3.0) * 0.09);
			}
		}
		// Protect warm masonry and lit windows; wisps softly veil the open sky.
		float masonry = smoothstep(0.07, 0.18, base.r - base.b);
		float opacity = min(veil, 0.45) * shed_strength * (1.0 - masonry);
		result = mix(result, vec3(0.52, 0.515, 0.50), opacity);
	}
	float fire = matte.g * fire_paint(base.rgb);
	if (fire > 0.001) {
		float flutter = sin(UV.x * 193.0 + angle * 43.0 + sin(UV.y * 151.0 - angle * 29.0));
		vec2 fire_uv = UV + vec2(flutter * 0.0018, sin(angle * 31.0 + UV.x * 89.0) * 0.003);
		vec3 flame = texture(TEXTURE, fire_uv).rgb;
		float safe_fire = fire_paint(flame) * texture(atmosphere_mask, fire_uv).g;
		float rising = sin(UV.y * 380.0 + angle * 37.0 + flutter * 0.65);
		float breath = 0.92 + 0.10 * sin(angle * 13.0 + UV.y * 39.0) + 0.08 * rising;
		vec3 lit = mix(base.rgb, flame, safe_fire * 0.72) * breath;
		lit += vec3(0.10, 0.040, 0.005) * max(rising, 0.0);
		result = mix(result, lit, fire * flame_strength);
	}
	COLOR = vec4(result, base.a) * vertex_tint;
}
