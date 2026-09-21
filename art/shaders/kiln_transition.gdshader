shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool revealing = false;
uniform bool chapter = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - 0.5) * aspect;
	// 固定种子的陶片：最近两个点的距离差形成裂缝，不使用 TIME 或屏幕采样。
	vec2 grid = p * 7.0;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float nearest = 10.0;
	float second = 10.0;
	float shard = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = cell + offset;
			vec2 point = offset + 0.2 + 0.6 * vec2(hash(seed), hash(seed + 19.3));
			float d = length(point - local);
			if (d < nearest) {
				second = nearest;
				nearest = d;
				shard = hash(seed + 7.1);
			} else {
				second = min(second, d);
			}
		}
	}
	float seam = 1.0 - smoothstep(0.006, 0.035, second - nearest);
	float radius = length(p) / length(aspect * 0.5);
	float mask;
	float glow;
	if (chapter) {
		// 窑门从两侧合拢、从中间开启；细微不规则门缝避免机械直线。
		float center = 0.5 + sin(UV.y * 21.0) * 0.002;
		float door = abs(UV.x - center) * 2.0;
		float boundary = mix(1.04, -0.04, progress);
		mask = smoothstep(boundary - 0.008, boundary + 0.008, door);
		glow = (1.0 - smoothstep(0.006, 0.025, abs(door - boundary))) * 0.7;
	} else {
		// 陶壳由边缘合拢，揭幕时裂缝从中央扩散，陶片错落退去。
		float front = revealing ? radius * 0.8 + shard * 0.16 : 1.0 - radius * 0.8 + shard * 0.16;
		float phase = revealing ? 1.0 - progress : progress;
		float boundary = mix(-0.08, 1.20, phase);
		mask = smoothstep(front - 0.035, front + 0.035, boundary);
		if (revealing) { mask = 1.0 - mask; }
		float wave = 1.0 - smoothstep(0.04, 0.27, abs(front - boundary));
		glow = seam * (0.18 + wave * 0.70);
	}
	float grain = (hash(floor(p * 900.0)) - 0.5) * 0.022;
	vec3 clay = vec3(0.105, 0.082, 0.070) + vec3(grain + shard * 0.025);
	// 发光只在过渡中出现；完全覆盖时没有强光闪屏。
	float pulse = sin(clamp(progress, 0.0, 1.0) * 3.14159265);
	vec3 pigment = mix(clay, vec3(0.72, 0.32, 0.12), glow * pulse);
	if (progress <= 0.0) { mask = 0.0; }
	if (progress >= 1.0) { mask = 1.0; }
	COLOR = vec4(pigment, mask);
}
