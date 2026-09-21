shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR = vec4(vec3(1.0), COLOR.a * strength);
}
