shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool revealing = false;
uniform vec4 clay_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform vec4 ember_color : source_color = vec4(0.56, 0.23, 0.09, 1.0);

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), t.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + vec2(1.0)), t.x), t.y);
}

void fragment() {
	// 使用屏幕像素比例保持颗粒形状；不采样屏幕，也不使用随时间闪动的噪声。
	vec2 p = UV * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float coarse = noise(p * 13.0);
	float silhouette = noise(vec2(p.x * 14.0, 2.9));
	float grit = noise(vec2(p.x * 110.0, 8.1));
	// 轮廓只沿横向变化，保证每列连续擦除，不产生孤立方孔或大块撕裂。
	float front = UV.y + (silhouette - 0.5) * 0.06 + (grit - 0.5) * 0.01;
	// 进场从上往下覆盖，揭幕继续向下推进，不把同一段动画倒放。
	float threshold = mix(-0.14, 1.14, revealing ? 1.0 - progress : progress);
	float mask = smoothstep(front - 0.006, front + 0.006, threshold);
	if (revealing) { mask = 1.0 - mask; }
	float edge = 1.0 - smoothstep(0.003, 0.012, abs(threshold - front));
	float texture_grain = (grain(floor(p * 720.0)) - 0.5) * 0.028;
	vec3 pigment = clay_color.rgb + vec3(texture_grain + (coarse - 0.5) * 0.018);
	pigment = mix(pigment, ember_color.rgb, edge * 0.72);
	// 两端强制全透明/不透明，任何尺寸下都没有残留颗粒或透底孔洞。
	if (progress <= 0.0) { mask = 0.0; }
	if (progress >= 1.0) { mask = 1.0; }
	COLOR = vec4(pigment, mask);
}
