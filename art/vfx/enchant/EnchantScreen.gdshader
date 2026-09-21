shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D effect_atlas : source_color, repeat_disable, filter_linear;
uniform sampler2D cutin_portrait : source_color, repeat_disable, filter_linear;
uniform float cutin_progress = -1.0;
uniform float cutin_portrait_height = 0.98;
uniform vec2 cutin_portrait_offset = vec2(-0.19, 0.035);
uniform float cutin_mask_top = 0.50;
uniform float cutin_mask_bottom = 0.90;
uniform vec4 cutin_mask_color : source_color = vec4(0.02745, 0.01961, 0.04706, 1.0);
uniform float cutin_background_retention = 0.04;
uniform vec2 cutin_eye_uv = vec2(0.716, 0.482);
uniform float cutin_blur_pixels = 18.0;
uniform vec4 cutin_red : source_color = vec4(0.835, 0.16, 0.21, 1.0);
uniform float charge = 0.0;
uniform float progress = 0.0;
uniform float strength = 0.0;
uniform float frame_cursor = 0.0;
uniform bool stepped_frames = false;
uniform vec2 impact_offset = vec2(0.0);
uniform float impact_zoom = 0.0;
uniform int effect_kind = 0;
uniform vec2 origin_uv = vec2(0.5, 0.32);
uniform vec2 canvas_size = vec2(720.0, 1280.0);
uniform vec2 sprite_size = vec2(520.0);
uniform vec2 sprite_anchor = vec2(0.5);
uniform vec2 sprite_offset = vec2(0.0);
uniform float sprite_rotation = 0.0;
uniform float saturation = 0.72;
uniform vec4 fire_color : source_color = vec4(0.85, 0.64, 0.25, 1.0);
uniform vec4 core_color : source_color = vec4(0.88, 0.76, 0.67, 1.0);
uniform vec4 ash_color : source_color = vec4(0.49, 0.31, 0.31, 1.0);
uniform vec4 ink_color : source_color = vec4(0.106, 0.086, 0.07, 1.0);
uniform float darken = 0.38;
uniform float distortion_pixels = 9.0;
uniform float reduced_motion = 0.0;
uniform int target_count = 0;
uniform vec2 target_origins[8];

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
// Premultiplied samples keep transparent ink edges clean during the short frame blends.
// Sampling is explicitly clamped inside a cell; adjacent atlas frames never bleed in.
vec4 atlas_frame(vec2 local_uv, float index) {
	vec2 grid = vec2(3.0, 2.0);
	vec2 slot = vec2(mod(index, 3.0), floor(index / 3.0));
	vec2 half_pixel = vec2(0.5 / 512.0);
	vec2 safe_uv = clamp(local_uv, half_pixel, vec2(1.0) - half_pixel);
	vec4 texel = texture(effect_atlas, (slot + safe_uv) / grid);
	// Remove residual chroma-key fringe in antialiased source pixels, preserving amber and blue ink.
	float spill = max(0.0, min(texel.r, texel.b) - texel.g * 1.5 - 0.02);
	texel.rb -= vec2(spill);
	float inside = step(0.0, local_uv.x) * step(local_uv.x, 1.0) * step(0.0, local_uv.y) * step(local_uv.y, 1.0);
	texel.a *= inside;
	return vec4(texel.rgb * texel.a, texel.a);
}
vec4 animated_art(vec2 pixels, vec2 anchor, float cursor, float t, float mirror) {
	vec2 p = pixels - anchor - sprite_offset;
	float rotation = sprite_rotation;
	if (effect_kind == 2) {
		// A fast horizontal sweep continues through the hand-authored shape changes.
		p.x -= mix(-115.0, 75.0, smoothstep(0.0, 0.48, t));
		rotation += mix(-0.18, 0.08, smoothstep(0.0, 0.5, t));
	} else if (effect_kind == 0) {
		p -= vec2(16.0, 28.0) * (1.0 - smoothstep(0.0, 0.18, t));
	} else if (effect_kind == 3) {
		p -= mix(vec2(-45.0, -60.0), vec2(22.0, 30.0), smoothstep(0.0, 0.34, t));
	} else if (effect_kind == 4) {
		p.y -= mix(60.0, -65.0, smoothstep(0.0, 0.60, t));
		rotation += mix(-0.10, 0.08, smoothstep(0.0, 0.45, t));
	} else if (effect_kind == 5) {
		p -= mix(vec2(-20.0, 25.0), vec2(12.0, -16.0), smoothstep(0.0, 0.32, t));
	} else if (effect_kind == 6) {
		rotation += mix(-0.22, 0.18, smoothstep(0.0, 0.65, t));
		p /= mix(0.80, 1.06, smoothstep(0.0, 0.32, t));
	} else if (effect_kind == 7) {
		p -= mix(vec2(-34.0, 40.0), vec2(28.0, -32.0), smoothstep(0.0, 0.45, t));
	} else if (effect_kind == 8) {
		p /= mix(1.16, 0.94, smoothstep(0.0, 0.24, t));
	}
	float c = cos(rotation);
	float s = sin(rotation);
	p = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
	p.x *= mirror;
	vec2 local_uv = p / sprite_size + sprite_anchor;
	float first = min(floor(cursor), 5.0);
	float blend = stepped_frames ? 0.0 : smoothstep(0.72, 1.0, fract(cursor));
	vec4 a = atlas_frame(local_uv, first);
	vec4 b = atlas_frame(local_uv, min(first + 1.0, 5.0));
	vec4 art = mix(a, b, blend);
	float grey = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	art.rgb = mix(vec3(grey), art.rgb, saturation);
	return art;
}
// Fullscreen vertical-opacity mask, then a transparent portrait with no center crop.
vec3 reaper_cutin(vec2 uv, vec3 base) {
	float t = cutin_progress;
	float enter = smoothstep(0.0, 0.10, t);
	float leave = smoothstep(0.78, 1.0, t);
	float envelope = enter * (1.0 - leave);
	vec2 blur_step = vec2(cutin_blur_pixels * 0.35) / canvas_size;
	float blur_lod = max(0.0, log2(max(cutin_blur_pixels, 1.0)));
	vec3 blurred = vec3(0.0);
	float weights = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			float w = exp(-float(x*x + y*y) * 0.45);
			blurred += textureLod(screen_texture, clamp(uv + vec2(float(x), float(y)) * blur_step, vec2(0.0), vec2(1.0)), blur_lod).rgb * w;
			weights += w;
		}
	}
	blurred /= weights;
	vec3 masked = mix(cutin_mask_color.rgb, blurred, cutin_background_retention);
	float mask_opacity = mix(cutin_mask_top, cutin_mask_bottom, smoothstep(0.0, 1.0, uv.y));
	vec3 cinematic = mix(base, masked, mask_opacity);
	// Preserve proportions and alpha silhouette, leaving space above the full horn.
	vec2 tex_size = vec2(textureSize(cutin_portrait, 0));
	vec2 portrait_size = vec2(tex_size.x / tex_size.y, 1.0) * (canvas_size.y * cutin_portrait_height);
	float shift = (-0.035 * (1.0 - enter) - 0.025 * leave) * (1.0 - reduced_motion);
	vec2 portrait_origin = (cutin_portrait_offset + vec2(shift, 0.0)) * canvas_size;
	vec2 face_uv = (uv * canvas_size - portrait_origin) / portrait_size;
	face_uv.x = 1.0 - face_uv.x;
	vec4 face = texture(cutin_portrait, clamp(face_uv, vec2(0.0), vec2(1.0)));
	float inside = step(0.0, face_uv.x) * step(face_uv.x, 1.0) * step(0.0, face_uv.y) * step(face_uv.y, 1.0);
	float portrait_mask = face.a * inside * (1.0 - smoothstep(0.92, 1.0, face_uv.y));
	vec2 eye = (portrait_origin + vec2(1.0 - cutin_eye_uv.x, cutin_eye_uv.y) * portrait_size) / canvas_size;
	vec2 d = (uv - eye) * canvas_size;
	float ignite = smoothstep(0.08, 0.22, t) * (1.0 - smoothstep(0.64, 0.93, t));
	float glow = exp(-dot(d / vec2(42.0, 32.0), d / vec2(42.0, 32.0)));
	float beam = exp(-abs(d.y) / 2.0) * exp(-abs(d.x) / 250.0);
	float core = exp(-dot(d / vec2(9.0, 7.0), d / vec2(9.0, 7.0)));
	float right = smoothstep(0.48, 0.66, uv.x);
	// Sparse drifting embers and curved traces lead the eye toward the coming sweep.
	for (int i = 0; i < 9; i++) {
		float n = float(i);
		vec2 pos = vec2(0.57 + hash(n + 3.0) * 0.40, fract(hash(n + 23.0) - t * 0.19));
		vec2 q = (uv - pos) * canvas_size;
		float ember = exp(-abs(q.x) * 0.55 - abs(q.y) * 0.18);
		cinematic += cutin_red.rgb * ember * right * 0.60;
	}
	float curve_x = (uv.x - 0.50) * 1.5;
	float curve = uv.y - (0.70 - 0.30 * curve_x * curve_x - t * 0.08);
	float trace = exp(-abs(curve) * canvas_size.y / 1.8) * right * sin(t * 3.14159);
	cinematic += cutin_red.rgb * trace * 0.22;
	// One restrained crimson entrance flash, no repeated strobing.
	cinematic += cutin_red.rgb * (1.0 - smoothstep(0.04, 0.15, t)) * 0.14 * (1.0 - reduced_motion);
	// Portrait is above the complete gradient treatment and its ambient effects.
	cinematic = mix(cinematic, face.rgb * vec3(0.92, 0.84, 0.86), portrait_mask);
	cinematic += cutin_red.rgb * (glow * 0.62 + beam * 0.76) * ignite;
	cinematic += vec3(1.0, 0.57, 0.42) * core * ignite;
	return mix(base, cinematic, envelope);
}
void fragment() {
	vec2 uv = (SCREEN_UV - vec2(0.5) - impact_offset / canvas_size) / (1.0 + impact_zoom) + vec2(0.5);
	vec2 pixels = uv * canvas_size;
	vec2 origin = origin_uv * canvas_size;
	vec2 p = pixels - origin;
	float t = progress;
	float radius = length(p);
	vec2 radial = p / max(radius, 0.01);
	float impact = (1.0 - smoothstep(0.025, 0.22, t)) * strength;
	float settle = (1.0 - smoothstep(0.18, 0.76, t)) * strength;
	float tail = (1.0 - smoothstep(0.74, 1.0, t)) * strength;
	float wave_radius = mix(16.0, 540.0, pow(t, 0.55));
	float wave = exp(-pow((radius - wave_radius) / 22.0, 2.0));
	vec2 offset = radial * wave * impact * distortion_pixels;
	if (effect_kind == 1 || effect_kind == 5 || effect_kind == 6) {
		offset.x += sin(p.y * 0.035 + t * 32.0) * sin(p.x * 0.018) * settle * 2.4;
	}
	offset *= (1.0 - reduced_motion);
	vec2 sample_uv = clamp(uv + offset / canvas_size, vec2(0.0), vec2(1.0));
	vec3 scene = texture(screen_texture, sample_uv).rgb;
	float atmosphere = max(charge * 0.65, settle);
	float luminance = dot(scene, vec3(0.299, 0.587, 0.114));
	scene = mix(scene, vec3(luminance), atmosphere * 0.22);
	scene *= 1.0 - darken * atmosphere;
	// Short contact light, concentrated around the attack rather than a white full-screen flash.
	scene += core_color.rgb * exp(-radius * radius / 19000.0) * impact * 0.14 * (1.0 - reduced_motion);
	float angle = atan(p.y, p.x);
	float border = smoothstep(190.0, 580.0, radius);
	float lines = pow(max(0.0, cos(angle * 19.0 + sin(angle * 7.0) * 2.0)), 70.0);
	scene += fire_color.rgb * lines * border * charge * 0.14;
	// The first painted pose acts as a faint wind-up trace; impact runs the six-frame one-shot.
	float art_opacity = max(charge * charge * 0.27, tail);
	if (effect_kind == 1) {
		for (int i = 0; i < target_count; i++) {
			float lag = float(i) * 0.22;
			float cursor = max(0.0, frame_cursor - lag);
			vec2 base = target_origins[i] * canvas_size;
			vec4 art = animated_art(pixels, base, cursor, t, mod(float(i), 2.0) < 1.0 ? 1.0 : -1.0);
			float appear = strength > 0.0 ? smoothstep(float(i) * 0.018, float(i) * 0.018 + 0.035, t) : 1.0;
			float opacity = art_opacity * appear;
			scene = scene * (1.0 - art.a * opacity) + art.rgb * opacity;
		}
	} else {
		vec4 art = animated_art(pixels, origin, frame_cursor, t, 1.0);
		scene = scene * (1.0 - art.a * art_opacity) + art.rgb * art_opacity;
	}
	// Thin moving cinders complement the authored large fragments; no repeated giant ring/cracks.
	for (int i = 0; i < 12; i++) {
		float n = float(i);
		float a = hash(n + 8.0) * 6.28318;
		float travel = (35.0 + hash(n + 21.0) * 245.0) * pow(t, 0.65);
		vec2 center = origin + vec2(cos(a), sin(a)) * travel;
		center.y += (effect_kind == 1 || effect_kind == 4 || effect_kind == 5 || effect_kind == 6) ? -t * t * 105.0 : t * t * 80.0;
		vec2 d = pixels - center;
		float streak = exp(-abs(d.x) * 0.9 - abs(d.y) * 0.23);
		scene += fire_color.rgb * streak * strength * (1.0 - smoothstep(0.25, 0.95, t)) * 0.7;
	}
	// Full viewport composite, including HUD and hand; no rectangular UI cutouts.
	if (cutin_progress >= 0.0) { scene = reaper_cutin(uv, scene); }
	COLOR = vec4(scene, 1.0);
}
