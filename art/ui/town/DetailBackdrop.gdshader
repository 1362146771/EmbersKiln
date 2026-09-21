shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 3.0;
uniform float dim_amount : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 background = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(background * (1.0 - dim_amount), 1.0);
}
