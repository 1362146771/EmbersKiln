shader_type canvas_item;
render_mode unshaded;

// Sample the portrait alpha, keeping the original image and its tint intact.
varying vec4 portrait_tint;

void vertex() {
	portrait_tint = COLOR;
}

float portrait_alpha(sampler2D image, vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return texture(image, uv).a;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = vec2(length(vec2(dFdx(UV.x), dFdy(UV.x))),
		length(vec2(dFdx(UV.y), dFdy(UV.y))));
	float edge = source.a;
	float glow = source.a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.2831853 / 16.0;
		vec2 direction = vec2(cos(angle), sin(angle)) * pixel;
		edge = max(edge, portrait_alpha(TEXTURE, UV + direction * 3.0));
		glow = max(glow, portrait_alpha(TEXTURE, UV + direction * 6.0));
	}
	float halo = max(edge, glow * 0.25) * (1.0 - source.a);
	float alpha = source.a + halo;
	vec3 rgb = (source.rgb * source.a + vec3(1.0) * halo) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * portrait_tint;
}
