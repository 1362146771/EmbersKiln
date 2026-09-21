shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fire_noise : filter_linear, repeat_enable;
uniform bool use_runtime_clock = false;
uniform float cycle_phase = 0.0;
uniform vec2 logo_size = vec2(354.0, 200.0);
uniform vec2 padding = vec2(16.0, 40.0);
uniform float flame_height : hint_range(0.0, 40.0) = 25.0;
uniform float flame_opacity : hint_range(0.0, 1.0) = 0.85;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

float inside(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}

void fragment() {
	float phase = use_runtime_clock ? cycle_phase : fract(TIME / 8.0);
	float angle = phase * TAU;
	vec2 q = (UV * (logo_size + padding * 2.0) - padding) / logo_size;
	vec4 under = texture(TEXTURE, clamp(q, vec2(0.0), vec2(1.0)));
	float solid = under.a * inside(q);
	vec2 noise_uv = vec2(q.x * 4.0, q.y * 1.8 + phase * 4.0);
	float noise = texture(fire_noise, noise_uv).r;
	float fine = texture(fire_noise, noise_uv * vec2(1.7, 2.0) + vec2(0.37, phase * 2.0)).r;
	float height = flame_height * (0.35 + 0.85 * noise);
	float wind = (fine - 0.5) * 0.48;
	float tongue = 0.0;
	float core = 0.0;
	if (solid < 0.99) {
		// Look DOWN toward the glyph to build tongues rising ABOVE its warm edges.
		// This is a separate padded quad behind the unchanged original lettering.
		for (int i = 1; i <= 10; i++) {
			float reach = float(i) / 10.0;
			vec2 sample_uv = q + vec2(wind * reach * height, reach * height) / logo_size;
			vec4 fuel = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
			// Broad clay selection avoids turning each bright surface fleck into
			// a separate noisy emitter; the alpha silhouette defines the fire edge.
			float warm = smoothstep(0.025, 0.09, fuel.r - fuel.b);
			float tag = smoothstep(0.83, 0.88, sample_uv.x) * (1.0 - smoothstep(0.35, 0.41, sample_uv.y));
			float ember = fuel.a * warm * inside(sample_uv) * (1.0 - tag);
			tongue = max(tongue, ember * (1.0 - reach));
			core = max(core, ember * max(0.0, 1.0 - reach * 2.4));
		}
	}
	float alpha = smoothstep(0.08, 0.50, tongue) * flame_opacity * (1.0 - solid);
	// Broad amber body and a small cream-hot core fit the painted title.
	vec3 color = mix(vec3(0.93, 0.19, 0.018), vec3(1.0, 0.59, 0.12), smoothstep(0.1, 0.6, tongue));
	color = mix(color, vec3(1.0, 0.87, 0.46), smoothstep(0.18, 0.8, core));
	float sparks = 0.0;
	for (int i = 0; i < 5; i++) {
		float seed = float(i);
		float life = fract(phase * 2.0 + seed * 0.217);
		vec2 origin = vec2(0.20 + seed * 0.157, 0.10 + 0.09 * sin(seed * 2.4));
		vec2 spark_uv = origin + vec2(sin(life * 3.0 + seed) * 0.014, -life * 0.18);
		float distance_px = length((q - spark_uv) * logo_size);
		float fade = pow(sin(life * PI), 2.0);
		sparks = max(sparks, (1.0 - smoothstep(0.35, 1.3, distance_px)) * fade);
	}
	sparks *= 1.0 - solid;
	color = mix(color, vec3(1.0, 0.77, 0.30), sparks);
	COLOR = vec4(color, max(alpha, sparks * 0.9)) * vertex_tint;
}
